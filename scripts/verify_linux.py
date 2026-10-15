"""Linux read-only collector oracle using independently parsed raw kernel texts.

No privileged operations, cgroup writes, network changes or stress workloads.
The optional raw output stays under ignored demo-output/.
"""
import json, math, os, pathlib, subprocess, tempfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
EXE = ROOT / '_build/native/release/build/cmd/moonpressure/moonpressure.exe'

def invoke(*args, success=True):
    p = subprocess.run([str(EXE), *map(str, args)], text=True, capture_output=True)
    if success:
        assert p.returncode == 0, p.stderr
        return [json.loads(line) for line in p.stdout.splitlines() if line.strip()]
    assert p.returncode != 0, ('expected failure', args, p.stdout)

def kv(text):
    return {key: int(value) for key, value in (line.split() for line in text.splitlines() if line.strip())}

def close(a, b):
    assert math.isclose(a, b, rel_tol=1e-10, abs_tol=1e-9), (a, b)

def verify_observation(o, relative):
    assert o['schema'] == 1
    raw, s, b = o['raw'], o['snapshot'], o['budget']
    prefix = relative + '/' if relative else ''
    cpu = kv(raw[prefix+'cpu.stat'])
    assert int(s['cpu_usage_us']) == cpu['usage_usec']
    assert int(s['memory_current_bytes']) == int(raw[prefix+'memory.current'])
    events = kv(raw[prefix+'memory.events'])
    assert {k: int(v) for k,v in s['memory_events'].items()} == {k: events[k] for k in ['high','max','oom','oom_kill']}
    for resource in ['cpu', 'memory', 'io']:
        text = raw.get(prefix+resource+'.pressure')
        actual = s[resource+'_pressure']
        if text is None:
            assert actual is None
            continue
        lines = {p[0]: dict(x.split('=') for x in p[1:]) for p in (l.split() for l in text.splitlines()) if p}
        for mode in ['some', 'full']:
            if mode not in lines:
                assert actual[mode] is None
            else:
                for key in ['avg10','avg60','avg300']:
                    close(actual[mode][key], float(lines[mode][key]))
                assert int(actual[mode]['total_us']) == int(lines[mode]['total'])
    if 'nr_periods' in cpu:
        for key, kernel in [('periods','nr_periods'), ('throttled_periods','nr_throttled'), ('throttled_us','throttled_usec')]:
            assert int(s['throttle'][key]) == cpu[kernel]
    else:
        assert s['throttle'] is None
    path = pathlib.PurePosixPath(relative) if relative else pathlib.PurePosixPath('.')
    paths = [path, *path.parents] if relative else [path]
    quotas, hard, high = [], [], []
    for path in paths:
        name = str(path) if str(path) != '.' else '/'
        prefix = str(path)+'/' if str(path) != '.' else ''
        if prefix+'cpu.max' in raw:
            quota, period = raw[prefix+'cpu.max'].split()
            if quota != 'max': quotas.append((int(quota)/int(period), name))
        current = raw.get(prefix+'memory.current')
        for file, dest in [('memory.max',hard),('memory.high',high)]:
            limit = raw.get(prefix+file, 'max').strip()
            if limit != 'max': dest.append((max(0,int(limit)-int(current)),name))
    for values, key, source in [(quotas,'quota_cores_upper_bound','quota_source'),(hard,'hard_headroom_bytes','hard_source'),(high,'high_headroom_bytes','high_source')]:
        if values:
            value, name = min(values, key=lambda pair:pair[0])
            close(float(b[key]),value)
            assert b[source] == name
        else:
            assert b[key] is None and b[source] is None
    return s

