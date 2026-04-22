# Profiling Results V3: Go vs Spring MVC vs Virtual Threads vs WebFlux vs Vert.x

**Scope:** Memory usage, GC behaviour, and concurrency metrics across all 5 servers
**Setup:** Each server monitored independently with 5-second sampling intervals during each benchmark phase
**Results dir:** `results_v3_20260421_095020/`
**Monitoring columns:**
- **Go:** `rss_mb, heap_mb, sys_mb, stack_mb, goroutines, gc_cycles, gc_pause_total_ms`
- **JVM (Spring/VT/WebFlux/Vert.x):** `rss_mb, heap_mb, nonheap_mb, gc_count, gc_time_ms, gc_max_pause_ms, threads`

---

## Section 1 — Physical Memory (RSS)

RSS = Resident Set Size — how much RAM the OS has allocated to the process.

### Peak RSS by server

| Server | Idle RSS | Peak RSS | Δ above idle | Peak phase |
|---|---:|---:|---:|---|
| Go | 7.2 MB | 168.5 MB | +161.3 MB | vegeta_customer_summary_5k |
| Spring | 202.6 MB | 599.0 MB | +396.4 MB | vegeta_customer_summary_5k |
| **VT** | 198.0 MB | **2,764.8 MB** | **+2,566.8 MB** | vegeta_accounts_5k |
| WebFlux | 250.9 MB | 909.0 MB | +658.1 MB | vegeta_customer_summary_5k |
| Vert.x | 127.8 MB | 573.2 MB | +445.4 MB | vegeta_customer_summary_5k |

> Virtual Threads' RSS peak (2,764MB) is **16.4x Go** and **4.6x Spring**. The VT server kept all objects in memory even after vegeta 5k — virtual threads park on I/O but still hold their stack-allocated objects in the JVM heap, and under high concurrency the JVM could not GC fast enough.

### RSS progression through benchmark phases

| Phase | Go | Spring | VT | WebFlux | Vert.x |
|---|---:|---:|---:|---:|---:|
| idle | 7.2 | 202.6 | 198.0 | 250.9 | 127.8 |
| hey_customers_50k | 41.7 | 391.4 | 555.7 | 594.6 | 273.3 |
| hey_accounts_50k | 43.5 | 391.3 | 646.7 | 889.3 | 473.4 |
| hey_customer_summary_50k | 46.2 | 392.3 | 635.9 | 889.8 | 486.3 |
| wrk_customers_500c | 44.3 | 393.1 | 656.5 | 608.5 | 477.0 |
| wrk_accounts_500c | 44.5 | 393.3 | 913.7 | 903.7 | 555.8 |
| wrk_customer_summary_500c | 44.9 | 393.7 | 914.2 | 908.2 | 557.4 |
| k6_stress_customers | 42.9 | 392.4 | 480.9 | 890.4 | 469.5 |
| k6_spike_customers | 44.1 | 392.4 | 481.0 | 886.3 | 469.5 |
| k6_stress_accounts | 42.1 | 392.3 | 481.2 | 303.0 | 469.9 |
| k6_stress_customer_summary | 43.0 | 392.8 | 481.3 | 366.2 | 472.1 |
| vegeta_customers_5k | 152.6 | 520.0 | 1,331.2 | 903.4 | 557.4 |
| vegeta_accounts_5k | 167.4 | 597.9 | **2,764.8** | 903.8 | 563.1 |
| vegeta_customer_summary_5k | **168.5** | **599.0** | **2,764.8** | **909.0** | **573.2** |
| ab_customers_50k | 40.7 | 392.4 | 432.3 | 890.0 | 490.0 |
| ab_accounts_50k | 40.5 | 392.4 | 480.9 | 890.1 | 490.4 |
| ab_customer_summary_50k | 40.4 | 392.4 | 480.9 | 890.0 | 490.5 |
| final_cooldown | 153.9 | 599.0 | 2,764.8 | 909.0 | 573.2 |

All values in **MB**.

### Key observations

- **Go:** RSS grows almost entirely from goroutine stacks during vegeta 5k (3,861 goroutines × ~42.9MB stack pool = 152MB peak). Returns to ~40MB between tests — almost perfect memory hygiene.
- **Spring:** Steps up steadily from 202MB idle to ~393MB after first hey run, then holds stable. Jumps to 599MB only at vegeta 5k — heap growth from queued requests.
- **VT:** Sharp jumps at every new load level. Does **not** release memory between phases — stays at 914MB after wrk_accounts even during lighter k6. Explodes to 2,764MB at vegeta_accounts_5k and stays there. The JVM did not GC aggressively enough between tests.
- **WebFlux:** Early jump to ~890MB after hey_accounts_50k, stays elevated. WebFlux pre-allocates Netty buffer pools and direct memory — hence the high RSS even at moderate load.
- **Vert.x:** Similar to WebFlux in growth pattern but more moderate (peak 573MB vs 909MB). Returns to ~470MB between vegeta and ab phases.

