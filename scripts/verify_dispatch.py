"""Linux/native model comparison. Recomputes leases from task state, never from the production ledger."""
import collections, copy, itertools, json, random, sys
from dispatch_client import Client, ROOT

DIMENSIONS = ('memory_bytes', 'cpu_millis')
ACTIVE = {'starting', 'running', 'stopping'}
TERMINAL = {'succeeded', 'failed', 'cancelled'}


def resource(memory, cpu):
    return {'memory_bytes': str(memory), 'cpu_millis': str(cpu)}


def scope(name, parent=None, memory=12, cpu=12, gate='open'):
    return {'id': name, 'parent': parent, 'capacity': resource(memory, cpu), 'gate': gate}


def job(name, rng):
    return {'id': name, 'value': str(rng.randint(1, 9)), 'allocations': [
        {'scope': rng.choice(['leaf-left', 'leaf-right', 'left', 'solo']),
         'resources': resource(rng.randint(1, 4), rng.randint(0, 4))}
        for _ in range(rng.choice([1, 1, 2]))]}


class Rejected(Exception):
    pass


class Model:
    def __init__(self, scopes):
        self.scopes = {s['id']: copy.deepcopy(s) for s in scopes}
        self.tasks = {}
        self.order = self.serial = self.revision = 0

    def amounts(self, jobs):
        used = {name: {d: 0 for d in DIMENSIONS} for name in self.scopes}
        for j in jobs:
            for a in j['allocations']:
                at = a['scope']
                while at is not None:
                    for d in DIMENSIONS:
                        used[at][d] += int(a['resources'][d])
                    at = self.scopes[at]['parent']
        return used

    def lookup(self, name):
        if name not in self.tasks:
            raise Rejected('unknown_job')
        return self.tasks[name]

    def attempt(self, ticket):
        for t in self.tasks.values():
            if t['ticket'] == ticket:
                return t
        raise Rejected('stale_attempt')

    def snapshot(self):
        used = self.amounts(t['job'] for t in self.tasks.values() if t['state'] in ACTIVE)
        balances = {}
        for name, s in self.scopes.items():
            balances[name] = {'scope': name, 'capacity': s['capacity'], 'gate': s['gate'],
                              'reserved': {d: str(used[name][d]) for d in DIMENSIONS},
                              'free': {d: str(max(0, int(s['capacity'][d]) - used[name][d])) for d in DIMENSIONS},
                              'deficit': {d: str(max(0, used[name][d] - int(s['capacity'][d]))) for d in DIMENSIONS}}
        tasks = {name: {k: t[k] for k in ('state', 'ticket', 'exit_code')} for name, t in self.tasks.items()}
        for name, t in tasks.items():
            t['id'] = name
        return {'tasks': tasks, 'balances': balances, 'revision': str(self.revision)}

    def operate(self, q):
        op, actions = q['op'], []
        if op == 'submit':
            j = copy.deepcopy(q['job'])
            if j['id'] in self.tasks or len(self.tasks) >= 128:
                raise Rejected('invalid')
            self.order += 1
            self.tasks[j['id']] = {'job': j, 'state': 'queued', 'ticket': None, 'exit_code': None, 'order': self.order}
        elif op == 'dispatch':
            waiting = sorted((t for t in self.tasks.values() if t['state'] == 'queued'), key=lambda t: t['order'])[:16]
            reserved = [t['job'] for t in self.tasks.values() if t['state'] in ACTIVE]
            best = (0, 0)
            selected = []
            for n in range(len(waiting) + 1):
                for subset in itertools.combinations(waiting, n):
                    proposed = [t['job'] for t in subset]
                    extra = self.amounts(proposed)
                    total = self.amounts(reserved + proposed)
                    feasible = all(not any(extra[s].values()) or self.scopes[s]['gate'] == 'open' for s in self.scopes)
                    feasible &= all(not any(extra[s].values()) or all(total[s][d] <= int(self.scopes[s]['capacity'][d]) for d in DIMENSIONS) for s in self.scopes)
                    ids = sorted((t['job']['id'] for t in subset), key=lambda s: s.encode('utf-16-be'))
                    score = (sum(int(t['job']['value']) for t in subset), n)
                    if feasible and (score > best or (score == best and ids < selected)):
                        best, selected = score, ids
            if selected:
                self.revision += 1
            for name in selected:
                self.serial += 1
                t = self.tasks[name]
                t['state'], t['ticket'] = 'starting', str(self.serial)
                actions.append({'kind': 'start', 'id': name, 'ticket': t['ticket']})
        elif op in ('started', 'exited', 'spawn_failed'):
            t = self.attempt(q['ticket'])
            if op == 'started':
                if t['state'] == 'starting':
                    t['state'] = 'running'
                elif t['state'] == 'stopping':
                    actions.append({'kind': 'stop', 'id': t['job']['id'], 'ticket': t['ticket']})
                elif t['state'] != 'running':
                    raise Rejected('stale_attempt')
            elif t['state'] not in TERMINAL:
                if op == 'spawn_failed' and t['state'] not in ('starting', 'stopping'):
                    raise Rejected('invalid')
                self.revision += 1
                t['state'] = 'cancelled' if t['state'] == 'stopping' else ('succeeded' if op == 'exited' and q['exit_code'] == 0 else 'failed')
                if op == 'exited':
                    t['exit_code'] = q['exit_code']
        elif op == 'cancel':
            t = self.lookup(q['id'])
            if t['state'] == 'queued':
                t['state'] = 'cancelled'
            elif t['state'] in ('starting', 'running'):
                t['state'] = 'stopping'
                actions.append({'kind': 'stop', 'id': q['id'], 'ticket': t['ticket']})
        elif op == 'retry':
            t = self.lookup(q['id'])
            if t['state'] not in ('failed', 'cancelled'):
                raise Rejected('invalid')
            self.order += 1
            t.update(state='queued', ticket=None, exit_code=None, order=self.order)
        elif op == 'forget':
            if self.lookup(q['id'])['state'] not in TERMINAL:
                raise Rejected('invalid')
            del self.tasks[q['id']]
        elif op == 'refresh':
            new = {s['id']: copy.deepcopy(s) for s in q['scopes']}
            if set(new) != set(self.scopes) or any(new[k]['parent'] != self.scopes[k]['parent'] for k in new):
                raise Rejected('invalid')
            self.scopes = new
            self.revision += 1
        elif op != 'status':
            raise Rejected('invalid_request')
        return actions


