"""Independent, hand-derived replay expectations. No third-party packages."""
import json, subprocess, sys
targets = sys.argv[1:] or ['wasm-gc', 'js']
outputs = []
for target in targets:
    proc = subprocess.run(['moon', 'run', 'examples/replay', '--target', target], check=True, capture_output=True, text=True)
    rows = [json.loads(s) for s in proc.stdout.splitlines() if s.strip()]
    assert len(rows) == 5
    assert [r['advice']['state'] for r in rows] == ['ready', 'shed', 'shed', 'shed', 'ready']
    assert [r['advice']['low_streak'] for r in rows] == [0, 0, 1, 2, 3]
    for i, r in enumerate(rows):
        assert r['budget']['quota_cores_upper_bound'] == 0.5
        assert r['budget']['hard_headroom_bytes'] == '104857600'
        assert r['budget']['hard_source'] == 'parent'
        d = r['interval']
        assert d['elapsed_us'] == '1000000'
        assert d['cpu_cores_used'] == (0.5 if i < 2 else 0)
        assert d['throttled_period_percent'] == (50 if i < 2 else 0)
        for name in ['cpu_stall', 'memory_stall', 'io_stall']:
            assert d[name]['some_percent'] == (30 if i < 2 else 0)
            assert d[name]['full_percent'] == (15 if i < 2 else 0)
    outputs.append(rows)
    print(f'{target}: 5 replay intervals match hand-derived oracle')
assert all(rows == outputs[0] for rows in outputs)
print('All selected backends agree')
