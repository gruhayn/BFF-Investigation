#!/usr/bin/env python3
"""
Extract performance test data for all 5 BFF servers (V2 unified run).

V2 uses a single results directory with 5 subdirs:
  results_v2_TIMESTAMP/
    go/        spring/        vt/        webflux/        vertx/

Each subdir contains:
  hey_*.txt, ab_*_50k.txt, k6_*.json, k6_*.txt, metrics.csv, crash_log.csv

CSV schemas:
  go:  timestamp,phase,rss_mb,heap_mb,sys_mb,stack_mb,goroutines,heap_objects,gc_cycles,gc_pause_total_ms,gc_pause_last_us
  jvm: timestamp,phase,server,rss_mb,heap_mb,nonheap_mb,gc_count,gc_time_ms,gc_max_pause_ms,threads
  vertx (jvm schema): threads=0, gc_max_pause_ms=0

Usage:
  python3 extract_perf_v2.py <results_v2_dir>

Example:
  python3 extract_perf_v2.py results_v2_20260420_180000
"""
import re, os, json, sys, csv

if len(sys.argv) < 2:
    print("Usage: python3 extract_perf_v2.py <results_v2_dir>")
    sys.exit(1)

RESULTS_DIR = sys.argv[1]

if not os.path.isdir(RESULTS_DIR):
    print(f"ERROR: directory not found: {RESULTS_DIR}")
    sys.exit(1)

SERVER_ORDER = ["go", "spring", "vt", "webflux", "vertx"]
ENDPOINTS    = ["customers", "accounts", "customer_summary"]

def srv_path(srv, filename):
    return os.path.join(RESULTS_DIR, srv, filename)

def read(path):
    try:
        return open(path).read()
    except Exception:
        return ""

# ─── HEY ──────────────────────────────────────────────────────────────────────
print("=" * 95)
print("HEY RESULTS")
print("=" * 95)
for ep in ENDPOINTS:
    for load in ["10k", "50k"]:
        concurrency = "200c" if load == "10k" else "500c"
        print(f"\n  Endpoint: {ep}  Load: {load} / {concurrency}")
        print(f"  {'Server':<12} {'rps':>12}  {'avg (s)':>10}  {'p50 (s)':>10}  {'p95 (s)':>10}  {'p99 (s)':>10}")
        print(f"  {'-'*12} {'-'*12}  {'-'*10}  {'-'*10}  {'-'*10}  {'-'*10}")
        for srv in SERVER_ORDER:
            txt = read(srv_path(srv, f"hey_{ep}_{load}.txt"))
            rps  = re.search(r'Requests/sec:\s+([\d.]+)', txt)
            avg  = re.search(r'Average:\s+([\d.]+)', txt)
            p50  = re.search(r'50% in\s+([\d.]+)', txt)
            p95  = re.search(r'95% in\s+([\d.]+)', txt)
            p99  = re.search(r'99% in\s+([\d.]+)', txt)
            print(f"  {srv:<12} "
                  f"{(rps.group(1) if rps else 'N/A'):>12}  "
                  f"{(avg.group(1) if avg else 'N/A'):>10}  "
                  f"{(p50.group(1) if p50 else 'N/A'):>10}  "
                  f"{(p95.group(1) if p95 else 'N/A'):>10}  "
                  f"{(p99.group(1) if p99 else 'N/A'):>10}")

