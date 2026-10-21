"""Run the promised core matrix once and save a sanitized summary."""
import datetime, json, pathlib, platform, re, subprocess, sys
ROOT=pathlib.Path(__file__).resolve().parents[1]

def run(*args):
    p=subprocess.run(args,cwd=ROOT,capture_output=True,text=True,encoding='utf8',timeout=180)
    if p.returncode:
        print((p.stdout+p.stderr)[-4000:],file=sys.stderr)
        p.check_returncode()
    print(p.stdout,end='')
    return p.stdout+p.stderr

targets=sys.argv[1:] or ['wasm','wasm-gc','js']
version=run('moon','version','--all')
run('moon','fmt','--check')
counts={}
for target in targets:
    run('moon','check','--target',target,'--deny-warn','--warn-list','+73')
    output=run('moon','test','--target',target,'--deny-warn')
    m=re.search(r'Total tests: (\d+), passed: (\d+), failed: (\d+)',output)
    assert m and m[1]==m[2] and m[3]=='0'
    counts[target]=int(m[1])
    run('moon','build','--target',target,'--release','--deny-warn')
run(sys.executable,'scripts/verify_replay.py',*targets)
run(sys.executable,'scripts/verify_admission.py',*targets)
evidence_date=datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=8))).date().isoformat()
summary={'date':evidence_date,'platform':platform.system(),'toolchain':[line.split(')')[0]+')' for line in version.splitlines() if line.startswith(('moon ','moonc ','moonrun '))], 'library_and_documentation_tests':counts,'format_check':'passed','check_build_deny_warn':'passed','replay_intervals_per_backend':5,'replay_hand_oracle_and_cross_backend':'passed'}
folder=ROOT/'demo-output';folder.mkdir(exist_ok=True)
(folder/'core-summary.json').write_text(json.dumps(summary,indent=2)+'\n')
print(json.dumps(summary,indent=2))
