"""Bounded real children; all scheduling and lifecycle decisions come from MoonBit."""
import json, pathlib, selectors, subprocess, sys
from dispatch_client import Client, ROOT


def main():
    assert sys.platform.startswith('linux')
    group_text = pathlib.Path('/proc/self/cgroup').read_text()
    group = next(line.split(':', 2)[2].strip().lstrip('/') for line in group_text.splitlines() if line.startswith('0::'))
    children = []
    selector = selectors.DefaultSelector()
    max_alive = launches = 0
    result = {}
    with Client('--live', '/sys/fs/cgroup', group) as client:
        def send(op, **fields):
            r = client.send({'op': op, **fields})
            assert r['ok'], (op, r)
            return r
        def reserved(r): return max(int(b['reserved']['memory_bytes']) for b in r['balances'])
        def state(r, name): return next(t for t in r['tasks'] if t['id'] == name)
        def submit(name, memory, cpu, value=1):
            return send('submit', job={'id': name, 'value': str(value), 'allocations': [
                {'scope': 'scope-0', 'resources': {'memory_bytes': str(memory), 'cpu_millis': str(cpu)}}]})
        def dispatch(): return send('dispatch')['actions']
        def start(action, code=0):
            nonlocal launches, max_alive
            p = subprocess.Popen([sys.executable, '-u', str(ROOT/'scripts/demo_worker.py'), str(code), group_text],
                                 stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, bufsize=1)
            children.append((p, action['ticket']))
            launches += 1
            max_alive = max(max_alive, sum(p.poll() is None for p, _ in children))
            send('started', ticket=action['ticket'])
            selector.register(p.stdout, selectors.EVENT_READ)
            assert selector.select(5), 'worker readiness timed out'
            ready = json.loads(p.stdout.readline())
            selector.unregister(p.stdout)
            assert ready['ready'] and ready['same_cgroup'] and ready['buffer_bytes'] == 1048576
            return p
        def finish(p, ticket, expected=0):
            p.stdin.write('finish\n'); p.stdin.flush()
            code = p.wait(timeout=3)
            assert code == expected
            return send('exited', ticket=ticket, exit_code=code)
        try:
            initial = send('status')
            assert all(b['gate'] == 'open' for b in initial['balances']), 'real pressure gate is closed; cannot launch demo workers'
            memory = min(int(b['capacity']['memory_bytes']) for b in initial['balances'])
            cpu = min(int(b['capacity']['cpu_millis']) for b in initial['balances'])
            assert memory >= 33554432 and cpu >= 5, 'insufficient bounded application budget for demo'
            submit('a', memory, cpu, 9)
            submit('b', memory//2, cpu*2//5, 6)
            submit('c', memory//2, cpu-cpu*2//5, 6)
            actions = dispatch()
            assert [a['id'] for a in actions] == ['b', 'c']
            b, c = start(actions[0]), start(actions[1])
            send('cancel', id='a')
            finish(b, actions[0]['ticket'])
            assert reserved(send('status')) > 0
            finish(c, actions[1]['ticket'])
            assert reserved(send('status')) == 0
            result['complementary_batch_real_children'] = ['b', 'c']
            submit('launch-fail', memory//4, max(1, cpu//4))
            bad = dispatch()[0]
            try:
                subprocess.Popen([str(ROOT/'release-local/nonexistent-demo-executable')])
                raise AssertionError('deliberately absent executable started')
            except FileNotFoundError:
                failure = send('spawn_failed', ticket=bad['ticket'])
            assert state(failure, 'launch-fail')['state'] == 'failed' and reserved(failure) == 0
            send('retry', id='launch-fail')
            retry = dispatch()[0]; p = start(retry)
            late = client.send({'op': 'exited', 'ticket': bad['ticket'], 'exit_code': 0})
            assert not late['ok'] and late['error'] == 'stale_attempt' and reserved(late['state']) > 0
            finish(p, retry['ticket'])
            result['launch_failure_retry_and_late_callback'] = 'passed'
            submit('nonzero', memory//4, max(1, cpu//4))
            action = dispatch()[0]; p = start(action, code=7)
            failed = finish(p, action['ticket'], expected=7)
            assert state(failed, 'nonzero')['state'] == 'failed' and reserved(failed) == 0
            result['nonzero_exit_release'] = 'passed'
            submit('cancel-running', memory//4, max(1, cpu//4))
            action = dispatch()[0]; p = start(action)
            stopped = send('cancel', id='cancel-running')
            assert stopped['actions'] == [{'kind': 'stop', 'id': 'cancel-running', 'ticket': action['ticket']}]
            assert reserved(stopped) > 0 and p.poll() is None
            p.terminate() # only this Popen-owned child, never unrelated server processes
            code = p.wait(timeout=3)
            cancelled = send('exited', ticket=action['ticket'], exit_code=code)
            assert code != 0 and state(cancelled, 'cancel-running')['state'] == 'cancelled' and reserved(cancelled) == 0
            result['cancel_holds_until_actual_wait'] = 'passed'
            submit('cancel-starting', memory//4, max(1, cpu//4))
            action = dispatch()[0]
            waiting = send('cancel', id='cancel-starting')
            assert reserved(waiting) > 0
            done = send('spawn_failed', ticket=action['ticket']) # executor confirms no child was created
            assert state(done, 'cancel-starting')['state'] == 'cancelled' and reserved(done) == 0
            result['cancel_before_spawn_ack'] = 'passed'
            final = send('observe')
            assert reserved(final) == 0
            result.update({'environment': 'actual Linux child processes in the observed cgroup', 'real_child_launches': launches,
                           'maximum_simultaneous_children': max_alive, 'worker_buffer_bytes_each': 1048576, 'worker_deadline_seconds': 8,
                           'live_observation_refreshed': True, 'all_children_reaped': all(p.poll() is not None for p, _ in children),
                           'final_reserved_memory_bytes': 0, 'cgroup_writes': 0, 'unrelated_processes_signalled': 0,
                           'limits': 'Bounded lifecycle demonstration; declared resource estimates are not kernel-enforced limits or measured throughput.'})
        finally:
            for p, ticket in children:
                if p.poll() is None:
                    p.terminate()
                    try: p.wait(timeout=2)
                    except subprocess.TimeoutExpired: p.kill(); p.wait(timeout=2)
                    try: client.send({'op': 'exited', 'ticket': ticket, 'exit_code': p.returncode})
                    except Exception: pass
                for stream in (p.stdin, p.stdout, p.stderr):
                    if stream and not stream.closed: stream.close()
            selector.close()
    out = ROOT/'demo-output'; out.mkdir(exist_ok=True)
    (out/'execution-summary.json').write_text(json.dumps(result, indent=2)+'\n')
    print(json.dumps(result, indent=2))


if __name__ == '__main__': main()