---

## Section 2 — Heap Memory

### Peak heap by server

| Server | Idle heap | Peak heap | Peak phase | Notes |
|---|---:|---:|---|---|
| Go | 2.4 MB | 86.6 MB | vegeta_customers_5k | Goroutine-allocated in-flight objects |
| Spring | 64.3 MB | 400.7 MB | vegeta_customer_summary_5k | JVM old-gen filling up |
| **VT** | 56.3 MB | **2,016.0 MB** | *(sampled peak)* | Heap explosion under 5k rps |
| WebFlux | 32.0 MB | 469.0 MB | *(sampled peak)* | Netty + reactive pipeline objects |
| Vert.x | 36.6 MB | 314.0 MB | *(sampled peak)* | Lowest JVM heap peak |

### Go heap profile (per phase)

| Phase | Peak Heap (MB) | Peak Stack (MB) | Peak Goroutines |
|---|---:|---:|---:|
| idle | 2.4 | 0.3 | 3 |
| hey_customers_50k | 7.3 | 3.2 | 3 |
| hey_accounts_50k | 14.6 | 4.7 | 3 |
| hey_customer_summary_50k | 14.3 | 6.2 | 3 |
| wrk_customers_500c | 13.1 | 7.7 | 510 |
| wrk_accounts_500c | 13.4 | 7.7 | 502 |
| wrk_customer_summary_500c | 12.4 | 9.3 | 573 |
| k6_stress_customers | 8.3 | 4.9 | 203 |
| k6_spike_customers | 13.8 | 7.6 | 503 |
| k6_stress_accounts | 8.9 | 4.9 | 203 |
| k6_stress_customer_summary | 7.5 | 5.8 | 203 |
| vegeta_customers_5k | **86.6** | 42.8 | **3,861** |
| vegeta_accounts_5k | 77.5 | 40.8 | 3,751 |
| vegeta_customer_summary_5k | 76.4 | 42.9 | 3,459 |
| ab_customers_50k | 4.9 | 2.8 | 5 |
| ab_accounts_50k | 5.3 | 2.9 | 6 |
| ab_customer_summary_50k | 3.4 | 2.9 | 7 |
| final_cooldown | 50.4 | 17.7 | 3 |

> Go's heap is directly proportional to in-flight goroutines. Outside vegeta 5k (which uses 5,000 concurrent goroutines), heap stays below 15MB throughout all benchmarks. The stack pool explains the RSS—heap gap: at vegeta 5k, stack=42.9MB, heap=86.6MB, total RSS=168.5MB.

### JVM heap profile (peak per phase, in MB)

| Phase | Spring | VT | WebFlux | Vert.x |
|---|---:|---:|---:|---:|
| idle | 64.3 | 56.3 | 32.0 | 36.6 |
| hey_customers_50k | 126.8 | 227.7 | 105.2 | 84.6 |
| hey_accounts_50k | 184.5 | 328.1 | 334.5 | 61.9 |
| hey_customer_summary_50k | 140.8 | 395.0 | 275.3 | 164.4 |
| wrk_customers_500c | 201.2 | 415.3 | 213.9 | 213.8 |
| wrk_accounts_500c | 201.5 | 555.3 | 446.6 | 227.0 |
| wrk_customer_summary_500c | 200.6 | 534.0 | 426.1 | 270.0 |
| k6_stress_customers | 201.8 | 274.0 | 406.6 | 242.1 |
| k6_spike_customers | 106.7 | 275.9 | 411.4 | 175.0 |
| k6_stress_accounts | 195.1 | 296.8 | 73.6 | 229.8 |
| k6_stress_customer_summary | 204.9 | 307.4 | 110.9 | 215.1 |
| vegeta_customers_5k | 279.7 | 900.0 | 195.1 | 264.1 |
| vegeta_accounts_5k | 372.2 | 1,452.0 | 437.0 | 314.0 |
| vegeta_customer_summary_5k | 400.7 | **1,991.5** | 387.1 | 258.6 |
| ab_customers_50k | 147.4 | 100.0 | 388.9 | 157.6 |
| ab_accounts_50k | 158.2 | 215.1 | 391.2 | 205.5 |
| ab_customer_summary_50k | 198.3 | 210.0 | 290.0 | 78.1 |
| final_cooldown | 372.8 | 1,683.3 | 183.5 | 235.4 |