def normalized(response):
    return {'tasks': {t['id']: t for t in response['tasks']},
            'balances': {b['scope']: b for b in response['balances']}, 'revision': response['revision']}


def main():
    assert sys.platform.startswith('linux'), 'native protocol comparison runs on Linux'
    operations = collections.Counter()
    errors = collections.Counter()
    states = set()
    events = 0
    for seed in range(8):
        rng = random.Random(8171 + seed)
        initial = [scope('root'), scope('left', 'root', 8, 10), scope('leaf-left', 'left', 6, 7),
                   scope('right', 'root', 9, 9), scope('leaf-right', 'right', 6, 6), scope('solo', memory=4, cpu=4)]
        m = Model(initial)
        tickets = ['0']
        with Client() as client:
            assert normalized(client.send({'op': 'init', 'scopes': initial})) == m.snapshot()
            # Framing failures must leave all reservations/state untouched and permit the next command.
            for malformed in ['{broken', ' ' * 65537]:
                client.process.stdin.write(malformed + '\n'); client.process.stdin.flush()
                failed = client.read()
                assert not failed['ok'] and normalized(failed['state']) == m.snapshot()
            for _ in range(250):
                op = rng.choices(['submit', 'dispatch', 'started', 'exited', 'spawn_failed', 'cancel', 'retry', 'forget', 'refresh', 'status'],
                                 [20, 20, 8, 10, 5, 10, 8, 7, 9, 3])[0]
                q = {'op': op}
                if op == 'submit': q['job'] = job('job-' + str(rng.randrange(8)), rng)
                if op in ('cancel', 'retry', 'forget'): q['id'] = 'job-' + str(rng.randrange(8))
                if op in ('started', 'exited', 'spawn_failed'): q['ticket'] = rng.choice(tickets)
                if op == 'exited': q['exit_code'] = rng.choice([0, 0, 7, -15])
                if op == 'refresh':
                    q['scopes'] = copy.deepcopy(initial)
                    for s in q['scopes']:
                        s['capacity'] = resource(rng.randrange(15), rng.randrange(15))
                        s['gate'] = rng.choices(['open', 'pressure', 'unknown'], [8, 1, 1])[0]
                    if rng.randrange(12) == 0: q['scopes'][0]['id'] = 'invalid-topology'
                before = m.snapshot()
                rejected = None
                try: actions = m.operate(q)
                except Rejected as e: rejected = str(e)
                actual = client.send(q)
                if rejected:
                    assert not actual['ok'] and actual['error'] == rejected, (seed, events, q, actual)
                    assert m.snapshot() == before and normalized(actual['state']) == before
                    errors[rejected] += 1
                else:
                    assert actual['ok'] and actual['actions'] == actions, (seed, events, q, actual)
                    assert normalized(actual) == m.snapshot(), (seed, events, q, actual)
                    assert actual['changed'] == (before != m.snapshot())
                    tickets.extend(a['ticket'] for a in actions if a['kind'] == 'start')
                states.update(t['state'] for t in m.tasks.values())
                operations[op] += 1; events += 1
    assert states == ACTIVE | TERMINAL | {'queued'}, states
    result = {'synthetic': True, 'seeds': 8, 'events': events, 'operations': dict(operations), 'expected_rejections': dict(errors),
              'states_observed': sorted(states), 'state_reservation_revision_and_action_comparison': 'passed',
              'malformed_and_oversized_protocol_frames': 16, 'oracle': 'independent task model; recomputed ancestor leases and exhaustive batch choices'}
    out = ROOT / 'demo-output'; out.mkdir(exist_ok=True)
    (out / 'dispatch-model-summary.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result, indent=2))


if __name__ == '__main__': main()
