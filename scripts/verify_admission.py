"""Independent subset enumeration oracle; does not import the MoonBit search or its helpers."""
import itertools, json, pathlib, subprocess, sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
DIMENSIONS = ('memory_bytes', 'cpu_millis')


def oracle(row):
    scopes = {s['id']: s for s in row['scopes']}
    jobs = sorted(row['jobs'], key=lambda j: j['id'].encode('utf-16-be'))
    best = (0, 0, ())
    best_ids = []
    # Enumerate combinations by cardinality, independently of the production include-first recursion.
    for size in range(len(jobs) + 1):
        for subset in itertools.combinations(jobs, size):
            used = {s: {d: 0 for d in DIMENSIONS} for s in scopes}
            feasible = True
            for job in subset:
                for request in job['allocations']:
                    at = request['scope']
                    while at is not None:
                        s = scopes[at]
                        if s['gate'] != 'open':
                            feasible = False
                        for d in DIMENSIONS:
                            used[at][d] += int(request['resources'][d])
                        at = s['parent']
            for name, amounts in used.items():
                if any(amounts[d] > int(scopes[name]['capacity'][d]) for d in DIMENSIONS):
                    feasible = False
            if not feasible:
                continue
            ids = [j['id'] for j in subset]
            value = sum(int(j['value']) for j in subset)
            score = (value, size)
            if score > best[:2] or (score == best[:2] and tuple(ids) < best[2]):
                best = (value, size, tuple(ids))
                best_ids = ids
    assert row['plan']['selected'] == best_ids, row['case']
    assert int(row['plan']['total_value']) == best[0], row['case']
    # Each deferred explanation must name an actual violating resource/gate after this selected set.
    selected_jobs = [j for j in jobs if j['id'] in best_ids]
    chosen_usage = {s: {d: 0 for d in DIMENSIONS} for s in scopes}
    for j in selected_jobs:
        for request in j['allocations']:
            at = request['scope']
            while at is not None:
                for d in DIMENSIONS:
                    chosen_usage[at][d] += int(request['resources'][d])
                at = scopes[at]['parent']
    deferred = {d['job_id']: d['blockers'] for d in row['plan']['deferred']}
    assert set(deferred) == {j['id'] for j in jobs} - set(best_ids)
    for j in jobs:
        if j['id'] in best_ids:
            continue
        demand = {s: {d: 0 for d in DIMENSIONS} for s in scopes}
        for request in j['allocations']:
            at = request['scope']
            while at is not None:
                for d in DIMENSIONS:
                    demand[at][d] += int(request['resources'][d])
                at = scopes[at]['parent']
        expected = []
        for name in sorted(scopes):
            if not any(demand[name].values()):
                continue
            s = scopes[name]
            if s['gate'] != 'open':
                expected.append({'kind': 'unknown_pressure' if s['gate'] == 'unknown' else 'pressure', 'scope': name})
            for d, kind in [('memory_bytes', 'memory'), ('cpu_millis', 'cpu')]:
                available = max(0, int(s['capacity'][d]) - chosen_usage[name][d])
                if demand[name][d] > available:
                    expected.append({'kind': kind, 'scope': name, 'requested': str(demand[name][d]), 'available': str(available)})
        assert deferred[j['id']] == expected, (row['case'], j['id'])
        assert expected, 'Positive-value excluded job must be blocked by at least one constraint'


def main():
    targets = sys.argv[1:] or ['wasm-gc', 'js']
    outputs = []
    for target in targets:
        p = subprocess.run(['moon', 'run', 'examples/admission', '--target', target, '--', '--oracle'],
                           cwd=ROOT, check=True, capture_output=True, text=True, timeout=180)
        rows = [json.loads(line) for line in p.stdout.splitlines() if line.strip()]
        selection = [r for r in rows if r['kind'] == 'selection']
        assert len(selection) == 66
        for row in selection:
            oracle(row)
        by_name = {r['case']: r for r in rows}
        expected = {'shared-parent': ['a'], 'separate-parents': ['a', 'b'], 'complementary': ['b', 'c'],
                    'changed-demand': ['a'], 'gang-one-branch-held': ['local'], 'gang-open': ['gang']}
        for case, ids in expected.items():
            assert by_name[case]['plan']['selected'] == ids
        lifecycle = by_name['commit-stale-shrink-release']
        assert lifecycle['first_selected'] == ['a'] and lifecycle['stale_rejected']
        assert lifecycle['after_shrink'][0]['reserved'] == {'memory_bytes': '60', 'cpu_millis': '60'}
        assert lifecycle['after_shrink'][0]['deficit'] == {'memory_bytes': '10', 'cpu_millis': '10'}
        assert lifecycle['after_release_selected'] == ['b']
        outputs.append(rows)
        print(f'{target}: 66 exact selections and all deferral reasons match independent exhaustive oracle; lifecycle passed')
    assert all(rows == outputs[0] for rows in outputs)
    folder = ROOT / 'demo-output'
    folder.mkdir(exist_ok=True)
    (folder / 'admission-summary.json').write_text(json.dumps({'targets': targets, 'selection_cases_per_backend': 66,
        'oracle': 'independent Python exhaustive subset enumeration and blocker reconstruction', 'cross_backend_equal': True,
        'synthetic': True, 'lifecycle': 'commit/stale/shrink/release passed'}, indent=2) + '\n')
    (folder / 'admission-cases.json').write_text(json.dumps(outputs[0][:7], indent=2) + '\n')


if __name__ == '__main__':
    main()