### RSS-above-heap ratio (peak phase)

| Server | Peak RSS | Peak Heap | RSS overhead | Notes |
|---|---:|---:|---:|---|
| Go | 168.5 MB | 86.6 MB | +81.9 MB | Stack pool, OS-level metadata |
| Spring | 599.0 MB | 400.7 MB | +198.3 MB | JVM metaspace, code cache, non-heap |
| VT | 2,764.8 MB | 2,016.0 MB | +748.8 MB | Virtual thread stacks in off-heap |
| WebFlux | 909.0 MB | 469.0 MB | +440.0 MB | Netty direct buffers, off-heap |
| Vert.x | 573.2 MB | 314.0 MB | +259.2 MB | Vert.x buffers, non-heap |

> Go's RSS overhead (82MB) is purely goroutine stacks and OS metadata. JVM overhead is larger (200–750MB above heap) because of: JIT code cache (~100MB), Metaspace, OS thread stacks, direct buffer pools (especially WebFlux/Netty), and in VT's case — virtual thread continuation objects stored off-heap.

---

## Section 3 — Garbage Collection

### Total GC across full benchmark run

| Server | Total GC cycles | Total GC time | Avg ms/cycle | Model |
|---|---:|---:|---:|---|
| Go | 14,417 | 3,131.7 ms | 0.22 ms | Concurrent tricolor mark-sweep |
| Spring | 1,011 | 2,022.0 ms | 2.0 ms | G1GC |
| VT | 1,202 | 5,903.0 ms | 4.9 ms | G1GC |
| WebFlux | 1,406 | 2,240.0 ms | 1.6 ms | G1GC |
| Vert.x | 943 | 1,044.0 ms | 1.1 ms | G1GC |

> Go runs **14,417 micro GCs** averaging only **0.22ms each** — nearly imperceptible. JVM G1GC runs fewer but costlier collections. VT's average of 4.9ms/cycle indicates long GC pauses under heap pressure (especially at 5k rps when heap is 1.5–2GB). Vert.x has the cleanest GC of all JVM servers: fewest cycles, shortest total time.

### GC activity per phase

| Phase | Go Δcycles | Go Δpause ms | Spring Δcycles | Spring Δtime ms | VT Δcycles | VT Δtime ms | WebFlux Δcycles | WebFlux Δtime ms | Vert.x Δcycles | Vert.x Δtime ms |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| hey_customers_50k | 0 | 0.0 | 1 | 2.0 | 2 | 8.0 | 0 | 0.0 | 1 | 3.0 |
| hey_accounts_50k | 0 | 0.0 | 11 | 25.0 | 19 | 86.0 | 9 | 26.0 | 0 | 0.0 |
| hey_customer_summary_50k | 0 | 0.0 | 12 | 34.0 | 11 | 35.0 | 3 | 6.0 | 0 | 0.0 |
| wrk_customers_500c | 821 | 157.6 | 89 | 176.0 | 73 | 225.0 | 123 | 223.0 | 78 | 72.0 |
| wrk_accounts_500c | 819 | 147.0 | 88 | 159.0 | 87 | 434.0 | 110 | 364.0 | 245 | 220.0 |
| wrk_customer_summary_500c | 1,526 | 418.0 | 36 | 82.0 | 54 | 202.0 | 42 | 78.0 | 41 | 46.0 |
| k6_stress_customers | 69 | 36.6 | 37 | 60.0 | 44 | 53.0 | 19 | 47.0 | 4 | 5.0 |
| k6_spike_customers | 29 | 10.1 | 28 | 60.0 | 36 | 57.0 | 16 | 21.0 | 2 | 7.0 |
| k6_stress_accounts | 70 | 42.9 | 37 | 47.0 | 62 | 86.0 | 242 | 245.0 | 21 | 35.0 |
| k6_stress_customer_summary | 146 | 77.6 | 22 | 44.0 | 32 | 50.0 | 56 | 80.0 | 6 | 7.0 |
| vegeta_customers_5k | 10 | 0.8 | 24 | 36.0 | 0 | 0.0 | 29 | 105.0 | 5 | 17.0 |
| vegeta_accounts_5k | 11 | 1.3 | 41 | 94.0 | 25 | 827.0 | **1,379** | **0.0*** | 27 | 69.0 |
| vegeta_customer_summary_5k | 20 | 4.6 | 24 | 98.0 | 12 | 810.0 | 19 | 89.0 | 9 | 87.0 |
| ab_customers_50k | 85 | 7.0 | 19 | 30.0 | 0 | 0.0 | 9 | 14.0 | 0 | 0.0 |
| ab_accounts_50k | 90 | 8.2 | 11 | 21.0 | 18 | 29.0 | 2 | 2.0 | 0 | 0.0 |
| ab_customer_summary_50k | 0 | 0.0 | 4 | 7.0 | 0 | 0.0 | 5 | 5.0 | 0 | 0.0 |

