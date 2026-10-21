"""Bounded child fixture: touch 1 MiB, acknowledge readiness, wait at most eight seconds."""
import json, pathlib, select, sys

buffer = bytearray(1024 * 1024)
for i in range(0, len(buffer), 4096): buffer[i] = 1
same = pathlib.Path('/proc/self/cgroup').read_text() == sys.argv[2]
print(json.dumps({'ready': True, 'buffer_bytes': len(buffer), 'same_cgroup': same}), flush=True)
if not select.select([sys.stdin], [], [], 8)[0]:
    raise SystemExit(99)
if sys.stdin.readline().strip() != 'finish':
    raise SystemExit(98)
raise SystemExit(int(sys.argv[1]))
