"""Exercise public APIs from an actual zip or an exact public registry version."""
import argparse, json, pathlib, re, subprocess, sys, tempfile, zipfile

ROOT=pathlib.Path(__file__).resolve().parents[1]
MODULE='trail-it/moonpressure'

def run(*args,cwd=ROOT):
    p=subprocess.run(list(map(str,args)),cwd=cwd,capture_output=True,text=True,encoding='utf8',timeout=180)
    if p.returncode:
        print((p.stdout+p.stderr)[-5000:],file=sys.stderr)
        p.check_returncode()
    print(p.stdout,end='')
    return p.stdout

def write(path,text):
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(text,encoding='utf8')

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--registry-version',help='Install this exact released version without a local workspace override')
    args=parser.parse_args()
    version=args.registry_version or re.search(r'^version\s*=\s*"([^"]+)"',(ROOT/'moon.mod').read_text(),re.M)[1]
    has_admission=tuple(map(int,version.split('.'))) >= (0,2,0)
    has_dispatch=tuple(map(int,version.split('.'))) >= (0,3,0)
    base=ROOT/'_build/package-consumers';base.mkdir(parents=True,exist_ok=True)
    work=pathlib.Path(tempfile.mkdtemp(prefix='consumer-',dir=base))
    names=[]
    if not args.registry_version:
        run('moon','package')
        archive=ROOT/'_build/publish'/f'trail-it-moonpressure-{version}.zip'
        with zipfile.ZipFile(archive) as z:
            names=z.namelist()
            assert all(not pathlib.PurePosixPath(n).is_absolute() and '..' not in pathlib.PurePosixPath(n).parts for n in names)
            blocked={'research','release-local','demo-output','tmp','.git','.github','output','credentials.json','node_modules'}
            assert not any(p in blocked for n in names for p in pathlib.PurePosixPath(n).parts)
            for file in ['moon.mod','moon.pkg','native/bridge.c','native/moon.pkg','native/pkg.generated.mbti','pkg.generated.mbti','LICENSE','README.md']:
                assert file in names,('missing archive file',file)
            if has_admission:
                assert {'admission/moon.pkg','admission/pkg.generated.mbti','admission/search.mbt','admission/ledger.mbt'}.issubset(names)
            if has_dispatch:
                assert {'dispatch/moon.pkg','dispatch/pkg.generated.mbti','dispatch/dispatcher.mbt','examples/dispatcher/stdio.c'}.issubset(names)
            z.extractall(work/'library')
        write(work/'moon.work','members = ["library", "consumer"]\n')
    consumer=work/'consumer'
    write(consumer/'moon.mod',f'name = "acceptance/pressure-consumer"\nversion = "0.0.1"\nimport {{ "{MODULE}@{version}" }}\n')
    if args.registry_version:
        assert not (work/'moon.work').exists()
        run('moon','-C',consumer,'add',f'{MODULE}@{version}')
        assert not any((parent/'moon.work').exists() for parent in [consumer,*consumer.parents]), 'registry dependency has a workspace override'
        # Query the resolver instead of assuming a toolchain-specific dependency cache layout.
        graph=json.loads(subprocess.run(['moon','-C',str(consumer),'tree','--json'],check=True,capture_output=True,text=True,encoding='utf8',timeout=180).stdout)
        assert graph['status']=='success'
        resolved=[m for m in graph['modules'] if m['name']==MODULE]
        assert len(resolved)==1 and resolved[0]['version']==version, 'resolved a different registry version'
        assert resolved[0]['source']['kind']=='registry' and not resolved[0]['workspace_member'], 'dependency is not from the public registry'
    extra=f', "{MODULE}/admission" @admission' if has_admission else ''
    if has_dispatch:extra+=f', "{MODULE}/dispatch" @driver'
    write(consumer/'moon.pkg',f'import {{ "{MODULE}" @pressure{extra} }} for "test"\n')
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
    if has_admission:
        write(consumer/'admission_test.mbt',r'''///|
test "downloaded planner selects complementary jobs and rejects stale commits" {
  let cap = @admission.Resources::new(memory_bytes=10L, cpu_millis=10L)
  let ledger = @admission.Ledger::new([@admission.Scope::new("root", cap)])
  let jobs = [
    @admission.Job::new("a", value=9L, [@admission.Allocation::new("root", cap)]),
    @admission.Job::new("b", value=6L, [@admission.Allocation::new("root", @admission.Resources::new(memory_bytes=6L, cpu_millis=4L))]),
    @admission.Job::new("c", value=6L, [@admission.Allocation::new("root", @admission.Resources::new(memory_bytes=4L, cpu_millis=6L))]),
  ]
  let plan = ledger.plan(jobs)
  let stale = ledger.plan(jobs)
  assert_eq(plan.selected(), ["b", "c"])
  assert_eq(plan.value(), 12L)
  assert_eq(plan.commit(), ["b", "c"])
  assert_true(try { ignore(stale.commit()); false } catch { StalePlan => true; _ => false })
  ledger.release("b")
  ledger.release("c")
  assert_eq(ledger.balances()[0].free.memory_bytes, 10L)
}
''')
    if has_dispatch:
        write(consumer/'dispatch_test.mbt',r'''///|
test "downloaded dispatcher retains cancellation lease and rejects old attempt" {
  let cap = @admission.Resources::new(memory_bytes=10L, cpu_millis=10L)
  let d = @driver.Dispatcher::new([@admission.Scope::new("root", cap)])
  d.submit(@admission.Job::new("job", value=1L, [@admission.Allocation::new("root", cap)]))
  let actions = d.dispatch()
  guard actions is [Start("job", old)] else { fail("expected start") }
  assert_eq(d.cancel("job"), Some(@driver.Action::Stop("job", old)))
  assert_eq(d.balances()[0].free.memory_bytes, 0L)
  assert_true(d.spawn_failed(old))
  assert_false(d.spawn_failed(old))
  d.retry("job")
  let actions = d.dispatch()
  guard actions is [Start("job", fresh)] else { fail("expected retry") }
  assert_true(fresh > old)
  assert_true(try { ignore(d.exited(old, 0)); false } catch { @driver.StaleAttempt => true; _ => false })
  assert_eq(d.balances()[0].free.memory_bytes, 0L)
  assert_eq(d.started(fresh), None)
  assert_true(d.exited(fresh, 0))
  assert_eq(d.status("job").state, @driver.State::Succeeded)
  assert_eq(d.balances()[0].free.memory_bytes, 10L)
}
''')
    targets=['wasm','wasm-gc','js']
    if sys.platform.startswith('linux'):targets.append('native')
    for target in targets:run('moon','-C',consumer,'test','--target',target,'--deny-warn')
    result={'version':version,'module':MODULE,'source':'public registry exact version' if args.registry_version else 'actual local zip extracted into isolated workspace','consumer_tests':{t:3 if has_dispatch else 2 if has_admission else 1 for t in targets},'registry_installation':version if args.registry_version else 'not performed'}
    if args.registry_version:result.update({'resolved_module_version':version,'local_workspace_override':False,'resolution_evidence':'moon tree --json registry source'})
    if not args.registry_version:result['archive_files']=len(names)
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
    write(ROOT/'demo-output'/('consumer-registry.json' if args.registry_version else 'consumer-archive.json'),json.dumps(result,indent=2)+'\n')
    if names:write(ROOT/'release-local/package-files.txt','\n'.join(names)+'\n')
    print(json.dumps(result,indent=2))

if __name__=='__main__':main()