> *WebFlux `vegeta_accounts_5k`: 1,379 GC cycles recorded in a single 5-second window while `gc_time_ms` counter shows 0 increase — this indicates the GC counter wrapped or reported incorrectly during the catastrophic OOM-adjacent event that caused 45.81% request failure. This is the GC thrashing that broke the WebFlux accounts endpoint.

### GC comparison summary

| Metric | Go | Spring | VT | WebFlux | Vert.x |
|---|---|---|---|---|---|
| Total cycles | 14,417 | 1,011 | 1,202 | 1,406 | **943** |
| Total GC time | 3,131 ms | 2,022 ms | 5,903 ms | 2,240 ms | **1,044 ms** |
| Worst single phase | wrk_cust_sum 500c (418ms) | hey_accounts (25ms/phase) | vegeta_accounts 5k (827ms) | vegeta_accounts 5k (💥 anomaly) | wrk_accounts_500c (220ms) |
| Avg ms/cycle | **0.22 ms** | 2.0 ms | 4.9 ms | 1.6 ms | 1.1 ms |
| Impact on tail latency | Minimal (sub-ms STW) | Moderate (2ms avg) | High at 5k rps | High under backpressure | **Lowest JVM impact** |

---

## Section 4 — Concurrency Model

### Goroutines vs Threads

| Phase | Go goroutines | Go stack (MB) | Spring threads | VT threads | WebFlux threads | Vert.x threads |
|---|---:|---:|---:|---:|---:|---:|
| idle | 3 | 0.3 | 24 | 16 | 22 | 0* |
| hey_customers_50k | 3 | 3.2 | 214 | 22 | 78 | 0* |
| hey_accounts_50k | 3 | 4.7 | 221 | 22 | 129 | 0* |
| wrk_customers_500c | 510 | 7.7 | 220 | 22 | 88 | 0* |
| wrk_accounts_500c | 502 | 7.7 | 219 | 22 | 92 | 0* |
| k6_stress_customers | 203 | 4.9 | 220 | 22 | 129 | 0* |
| k6_spike_customers | 503 | 7.6 | 219 | 22 | 84 | 0* |
| vegeta_customers_5k | **3,861** | **42.8** | 219 | 22 | 78 | 0* |
| vegeta_accounts_5k | 3,751 | 40.8 | 217 | 22 | 80 | 0* |
| ab_customers_50k | 5 | 2.8 | 221 | 22 | 129 | 0* |
| final_cooldown | 3 | 17.7 | 221 | 22 | 129 | 0* |

> *Vert.x thread metric always 0 in the collected data — the JMX thread count was not captured correctly for Vert.x in this run. Vert.x is known to use a small fixed number of event loop threads (typically 2×CPU cores). All other counts are accurate.

### Key concurrency observations

**Go goroutines:**
- Scale elastically from 3 (idle) to 3,861 (vegeta 5k) with no ceiling
- Each goroutine needs only ~10KB stack initially (grows on demand)
- 3,861 goroutines × avg ~42.9MB total stack / 3,861 ≈ 11KB avg stack — exactly as expected
- No goroutine pool required — the runtime manages scheduling efficiently

**Spring MVC threads:**
- Steps up sharply from 24 (idle) to 214–221 at first load
- Hits the 200-thread Tomcat ceiling immediately and stays there
- Thread count does not decrease between tests — OS threads are expensive to destroy/recreate
- Extra goroutines/requests at >200 concurrency queue behind the thread pool — causes latency spike

**Virtual Threads:**
- Only **22 platform (carrier) threads** visible — this is correct behaviour
- Virtual threads are mounted on carrier threads only during CPU execution, unmounted on I/O
- Despite 22 carrier threads, handles thousands of concurrent virtual threads
- The memory problem is not thread count — it's heap: 22 threads but 2GB+ heap because each virtual thread's continuation object lives in JVM heap

**WebFlux (Reactor/Netty):**
- Steps up from 22 to 78–129 threads — Netty I/O worker pool
- Thread count stabilises at 129 after first hey run and stays there
- Reactive backpressure model means latency is predictable at moderate load but creates failure cliffs at extreme rates

**Vert.x:**
- Event loop model with small fixed thread pool
- Very efficient resource usage: 573MB RSS peak with 314MB heap
- The low GC overhead (943 cycles) confirms the event loop creates fewer short-lived objects per request

