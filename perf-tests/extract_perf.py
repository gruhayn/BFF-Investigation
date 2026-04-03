#!/usr/bin/env python3
"""Extract all performance test data from isolated results directory."""
import re, os, json, sys

D = sys.argv[1] if len(sys.argv) > 1 else "results_20260402_201751"

def read(path):
    try:
        return open(path).read()
    except:
        return ""

# === HEY ===
print("=== HEY RESULTS ===")
for ep in ["customers", "accounts", "customer_summary"]:
    for load in ["10k", "50k"]:
        for srv in ["go", "spring"]:
            f = f"{D}/{srv}/hey_{ep}_{load}.txt"
            txt = read(f)
            rps = re.search(r'Requests/sec:\s+([\d.]+)', txt)
            avg = re.search(r'Average:\s+([\d.]+)', txt)
            p99 = re.search(r'99% in\s+([\d.]+)', txt)
            r_val = rps.group(1) if rps else 'N/A'
            a_val = avg.group(1) if avg else 'N/A'
            p_val = p99.group(1) if p99 else 'N/A'
            print(f"  {srv:8s} {ep:20s} {load:4s}  rps={r_val:>12s}  avg={a_val:>8s}s  p99={p_val:>8s}s")

# === WRK ===
print("\n=== WRK RESULTS ===")
for ep in ["customers", "accounts", "customer_summary"]:
    for conc in ["50c", "500c"]:
        for srv in ["go", "spring"]:
            f = f"{D}/{srv}/wrk_{ep}_{conc}.txt"
            txt = read(f)
            rps = re.search(r'Requests/sec:\s+([\d.]+)', txt)
            lat = re.search(r'Latency\s+([\d.]+\w+)', txt)
            r_val = rps.group(1) if rps else 'N/A'
            l_val = lat.group(1) if lat else 'N/A'
            print(f"  {srv:8s} {ep:20s} {conc:4s}  rps={r_val:>12s}  lat={l_val:>10s}")

# === VEGETA ===
print("\n=== VEGETA RESULTS ===")
for ep in ["customers", "accounts", "customer_summary"]:
    for rate in ["100", "1k", "5k"]:
        for srv in ["go", "spring"]:
            f = f"{D}/{srv}/vegeta_{ep}_{rate}.txt"
            txt = read(f)
            thr = re.search(r'Requests\s+\[total, rate, throughput\]\s+[\d]+,\s*[\d.]+,\s*([\d.]+)', txt)
            lat = re.search(r'Latencies\s+\[min, mean, 50, 90, 95, 99, max\]\s+([\d.]+\w+),\s*([\d.]+\w+),\s*([\d.]+\w+),\s*([\d.]+\w+),\s*([\d.]+\w+),\s*([\d.]+\w+)', txt)
            succ = re.search(r'Success\s+\[ratio\]\s+([\d.]+)%', txt)
            t_val = thr.group(1) if thr else 'N/A'
            m_val = lat.group(2) if lat else 'N/A'
            p_val = lat.group(6) if lat else 'N/A'
            s_val = succ.group(1) if succ else 'N/A'
            print(f"  {srv:8s} {ep:20s} {rate:4s}  thr={t_val:>10s}  mean={m_val:>12s}  p99={p_val:>12s}  succ={s_val}%")

# === AB ===
print("\n=== AB RESULTS ===")
for ep in ["customers", "accounts", "customer_summary"]:
    for srv in ["go", "spring"]:
        f = f"{D}/{srv}/ab_{ep}_50k.txt"
        txt = read(f)
        rps = re.search(r'Requests per second:\s+([\d.]+)', txt)
        mean_t = re.search(r'Time per request:\s+([\d.]+)\s+\[ms\]\s+\(mean\)', txt)
        p50 = re.search(r'\s+50%\s+(\d+)', txt)
        p99 = re.search(r'\s+99%\s+(\d+)', txt)
        r_val = rps.group(1) if rps else 'N/A'
        m_val = mean_t.group(1) if mean_t else 'N/A'
        p50v = p50.group(1) if p50 else 'N/A'
        p99v = p99.group(1) if p99 else 'N/A'
        print(f"  {srv:8s} {ep:20s}  rps={r_val:>12s}  mean={m_val:>10s}ms  p50={p50v:>6s}ms  p99={p99v:>6s}ms")

# === K6 (from JSON) ===
print("\n=== K6 RESULTS ===")
for ep in ["customers", "accounts", "customer_summary"]:
    for scenario in ["ramp", "stress", "spike"]:
        for srv in ["go", "spring"]:
            f = f"{D}/{srv}/k6_{scenario}_{ep}.json"
            try:
                d = json.load(open(f))
                m = d.get('metrics', {})
                iters = m.get('iterations', {}).get('count', 0)
                dur_avg = m.get('http_req_duration', {}).get('avg', 0)
                dur_p99 = m.get('http_req_duration', {}).get('p(99)', 0)
                rate = m.get('iterations', {}).get('rate', 0)
                print(f"  {srv:8s} {ep:20s} {scenario:6s}  iters={iters:>8}  rate={rate:>10.1f}/s  avg={dur_avg:>8.2f}ms  p99={dur_p99:>10.2f}ms")
            except Exception as e:
                print(f"  {srv:8s} {ep:20s} {scenario:6s}  [error: {e}]")

for srv in ["go", "spring"]:
    f = f"{D}/{srv}/k6_multi.json"
    try:
        d = json.load(open(f))
        m = d.get('metrics', {})
        iters = m.get('iterations', {}).get('count', 0)
        dur_avg = m.get('http_req_duration', {}).get('avg', 0)
        rate = m.get('iterations', {}).get('rate', 0)
        print(f"  {srv:8s} {'multi':20s}         iters={iters:>8}  rate={rate:>10.1f}/s  avg={dur_avg:>8.2f}ms")
    except Exception as e:
        print(f"  {srv:8s} {'multi':20s}         [error: {e}]")
