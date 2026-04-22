#!/usr/bin/env python3
"""
Extract performance test data for all 5 servers:
  - Go (8080) and Spring (8084): from the reference results dir (2nd argument)
  - VT (8081), WebFlux (8082), Vert.x (8083): from the new results dir (1st argument)

Usage:
  python3 extract_perf_new.py <new_results_dir> [reference_results_dir]

Example:
  python3 extract_perf_new.py results_new_20260403_120000 results_20260402_201751
"""
import re, os, json, sys

NEW_DIR = sys.argv[1] if len(sys.argv) > 1 else "results_new_LATEST"
REF_DIR = sys.argv[2] if len(sys.argv) > 2 else "results_20260402_201751"

# Map: server_name → (subdir_in_dir, base_dir)
SERVERS = {
    "go":      ("go",      REF_DIR),
    "spring":  ("spring",  REF_DIR),
    "vt":      ("vt",      NEW_DIR),
    "webflux": ("webflux", NEW_DIR),
    "vertx":   ("vertx",   NEW_DIR),
}

def read(path):
    try:
        return open(path).read()
    except Exception:
        return ""

def srv_path(srv, filename):
    subdir, base_dir = SERVERS[srv]
    return os.path.join(base_dir, subdir, filename)

ENDPOINTS = ["customers", "accounts", "customer_summary"]
SERVER_ORDER = ["go", "spring", "vt", "webflux", "vertx"]

# ─── HEY ─────────────────────────────────────────────────────────────────────
print("=" * 90)
print("HEY RESULTS")
print("=" * 90)
for ep in ENDPOINTS:
    for load in ["10k", "50k"]:
        print(f"\n  Endpoint: {ep}  Load: {load}")
        print(f"  {'Server':<12} {'rps':>12}  {'avg (s)':>10}  {'p99 (s)':>10}")
        print(f"  {'-'*12} {'-'*12}  {'-'*10}  {'-'*10}")
        for srv in SERVER_ORDER:
            txt = read(srv_path(srv, f"hey_{ep}_{load}.txt"))
            rps = re.search(r'Requests/sec:\s+([\d.]+)', txt)
            avg = re.search(r'Average:\s+([\d.]+)', txt)
            p99 = re.search(r'99% in\s+([\d.]+)', txt)
            print(f"  {srv:<12} {(rps.group(1) if rps else 'N/A'):>12}  {(avg.group(1) if avg else 'N/A'):>10}  {(p99.group(1) if p99 else 'N/A'):>10}")

# ─── AB ──────────────────────────────────────────────────────────────────────
print("\n" + "=" * 90)
print("AB RESULTS")
print("=" * 90)
for ep in ENDPOINTS:
    print(f"\n  Endpoint: {ep}")
    print(f"  {'Server':<12} {'rps':>12}  {'mean (ms)':>10}  {'p50 (ms)':>9}  {'p99 (ms)':>9}")
    print(f"  {'-'*12} {'-'*12}  {'-'*10}  {'-'*9}  {'-'*9}")
    for srv in SERVER_ORDER:
        txt = read(srv_path(srv, f"ab_{ep}_50k.txt"))
        rps = re.search(r'Requests per second:\s+([\d.]+)', txt)
        mean_t = re.search(r'Time per request:\s+([\d.]+)\s+\[ms\]\s+\(mean\)', txt)
        p50 = re.search(r'\s+50%\s+(\d+)', txt)
        p99 = re.search(r'\s+99%\s+(\d+)', txt)
        print(f"  {srv:<12} {(rps.group(1) if rps else 'N/A'):>12}  {(mean_t.group(1) if mean_t else 'N/A'):>10}  {(p50.group(1) if p50 else 'N/A'):>9}  {(p99.group(1) if p99 else 'N/A'):>9}")