def verify_delta(a,b,d):
    elapsed = int(b['time_us'])-int(a['time_us'])
    assert int(d['elapsed_us']) == elapsed and elapsed > 0
    close(d['cpu_cores_used'], (int(b['cpu_usage_us'])-int(a['cpu_usage_us']))/elapsed)
    for resource in ['cpu','memory','io']:
        x,y = a[resource+'_pressure'],b[resource+'_pressure']
        if x is None:
            assert d[resource+'_stall'] is None
        else:
            for mode in ['some','full']:
                if x[mode] is None:
                    assert d[resource+'_stall'][mode+'_percent'] is None
                else:
                    close(d[resource+'_stall'][mode+'_percent'],100*(int(y[mode]['total_us'])-int(x[mode]['total_us']))/elapsed)
    for field,key in [('memory_high_events','high'),('memory_max_events','max'),('oom_events','oom'),('oom_kills','oom_kill')]:
        assert int(d[field]) == int(b['memory_events'][key])-int(a['memory_events'][key])
    if a['throttle'] is not None:
        periods=int(b['throttle']['periods'])-int(a['throttle']['periods'])
        throttled=int(b['throttle']['throttled_periods'])-int(a['throttle']['throttled_periods'])
        if periods: close(d['throttled_period_percent'], 100*throttled/periods)
        else: assert d['throttled_period_percent'] is None
        assert int(d['throttled_us'])==int(b['throttle']['throttled_us'])-int(a['throttle']['throttled_us'])

def fixture_checks():
    (ROOT/'release-local').mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(dir=ROOT/'release-local') as temp:
        base=pathlib.Path(temp); parent=base/'parent'; leaf=parent/'leaf'; leaf.mkdir(parents=True)
        for directory, files in [
            (parent,{'cpu.max':'25000 100000','memory.max':'1000','memory.high':'950','memory.current':'900'}),
            (leaf,{'cpu.max':'max 100000','memory.max':'max','memory.high':'max','memory.current':'100','cpu.stat':'usage_usec 9007199254740993\nnr_periods 4\nnr_throttled 2\nthrottled_usec 100', 'memory.events':'high 1\nmax 2\noom 0\noom_kill 0', 'cpu.pressure':'some avg10=1.25 avg60=2.50 avg300=3.75 total=9007199254740993'})]:
            for file,text in files.items(): (directory/file).write_text(text)
        o=invoke('capture',base,'parent/leaf','raw')[0]; verify_observation(o,'parent/leaf')
        assert o['budget']['hard_headroom_bytes']=='100'
        assert o['budget']['high_headroom_bytes']=='50'
        assert o['budget']['quota_cores_upper_bound']==0.25
        assert o['snapshot']['memory_pressure'] is None
        invoke('capture',base,'../outside',success=False)
        (leaf/'cpu.stat').write_text('x'*65537)
        invoke('capture',base,'parent/leaf',success=False)
        (leaf/'cpu.stat').unlink()
        invoke('capture',base,'parent/leaf',success=False)
    return {'synthetic_native_capture':'passed','missing_optional_psi':'passed','parent_headroom':'passed','path_traversal_rejected':True,'oversized_read_rejected':True,'missing_required_rejected':True}

def main():
    assert os.uname().sysname=='Linux'
    checks=fixture_checks()
    groups=[line.split(':',2)[2].strip() for line in pathlib.Path('/proc/self/cgroup').read_text().splitlines() if line.startswith('0::')]
    assert len(groups)==1, 'requires unified cgroup v2'
    relative=groups[0].lstrip('/')
    rows=invoke('watch','/sys/fs/cgroup',relative,3,150,'raw')
    assert len(rows)==3
    previous=verify_observation(rows[0],relative)
    for row in rows[1:]:
        current=verify_observation(row['observation'],relative)
        assert current['identity']==previous['identity']
        verify_delta(previous,current,row['interval'])
        previous=current
    output=ROOT/'demo-output'; output.mkdir(exist_ok=True)
    (output/'linux-raw.json').write_text(json.dumps(rows,indent=2))
    result={'platform':'Linux','kernel':os.uname().release,'live_observations':3,'live_intervals':2,'independent_raw_text_oracle':'passed','fixture_checks':checks,'cgroup_writes':0,'privileged_operations':0,'limits':'Read-only live sampling; no induced CPU/memory pressure, OOM or power-loss tests.'}
    (output/'linux-summary.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))

if __name__=='__main__':main()
