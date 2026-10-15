"""Exercise public APIs from the actual zip, using an isolated local workspace.

This verifies archive consumption, not registry installation or publication.
"""
import json, pathlib, re, subprocess, sys, tempfile, zipfile

ROOT=pathlib.Path(__file__).resolve().parents[1]
MODULE='local/moonpressure'

def run(*args,cwd=ROOT):
    p=subprocess.run(list(map(str,args)),cwd=cwd,check=True,capture_output=True,text=True,encoding='utf8',timeout=180)
    print(p.stdout,end='')
    return p.stdout

def write(path,text):
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(text,encoding='utf8')

def main():
    version=re.search(r'^version\s*=\s*"([^"]+)"',(ROOT/'moon.mod').read_text(),re.M)[1]
    run('moon','package')
    archive=ROOT/'_build/publish'/f'local-moonpressure-{version}.zip'
    base=ROOT/'_build/package-consumers';base.mkdir(parents=True,exist_ok=True)
    work=pathlib.Path(tempfile.mkdtemp(prefix='consumer-',dir=base))
    with zipfile.ZipFile(archive) as z:
        names=z.namelist()
        assert all(not pathlib.PurePosixPath(n).is_absolute() and '..' not in pathlib.PurePosixPath(n).parts for n in names)
        blocked={'research','release-local','demo-output','tmp','.git','.github','output','credentials.json','node_modules'}
        assert not any(p in blocked for n in names for p in pathlib.PurePosixPath(n).parts)
        for file in ['moon.mod','moon.pkg','native/bridge.c','native/moon.pkg','native/pkg.generated.mbti','pkg.generated.mbti','LICENSE','README.md']:
            assert file in names,('missing archive file',file)
        z.extractall(work/'library')
    write(work/'moon.work','members = ["library", "consumer"]\n')
    consumer=work/'consumer'
    write(consumer/'moon.mod',f'name = "acceptance/pressure-consumer"\nversion = "0.0.1"\nimport {{ "{MODULE}@{version}" }}\n')
    write(consumer/'moon.pkg',f'import {{ "{MODULE}" @pressure }} for "test"\n')
    write(consumer/'api_test.mbt',r'''///|
test "packaged public APIs enforce parent budget and OOM admission" {
  let limits = @pressure.budget([
    @pressure.Layer::parse("leaf", memory_max="max", memory_current="100"),
    @pressure.Layer::parse("parent", cpu_max="25000 100000", memory_max="1000", memory_current="900"),
  ])
  assert_eq(limits.hard_headroom_bytes, Some(100L))
  assert_eq(limits.quota_cores, Some(0.25))
  let before = @pressure.Snapshot::parse("consumer", 0L,
    cpu_stat="usage_usec 9007199254740993", memory_current="100",
    memory_events="high 0\nmax 0\noom 0\noom_kill 0")
  let after = @pressure.Snapshot::parse("consumer", 1000000L,
    cpu_stat="usage_usec 9007199255240993", memory_current="100",
    memory_events="high 0\nmax 0\noom 1\noom_kill 0")
  let delta = @pressure.interval(before, after)
  assert_eq(delta.cpu_cores_used, 0.5)
  let c = @pressure.Controller::new(@pressure.Policy::new())
  let result = c.update(delta, limits)
  assert_eq(result.state.label(), "shed")
  assert_true(result.reasons.contains(OutOfMemory))
  assert_true(before.to_json().stringify().contains("9007199254740993"))
}
''')
    targets=['wasm','wasm-gc','js']
    if sys.platform.startswith('linux'):targets.append('native')
    for target in targets:run('moon','-C',consumer,'test','--target',target,'--deny-warn')
    result={'version':version,'module':MODULE,'source':'actual local zip extracted into isolated workspace','archive_files':len(names),'consumer_tests':{t:1 for t in targets},'registry_installation':'not performed'}
    if sys.platform.startswith('linux'):
        write(consumer/'probe/moon.pkg',f'import {{ "{MODULE}/native", "moonbitlang/core/env" }}\nsupported_targets = "native"\noptions("is-main": true)\n')
        write(consumer/'probe/main.mbt','''///|
fn main raise {
  let args = @env.args()
  let o = @native.collect(args[1], args[2])
  guard o.layers.length() > 0 && o.snapshot.time_us > 0L else { abort("invalid observation") }
  println("{\\"linux_cgroup_read\\":true}")
}
''')
        group=next(line.split(':',2)[2].strip().lstrip('/') for line in pathlib.Path('/proc/self/cgroup').read_text().splitlines() if line.startswith('0::'))
        probe=json.loads(run('moon','-C',consumer,'run','probe','--target','native','--','/sys/fs/cgroup',group))
        assert probe['linux_cgroup_read']
        result['native_bridge_compiled_and_real_cgroup_called']=True
    write(ROOT/'demo-output/consumer-archive.json',json.dumps(result,indent=2)+'\n')
    write(ROOT/'release-local/package-files.txt','\n'.join(names)+'\n')
    print(json.dumps(result,indent=2))

if __name__=='__main__':main()