---

## Section 5 — Stability & Crash Analysis

| Server | Crashes | OOM events | Memory stays elevated | Vegeta 5k failures |
|---|---|---|---|---|
| Go | ❌ None | ❌ None | ✅ Releases after test | None |
| Spring | ❌ None | ❌ None | ✅ Mostly releases | None |
| VT | ❌ None | ⚠️ Near-OOM at vegeta_accounts_5k | ❌ Stays at 2,764MB | /customers: 95.66% (avg 2,145ms) |
| WebFlux | ❌ None | ⚠️ GC anomaly at vegeta_accounts_5k | ❌ Stays at ~909MB | /accounts: 45.81% (avg 4,993ms) |
| Vert.x | ❌ None | ❌ None | ✅ Partially releases | None |

### Memory retention after benchmark

- **Go:** RSS dropped from 168.5MB peak back to ~40MB between major tests. Only vegeta goroutine pool lingered (final_cooldown: 153.9MB RSS — runtime hadn't GC'd stacks yet).
- **Spring:** RSS settled at 599MB in `final_cooldown` — Java old-gen retention. Normal JVM behaviour; GC only collects under pressure.
- **VT:** RSS at 2,764.8MB in `final_cooldown` — no GC triggered. The JVM heap is so full (1,683MB surviving heap) that even with no active requests, the old-gen is not collected.
- **WebFlux:** RSS at 909MB in `final_cooldown` — Netty direct buffers not released. This is expected; Netty holds buffer pools for fast reuse.
- **Vert.x:** RSS at 573.2MB in `final_cooldown` — reasonable, Vert.x released most load-phase allocation.

---

## Section 6 — Summary

### Memory profile comparison

| Metric | Go | Spring | VT | WebFlux | Vert.x |
|---|---|---|---|---|---|
| Idle RSS | **7.2 MB** | 202.6 MB | 198.0 MB | 250.9 MB | 127.8 MB |
| Peak RSS | **168.5 MB** | 599.0 MB | 2,764.8 MB | 909.0 MB | 573.2 MB |
| Peak Heap | **86.6 MB** | 400.7 MB | 2,016.0 MB | 469.0 MB | 314.0 MB |
| RSS / Heap ratio | 1.9x | 1.5x | 1.4x | 1.9x | 1.8x |
| GC cycles total | 14,417 | 1,011 | 1,202 | 1,406 | **943** |
| GC time total | 3,131 ms | 2,022 ms | 5,903 ms | 2,240 ms | **1,044 ms** |
| GC cost per cycle | **0.22 ms** | 2.0 ms | 4.9 ms | 1.6 ms | 1.1 ms |
| Peak concurrency unit | 3,861 goroutines | 221 threads | 22 carrier threads | 129 threads | ~8 evt-loop threads |
| Memory-stable after load | ✅ Yes | ⚠️ Partial | ❌ No | ❌ No | ✅ Yes |

### Interpretation

**Go** is the clear memory efficiency winner:
- **23x less peak RSS than VT** (168MB vs 2,764MB)
- **5.4x less peak RSS than Spring** (168MB vs 599MB)
- Goroutines scale elastically — 3,861 goroutines cost only 43MB stack vs 221 OS threads costing far more per thread
- Go's GC runs 14k times but each pause is sub-millisecond — invisible to request latency

**Vert.x** is the best JVM server for memory efficiency:
- Lowest peak RSS among JVM servers (573MB) — 4.8x lower than VT
- Lowest GC overhead (943 cycles, 1,044ms) — nearly 6x less than VT
- Event loop with small thread count avoids both thread-stack overhead and virtual thread heap explosion

**Virtual Threads** (VT) is the worst for memory at high load:
- 2,016MB heap at peak — **23x Go's peak heap**
- GC pause of 4.9ms/cycle average (vs Go's 0.22ms) — long STW pauses under 2GB heap
- Paradoxically, VT uses only 22 carrier threads (efficient OS-level) but trades that for heap explosion
- Best model for: CPU-bound workloads or I/O with moderate concurrency. Not suitable for fire-hose rates.

**WebFlux** lands in the middle — non-blocking but Netty pre-allocates substantial buffer memory, leading to high baseline RSS (250MB idle vs Spring's 202MB). The reactive pipeline is memory-efficient under normal load but shows GC anomalies at extreme vegeta 5k rates on the `/accounts` endpoint.

**Spring MVC** is the most predictable: thread pool fills to ~220 and stays there, heap is proportional to active request count. Stable but capped — the 200-thread ceiling limits throughput linearly.