# ─── AB ───────────────────────────────────────────────────────────────────────
print("\n" + "=" * 95)
print("AB RESULTS  (50k requests, 100 concurrency — standardized for all servers)")
print("=" * 95)
for ep in ENDPOINTS:
    print(f"\n  Endpoint: {ep}")
    print(f"  {'Server':<12} {'rps':>12}  {'mean (ms)':>10}  {'p50 (ms)':>9}  {'p95 (ms)':>9}  {'p99 (ms)':>9}")
    print(f"  {'-'*12} {'-'*12}  {'-'*10}  {'-'*9}  {'-'*9}  {'-'*9}")
    for srv in SERVER_ORDER:
        txt = read(srv_path(srv, f"ab_{ep}_50k.txt"))
        rps    = re.search(r'Requests per second:\s+([\d.]+)', txt)
        mean_t = re.search(r'Time per request:\s+([\d.]+)\s+\[ms\]\s+\(mean\)', txt)
        p50    = re.search(r'\s+50%\s+(\d+)', txt)
        p95    = re.search(r'\s+95%\s+(\d+)', txt)
        p99    = re.search(r'\s+99%\s+(\d+)', txt)
        print(f"  {srv:<12} "
              f"{(rps.group(1)    if rps    else 'N/A'):>12}  "
              f"{(mean_t.group(1) if mean_t else 'N/A'):>10}  "
              f"{(p50.group(1)    if p50    else 'N/A'):>9}  "
              f"{(p95.group(1)    if p95    else 'N/A'):>9}  "
              f"{(p99.group(1)    if p99    else 'N/A'):>9}")

# ─── K6 ───────────────────────────────────────────────────────────────────────
print("\n" + "=" * 95)
print("K6 RESULTS")
print("=" * 95)
for ep in ENDPOINTS:
    for scenario in ["ramp", "stress", "spike"]:
        print(f"\n  Endpoint: {ep}  Scenario: {scenario}")
        print(f"  {'Server':<12} {'iters':>8}  {'rate (/s)':>11}  {'avg (ms)':>10}  {'p95 (ms)':>10}  {'p99 (ms)':>10}  {'errors':>7}")
        print(f"  {'-'*12} {'-'*8}  {'-'*11}  {'-'*10}  {'-'*10}  {'-'*10}  {'-'*7}")
        for srv in SERVER_ORDER:
            fname = f"k6_{scenario}_{ep}.json"
            try:
                d = json.load(open(srv_path(srv, fname)))
                m = d.get("metrics", {})
                iters    = m.get("iterations", {}).get("count", 0)
                rate     = m.get("iterations", {}).get("rate", 0)
                dur_avg  = m.get("http_req_duration", {}).get("avg", 0)
                dur_p95  = m.get("http_req_duration", {}).get("p(95)", 0)
                dur_p99  = m.get("http_req_duration", {}).get("p(99)", 0)
                err_rate = m.get("http_req_failed",   {}).get("rate", 0)
                print(f"  {srv:<12} {iters:>8}  {rate:>11.1f}  {dur_avg:>10.2f}  {dur_p95:>10.2f}  {dur_p99:>10.2f}  {err_rate:>7.4f}")
            except Exception as e:
                print(f"  {srv:<12} [N/A: {e}]")

# k6 multi-endpoint
print(f"\n  Multi-endpoint scenario:")
print(f"  {'Server':<12} {'iters':>8}  {'rate (/s)':>11}  {'avg (ms)':>10}  {'p99 (ms)':>10}")
print(f"  {'-'*12} {'-'*8}  {'-'*11}  {'-'*10}  {'-'*10}")
for srv in SERVER_ORDER:
    try:
        d = json.load(open(srv_path(srv, "k6_multi.json")))
        m = d.get("metrics", {})
        iters   = m.get("iterations", {}).get("count", 0)
        rate    = m.get("iterations", {}).get("rate", 0)
        dur_avg = m.get("http_req_duration", {}).get("avg", 0)
        dur_p99 = m.get("http_req_duration", {}).get("p(99)", 0)
        print(f"  {srv:<12} {iters:>8}  {rate:>11.1f}  {dur_avg:>10.2f}  {dur_p99:>10.2f}")
    except Exception as e:
        print(f"  {srv:<12} [N/A: {e}]")

