"""Compare declared-value selection with FIFO first-fit/value-greedy; time MoonBit alone."""
import json, pathlib, statistics, subprocess, sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
EXE = ROOT/'_build/native/release/build/examples/admission-bench/admission-bench.exe'
DIMENSIONS = ('memory_bytes', 'cpu_millis')


def usage(scopes, job):
    amounts = {s: {d: 0 for d in DIMENSIONS} for s in scopes}
    for request in job['allocations']:
        at = request['scope']
        while at is not None:
            for d in DIMENSIONS: amounts[at][d] += int(request['resources'][d])
            at = scopes[at]['parent']
    return amounts


def feasible(scopes, totals):
    return all(not any(totals[s].values()) or (scopes[s]['gate'] == 'open' and
               all(totals[s][d] <= int(scopes[s]['capacity'][d]) for d in DIMENSIONS)) for s in scopes)


def first_fit(scopes, jobs):
    used = {s: {d: 0 for d in DIMENSIONS} for s in scopes}
    selected = []
    for job in jobs:
        request = usage(scopes, job)
        proposed = {s: {d: used[s][d] + request[s][d] for d in DIMENSIONS} for s in scopes}
        if feasible(scopes, proposed):
            selected.append(job); used = proposed
    return selected


def main():
    assert sys.platform.startswith('linux')
    p = subprocess.run([str(EXE)], check=True, capture_output=True, text=True, timeout=60)
    rows = [json.loads(line) for line in p.stdout.splitlines() if line.strip()]
    assert len(rows) == 20
    summaries = []
    for row in rows:
        scopes = {s['id']: s for s in row['scopes']}
        jobs = row['jobs']; by_id = {j['id']: j for j in jobs}
        selected = [by_id[i] for i in row['plan']['selected']]
        total = {s: {d: 0 for d in DIMENSIONS} for s in scopes}
        for j in selected:
            amounts = usage(scopes, j)
            for s in scopes:
                for d in DIMENSIONS: total[s][d] += amounts[s][d]
        assert feasible(scopes, total)
        value = sum(int(j['value']) for j in selected)
        assert value == int(row['plan']['total_value'])
        fifo = sum(int(j['value']) for j in first_fit(scopes, jobs))
        greedy = sum(int(j['value']) for j in first_fit(scopes, sorted(jobs, key=lambda j: -int(j['value']))))
        assert value >= max(fifo, greedy)
        times = [int(t) for t in row['planning_time_us']]
        assert len(times) == 3 and min(times) >= 0
        assert 1 <= row['plan']['explored_states'] <= 131071
        summaries.append({'case': row['case'], 'jobs': len(jobs), 'scopes': len(scopes), 'fifo_first_fit_value': fifo,
                          'value_greedy_value': greedy, 'exact_value': value, 'median_planning_us': statistics.median(times),
                          'maximum_planning_us': max(times), 'explored_states': row['plan']['explored_states']})
    named = {s['case']: s for s in summaries}
    for name in ['complement-12', 'complement-16']:
        assert named[name]['exact_value'] == 48 and named[name]['value_greedy_value'] == 36
    assert named['dense-64-scopes-16-jobs']['exact_value'] == 8
    assert named['all-fit-16']['exact_value'] == 16
    result = {'synthetic': True, 'cases': 20, 'timing': 'release native; monotonic microseconds; warm-up; 3 measured plans/case',
              'fifo_baseline': 'first-fit in submission order; infeasible jobs skipped',
              'greedy_baseline': 'descending declared value; stable submission-order ties; first-fit',
              'wins_over_fifo': sum(s['exact_value'] > s['fifo_first_fit_value'] for s in summaries),
              'wins_over_greedy': sum(s['exact_value'] > s['value_greedy_value'] for s in summaries),
              'rows': summaries,
              'limits': 'Declared-value improvement is not measured throughput. Timings are environment-specific, not an SLA or a cross-language speed comparison.'}
    out = ROOT/'demo-output'; out.mkdir(exist_ok=True)
    (out/'benchmark-summary.json').write_text(json.dumps(result, indent=2)+'\n')
    print(json.dumps(result, indent=2))


if __name__ == '__main__': main()
