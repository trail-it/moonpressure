"""Run the promised core matrix once and save a sanitized summary."""
import json, pathlib, platform, re, subprocess, sys
ROOT=pathlib.Path(__file__).resolve().parents[1]

def run(*args):
    p=subprocess.run(args,cwd=ROOT,check=True,capture_output=True,text=True,encoding='utf8',timeout=180)
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
summary={'date':'2026-10-15','platform':platform.system(),'toolchain':[line.split(')')[0]+')' for line in version.splitlines() if line.startswith(('moon ','moonc ','moonrun '))], 'library_and_documentation_tests':counts,'format_check':'passed','check_build_deny_warn':'passed','replay_intervals_per_backend':5,'replay_hand_oracle_and_cross_backend':'passed'}
folder=ROOT/'demo-output';folder.mkdir(exist_ok=True)
(folder/'core-summary.json').write_text(json.dumps(summary,indent=2)+'\n')
print(json.dumps(summary,indent=2))
