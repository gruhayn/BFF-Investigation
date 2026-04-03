#!/usr/bin/env python3
"""Extract profiling data from separate Go/Spring metrics CSVs.

New format (run_master.sh): results_dir/go/metrics.csv + results_dir/spring/metrics.csv
Legacy format (profile_pro.sh): profiling_dir/metrics_timeline.csv (combined)
"""
import csv, sys, os, statistics
from collections import defaultdict

if len(sys.argv) < 2:
    print(f"Usage: {sys.argv[0]} <results_dir>")
    sys.exit(1)

results_dir = sys.argv[1]

def safe_float(v, default=0.0):
    try: return float(v)
    except: return default

def load_csv(path):
    if not os.path.exists(path):
        return [], [], defaultdict(list)
    rows = list(csv.DictReader(open(path)))
    phases_seen = []
    phase_rows = defaultdict(list)
    for r in rows:
        p = r['phase']
        if p not in phase_rows:
            phases_seen.append(p)
        phase_rows[p].append(r)
    return rows, phases_seen, phase_rows

# ─── Detect format ────────────────────────────────────────────────────────────
legacy_csv = os.path.join(results_dir, "metrics_timeline.csv")
go_csv = os.path.join(results_dir, "go", "metrics.csv")
spring_csv = os.path.join(results_dir, "spring", "metrics.csv")

if os.path.exists(go_csv) or os.path.exists(spring_csv):
    MODE = "isolated"
    print("FORMAT: isolated (separate go/spring CSVs)")
else:
    print(f"ERROR: No metrics files found in {results_dir}")
    print(f"  Looked for: {go_csv}")
    print(f"          and: {spring_csv}")
    sys.exit(1)

# ─── Load data ─────────────────────────────────────────────────────────────────
go_rows, go_phases, go_phase_rows = load_csv(go_csv)
sp_rows, sp_phases, sp_phase_rows = load_csv(spring_csv)

print(f"GO SAMPLES: {len(go_rows)}, PHASES: {len(go_phases)}")
print(f"SPRING SAMPLES: {len(sp_rows)}, PHASES: {len(sp_phases)}")

# Build unified phase list (preserving order: go phases first, then spring-only phases)
all_phases = list(go_phases)
for p in sp_phases:
    if p not in all_phases:
        all_phases.append(p)

# ─── RSS ───────────────────────────────────────────────────────────────────────
print("\n=== RSS (vmmap Physical Footprint) ===")
print(f"  {'Phase':40s} {'Go RSS':>12s} {'Spring RSS':>12s} {'Ratio':>8s}")
print(f"  {'─'*40} {'─'*12} {'─'*12} {'─'*8}")

for p in go_phases:
    rr = go_phase_rows[p]
    vals = [safe_float(r['rss_mb']) for r in rr]
    avg = statistics.mean(vals) if vals else 0
    print(f"  {p:40s} {avg:10.1f} MB {'':>12s} {'':>8s}  n={len(rr)}")

print()
for p in sp_phases:
    rr = sp_phase_rows[p]
    vals = [safe_float(r['rss_mb']) for r in rr]
    avg = statistics.mean(vals) if vals else 0
    print(f"  {p:40s} {'':>12s} {avg:10.1f} MB {'':>8s}  n={len(rr)}")

# Side-by-side comparison for matching phases
matching = [p for p in go_phases if p in sp_phase_rows]
if matching:
    print("\n  --- Side-by-side (matching phases) ---")
    for p in matching:
        go_vals = [safe_float(r['rss_mb']) for r in go_phase_rows[p]]
        sp_vals = [safe_float(r['rss_mb']) for r in sp_phase_rows[p]]
        go_avg = statistics.mean(go_vals)
        sp_avg = statistics.mean(sp_vals)
        ratio = sp_avg / go_avg if go_avg > 0 else 0
        print(f"  {p:40s} {go_avg:10.1f} MB {sp_avg:10.1f} MB {ratio:6.1f}x")

# ─── HEAP ──────────────────────────────────────────────────────────────────────
print("\n=== HEAP ===")
print("  --- Go ---")
for p in go_phases:
    rr = go_phase_rows[p]
    vals = [safe_float(r['heap_mb']) for r in rr]
    avg = statistics.mean(vals) if vals else 0
    std = statistics.stdev(vals) if len(vals) > 1 else 0
    print(f"  {p:40s} heap={avg:7.2f} MB (+/-{std:.2f})")