# ─── WRK ──────────────────────────────────────────────────────────────────────
print("\n" + "=" * 95)
print("WRK RESULTS  (sustained throughput, 30s)")
print("=" * 95)
for ep in ENDPOINTS:
    for concur in ["50c", "500c"]:
        threads = "4t" if concur == "50c" else "8t"
        print(f"\n  Endpoint: {ep}  Config: {threads}/{concur}/30s")
        print(f"  {'Server':<12} {'rps':>12}  {'avg lat':>10}  {'max lat':>10}")
        print(f"  {'-'*12} {'-'*12}  {'-'*10}  {'-'*10}")
        for srv in SERVER_ORDER:
            txt = read(srv_path(srv, f"wrk_{ep}_{concur}.txt"))
            rps     = re.search(r'Requests/sec:\s+([\d.]+)', txt)
            avg_lat = re.search(r'Latency\s+([\d.]+\w+)\s', txt)
            max_lat = re.search(r'Latency\s+[\d.]+\w+\s+[\d.]+\w+\s+([\d.]+\w+)', txt)
            print(f"  {srv:<12} "
                  f"{(rps.group(1)     if rps     else 'N/A'):>12}  "
                  f"{(avg_lat.group(1) if avg_lat else 'N/A'):>10}  "
                  f"{(max_lat.group(1) if max_lat else 'N/A'):>10}")

# ─── VEGETA ────────────────────────────────────────────────────────────────────
def vegeta_lat_ms(raw: str) -> str:
    """Convert vegeta latency string (59.166µs / 57.653ms / 1.002s) to ms string."""
    if not raw:
        return "N/A"
    m = re.match(r'([\d.]+)(µs|ms|s)', raw.strip())
    if not m:
        return raw
    val, unit = float(m.group(1)), m.group(2)
    if unit == "µs":
        return f"{val/1000:.2f}ms"
    elif unit == "ms":
        return f"{val:.2f}ms"
    else:  # s
        return f"{val*1000:.1f}ms"

print("\n" + "=" * 95)
print("VEGETA RESULTS  (fixed-rate load, 30s duration)")
print("=" * 95)
for ep in ENDPOINTS:
    for rate_name in ["100", "1k", "5k"]:
        rate_label = {"100": "100 rps", "1k": "1,000 rps", "5k": "5,000 rps"}[rate_name]
        print(f"\n  Endpoint: {ep}  Rate: {rate_label}")
        print(f"  {'Server':<12} {'total':>8}  {'throughput':>12}  {'mean':>10}  {'p95':>10}  {'p99':>10}  {'success':>9}")
        print(f"  {'-'*12} {'-'*8}  {'-'*12}  {'-'*10}  {'-'*10}  {'-'*10}  {'-'*9}")
        for srv in SERVER_ORDER:
            txt = read(srv_path(srv, f"vegeta_{ep}_{rate_name}.txt"))
            total      = re.search(r'Requests\s+\[total.*?\]\s+(\d+),', txt)
            throughput = re.search(r'Requests\s+\[total.*?\]\s+\d+,\s+[\d.]+,\s+([\d.]+)', txt)
            lats_m     = re.search(r'Latencies\s+\[.*?\]\s+([\S]+),\s+([\S]+),\s+([\S]+),\s+([\S]+),\s+([\S]+),\s+([\S]+),', txt)
            success    = re.search(r'Success\s+\[ratio\]\s+([\d.]+)%', txt)
            if lats_m:
                # groups: min, mean, 50, 90, 95, 99
                mean_ms = vegeta_lat_ms(lats_m.group(2))
                p95_ms  = vegeta_lat_ms(lats_m.group(5))
                p99_ms  = vegeta_lat_ms(lats_m.group(6))
            else:
                mean_ms = p95_ms = p99_ms = "N/A"
            print(f"  {srv:<12} "
                  f"{(total.group(1)      if total      else 'N/A'):>8}  "
                  f"{(throughput.group(1) if throughput else 'N/A'):>12}  "
                  f"{mean_ms:>10}  "
                  f"{p95_ms:>10}  "
                  f"{p99_ms:>10}  "
                  f"{(success.group(1)+'%' if success else 'N/A'):>9}")