# ─── K6 ──────────────────────────────────────────────────────────────────────
print("\n" + "=" * 90)
print("K6 RESULTS")
print("=" * 90)
for ep in ENDPOINTS:
    for scenario in ["ramp", "stress", "spike"]:
        print(f"\n  Endpoint: {ep}  Scenario: {scenario}")
        print(f"  {'Server':<12} {'iters':>8}  {'rate (/s)':>11}  {'avg (ms)':>10}  {'p99 (ms)':>10}")
        print(f"  {'-'*12} {'-'*8}  {'-'*11}  {'-'*10}  {'-'*10}")
        for srv in SERVER_ORDER:
            fname = f"k6_{scenario}_{ep}.json"
            try:
                d = json.load(open(srv_path(srv, fname)))
                m = d.get("metrics", {})
                iters = m.get("iterations", {}).get("count", 0)
                rate = m.get("iterations", {}).get("rate", 0)
                dur_avg = m.get("http_req_duration", {}).get("avg", 0)
                dur_p99 = m.get("http_req_duration", {}).get("p(99)", 0)
                print(f"  {srv:<12} {iters:>8}  {rate:>11.1f}  {dur_avg:>10.2f}  {dur_p99:>10.2f}")
            except Exception as e:
                print(f"  {srv:<12} [N/A: {e}]")

# k6 multi
print(f"\n  Multi-endpoint scenario:")
print(f"  {'Server':<12} {'iters':>8}  {'rate (/s)':>11}  {'avg (ms)':>10}")
print(f"  {'-'*12} {'-'*8}  {'-'*11}  {'-'*10}")
for srv in SERVER_ORDER:
    try:
        d = json.load(open(srv_path(srv, "k6_multi.json")))
        m = d.get("metrics", {})
        iters = m.get("iterations", {}).get("count", 0)
        rate = m.get("iterations", {}).get("rate", 0)
        dur_avg = m.get("http_req_duration", {}).get("avg", 0)
        print(f"  {srv:<12} {iters:>8}  {rate:>11.1f}  {dur_avg:>10.2f}")
    except Exception as e:
        print(f"  {srv:<12} [N/A: {e}]")

# ─── METRICS SUMMARY ─────────────────────────────────────────────────────────
print("\n" + "=" * 90)
print("METRICS SUMMARY (peak samples from metrics.csv)")
print("=" * 90)

import csv

def peak_metrics_jvm(csv_path):
    """Return peak heap_mb, peak rss_mb, peak threads from JVM metrics CSV."""
    try:
        rows = list(csv.DictReader(open(csv_path)))
        peak_heap = max((float(r.get("heap_mb", 0) or 0) for r in rows), default=0)
        peak_rss  = max((float(r.get("rss_mb", 0) or 0) for r in rows), default=0)
        peak_thr  = max((float(r.get("threads", 0) or 0) for r in rows), default=0)
        return round(peak_heap, 1), round(peak_rss, 1), int(peak_thr)
    except Exception:
        return "N/A", "N/A", "N/A"

def peak_metrics_go(csv_path):
    """Return peak heap_mb, peak rss_mb for Go metrics CSV."""
    try:
        rows = list(csv.DictReader(open(csv_path)))
        peak_heap = max((float(r.get("heap_mb", 0) or 0) for r in rows), default=0)
        peak_rss  = max((float(r.get("rss_mb", 0) or 0) for r in rows), default=0)
        return round(peak_heap, 1), round(peak_rss, 1)
    except Exception:
        return "N/A", "N/A"

print(f"\n  {'Server':<12} {'Peak Heap (MB)':>15}  {'Peak RSS (MB)':>14}  {'Peak Threads':>13}")
print(f"  {'-'*12} {'-'*15}  {'-'*14}  {'-'*13}")

# Go
h, r = peak_metrics_go(os.path.join(REF_DIR, "go", "metrics.csv"))
print(f"  {'go':<12} {str(h):>15}  {str(r):>14}  {'N/A (goroutines)':>13}")

# Spring
h, r, t = peak_metrics_jvm(os.path.join(REF_DIR, "spring", "metrics.csv"))
print(f"  {'spring':<12} {str(h):>15}  {str(r):>14}  {str(t):>13}")

# New servers
for srv in ["vt", "webflux", "vertx"]:
    h, r, t = peak_metrics_jvm(os.path.join(NEW_DIR, srv, "metrics.csv"))
    print(f"  {srv:<12} {str(h):>15}  {str(r):>14}  {str(t):>13}")