print("  --- Spring ---")
for p in sp_phases:
    rr = sp_phase_rows[p]
    vals = [safe_float(r['heap_mb']) for r in rr]
    avg = statistics.mean(vals) if vals else 0
    std = statistics.stdev(vals) if len(vals) > 1 else 0
    print(f"  {p:40s} heap={avg:7.2f} MB (+/-{std:.2f})")

# ─── GO GC ─────────────────────────────────────────────────────────────────────
print("\n=== GO GC (cumulative boundaries) ===")
total_delta_cycles = 0
total_delta_pause = 0
for p in go_phases:
    rr = go_phase_rows[p]
    cycles = [safe_float(r['gc_cycles']) for r in rr]
    pauses = [safe_float(r['gc_pause_total_ms']) for r in rr]
    c_min, c_max = int(min(cycles)), int(max(cycles))
    p_min, p_max = min(pauses), max(pauses)
    dc = c_max - c_min
    dp = p_max - p_min
    total_delta_cycles += dc
    total_delta_pause += dp
    print(f"  {p:40s} cumul=[{c_min}->{c_max}]  phase_delta=+{dc}/+{dp:.1f}ms")
print(f"  TOTAL: +{total_delta_cycles} cycles, +{total_delta_pause:.1f} ms")

# ─── SPRING GC ────────────────────────────────────────────────────────────────
print("\n=== SPRING GC (cumulative boundaries) ===")
total_sp_dc = 0
total_sp_dp = 0
for p in sp_phases:
    rr = sp_phase_rows[p]
    counts = [safe_float(r['gc_count']) for r in rr]
    times = [safe_float(r['gc_time_ms']) for r in rr]
    maxp = [safe_float(r['gc_max_pause_ms']) for r in rr]
    c_min, c_max = int(min(counts)), int(max(counts))
    t_min, t_max = int(min(times)), int(max(times))
    mx = int(max(maxp))
    dc = c_max - c_min
    dp = t_max - t_min
    total_sp_dc += dc
    total_sp_dp += dp
    print(f"  {p:40s} cumul=[{c_min}->{c_max}]  phase_delta=+{dc}/+{dp}ms  max_single={mx}ms")
print(f"  TOTAL: +{total_sp_dc} cycles, +{total_sp_dp} ms")

# ─── CONCURRENCY ──────────────────────────────────────────────────────────────
print("\n=== CONCURRENCY ===")
print("  --- Go (goroutines + stack) ---")
for p in go_phases:
    rr = go_phase_rows[p]
    gors = [safe_float(r['goroutines']) for r in rr]
    stacks = [safe_float(r['stack_mb']) for r in rr]
    gor_max = int(max(gors))
    stack_max = max(stacks)
    print(f"  {p:40s} goroutines={gor_max:6d}  stack={stack_max:.2f}MB")

print("  --- Spring (threads) ---")
for p in sp_phases:
    rr = sp_phase_rows[p]
    threads = [safe_float(r['threads']) for r in rr]
    thr_max = int(max(threads))
    print(f"  {p:40s} threads={thr_max}")

# ─── RSS vs HEAP sanity ──────────────────────────────────────────────────────
print("\n=== RSS vs HEAP SANITY CHECK ===")
go_violations = sum(1 for r in go_rows if safe_float(r['rss_mb']) > 0 and safe_float(r['rss_mb']) < safe_float(r['heap_mb']))
sp_violations = sum(1 for r in sp_rows if safe_float(r['rss_mb']) > 0 and safe_float(r['rss_mb']) < safe_float(r['heap_mb']))
print(f"  Go RSS < Heap violations: {go_violations} / {len(go_rows)}")
print(f"  Spring RSS < Heap violations: {sp_violations} / {len(sp_rows)}")

# ─── Crash logs ───────────────────────────────────────────────────────────────
print("\n=== CRASH LOGS ===")
for name, subdir in [("Go", "go"), ("Spring", "spring")]:
    crash_file = os.path.join(results_dir, subdir, "crash_log.csv")
    if os.path.exists(crash_file):
        crash_rows = list(csv.DictReader(open(crash_file)))
        events = [r for r in crash_rows if r.get('event', '').startswith('restart')]
        print(f"  {name} crashes: {len(events)}")
        for r in events:
            print(f"    {r['timestamp']}  phase={r['phase']}  {r['event']}")
    else:
        print(f"  {name} crash log: not found")