# ─── METRICS SUMMARY ──────────────────────────────────────────────────────────
print("\n" + "=" * 95)
print("METRICS SUMMARY (peak values from metrics.csv)")
print("=" * 95)

def peak_metrics_go(csv_path):
    """Peak heap_mb, peak rss_mb, peak goroutines from Go CSV."""
    try:
        rows = list(csv.DictReader(open(csv_path)))
        peak_heap  = max((float(r.get("heap_mb", 0) or 0) for r in rows), default=0)
        peak_rss   = max((float(r.get("rss_mb", 0) or 0) for r in rows), default=0)
        peak_gor   = max((float(r.get("goroutines", 0) or 0) for r in rows), default=0)
        gc_total   = max((float(r.get("gc_pause_total_ms", 0) or 0) for r in rows), default=0)
        gc_cycles  = max((float(r.get("gc_cycles", 0) or 0) for r in rows), default=0)
        return round(peak_heap, 1), round(peak_rss, 1), int(peak_gor), round(gc_total, 1), int(gc_cycles)
    except Exception:
        return "N/A", "N/A", "N/A", "N/A", "N/A"

def peak_metrics_jvm(csv_path):
    """Peak heap_mb, peak rss_mb, peak threads, peak gc_time_ms from JVM CSV."""
    try:
        rows = list(csv.DictReader(open(csv_path)))
        peak_heap  = max((float(r.get("heap_mb", 0) or 0) for r in rows), default=0)
        peak_rss   = max((float(r.get("rss_mb", 0) or 0) for r in rows), default=0)
        peak_thr   = max((float(r.get("threads", 0) or 0) for r in rows), default=0)
        peak_gc_t  = max((float(r.get("gc_time_ms", 0) or 0) for r in rows), default=0)
        peak_gc_c  = max((float(r.get("gc_count", 0) or 0) for r in rows), default=0)
        return round(peak_heap, 1), round(peak_rss, 1), int(peak_thr), round(peak_gc_t, 1), int(peak_gc_c)
    except Exception:
        return "N/A", "N/A", "N/A", "N/A", "N/A"

print(f"\n  {'Server':<12} {'Peak Heap (MB)':>15}  {'Peak RSS (MB)':>14}  {'Peak Threads':>13}  {'GC Time (ms)':>13}  {'GC Cycles':>10}")
print(f"  {'-'*12} {'-'*15}  {'-'*14}  {'-'*13}  {'-'*13}  {'-'*10}")

for srv in SERVER_ORDER:
    csv_path = srv_path(srv, "metrics.csv")
    if srv == "go":
        heap, rss, goroutines, gc_total, gc_cycles = peak_metrics_go(csv_path)
        print(f"  {srv:<12} {str(heap):>15}  {str(rss):>14}  {str(goroutines)+' goroutines':>13}  {str(gc_total):>13}  {str(gc_cycles):>10}")
    else:
        heap, rss, threads, gc_time, gc_count = peak_metrics_jvm(csv_path)
        thr_label = "N/A (vertx)" if srv == "vertx" else str(threads)
        print(f"  {srv:<12} {str(heap):>15}  {str(rss):>14}  {thr_label:>13}  {str(gc_time):>13}  {str(gc_count):>10}")

# ─── CRASH SUMMARY ────────────────────────────────────────────────────────────
print("\n" + "=" * 95)
print("CRASH LOG SUMMARY")
print("=" * 95)
print(f"\n  {'Server':<12}  {'Crashes':>8}")
print(f"  {'-'*12}  {'-'*8}")
for srv in SERVER_ORDER:
    crash_path = os.path.join(RESULTS_DIR, srv, ".crash_count")
    try:
        count = int(open(crash_path).read().strip())
    except Exception:
        count = 0
    print(f"  {srv:<12}  {count:>8}")

print(f"\nAll data from: {RESULTS_DIR}")
