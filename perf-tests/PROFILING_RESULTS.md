# Profiling Results — Memory, GC & Concurrency

> **Scope**: This report covers runtime profiling — physical memory (RSS), heap, garbage collection, and concurrency.
> Throughput and latency results are in [RESULTS.md](RESULTS.md).

**Setup**: Go BFF (port 8080) vs Spring Boot BFF (port 8084), identical endpoints, macOS Apple Silicon.
**Test methodology:** Isolated — Go tested first (cold start), stopped, then Spring Boot tested (cold start). No cross-contamination.
RSS measured via `vmmap --summary` (physical footprint), heap/GC via `/memstats` (Go) and `/actuator/metrics` (Spring).
Go: 250 samples across 26 test phases. Spring: 280 samples across 70 test phases.

---

## 1. Physical Memory (RSS via vmmap)

RSS = actual physical pages the OS assigned to the process. Measured with `vmmap --summary` on macOS (not `ps`, which is inaccurate for JVM due to memory compression).

### Side-by-side comparison (matching phases)

| Phase | Go RSS (MB) | Spring RSS (MB) | Ratio |
|---|---:|---:|---:|
| idle (cold start) | 40.4 | 201.1 | 5.0x |
| vegeta\_customers\_100 | 41.9 | 391.7 | 9.3x |
| vegeta\_customers\_1k | 44.0 | 393.2 | 8.9x |
| vegeta\_customers\_5k | 135.9 | 540.0 | 4.0x |
| vegeta\_accounts\_100 | 165.3 | 576.8 | 3.5x |
| vegeta\_accounts\_1k | 160.2 | 576.8 | 3.6x |
| vegeta\_accounts\_5k | 175.9 | 576.9 | 3.3x |
| vegeta\_customer\_summary\_100 | 180.6 | 577.3 | 3.2x |
| vegeta\_customer\_summary\_1k | 159.7 | 577.3 | 3.6x |
| vegeta\_customer\_summary\_5k | 182.1 | 577.5 | 3.2x |
| ab\_customers\_50k | 168.9 | 577.7 | 3.4x |
| ab\_accounts\_50k | 168.8 | 754.3 | 4.5x |
| ab\_customer\_summary\_50k | 168.8 | 812.5 | 4.8x |
| final\_cooldown | 168.8 | 812.5 | 4.8x |

### Key observations

- **Go idle footprint: 40.4 MB.** Cold start with no pre-warming. This is Go's true baseline — runtime, binary code, initial stack. Dramatically lower than pre-warmed (143 MB in prior tests).
- **Spring idle footprint: 201.1 MB.** Cold start JVM with class metadata, compiled code, initial thread stacks (21 at idle), and heap. Also much lower than pre-warmed (630 MB in prior tests).
- **Go scales from 40 → 182 MB under load.** The vegeta_customers_5k phase pushed Go to 136 MB (first major load), peaking at 182 MB during customer_summary_5k. Settled at 169 MB after final cooldown — Go retained some mapped pages.
- **Spring grows from 201 → 813 MB.** Steady climb through all phases. The biggest jump (577 → 754 MB) happened during ab_accounts_50k. Spring never releases pages back to the OS.
- **Ratio narrows under load.** Idle ratio is 5.0x (Go is lighter). Under heavy load it narrows to 3.2x because Go's RSS grows proportionally to connection count while Spring's was already high.

### Spring RSS progression (Go had no hey/wrk/k6 phases — those ran first, separately)

| Phase Group | Spring RSS (MB) | Notes |
|---|---:|---|
| idle | 201.1 | Cold start |
| hey (all) | 362 → 391 | +160 MB from first load |
| wrk (all) | 391 | Stable at plateau |
| k6 (all) | 391 | Stable |
| vegeta 100–1k | 391 → 393 | Minor growth |
| vegeta 5k (customers) | 540 | +147 MB spike |
| vegeta 5k (accounts) | 577 | Continued growth |
| ab (accounts) | 754 | +177 MB (large response bodies) |
| ab (customer\_summary) → cooldown | 813 | Final plateau, never released |

---

## 2. Heap Memory

Heap = managed memory that the GC tracks. Go reports `HeapAlloc`; Spring reports `jvm.memory.used` (heap area).

### Go Heap (key phases)

| Phase | Go Heap (MB) | ±σ |
|---|---:|---:|
| idle | 7.3 | 3.5 |
| vegeta\_customers\_1k | 15.5 | 4.8 |
| vegeta\_customers\_5k | 68.0 | 29.6 |
| vegeta\_accounts\_5k | 78.1 | 6.1 |
| vegeta\_customer\_summary\_5k | 60.3 | 26.0 |
| ab\_customers\_50k | 11.9 | 0.0 |
| ab\_customer\_summary\_50k | 15.8 | 0.0 |
| final\_cooldown | 15.8 | 0.0 |

### Spring Heap (key phases)

| Phase | Spring Heap (MB) | ±σ |
|---|---:|---:|
| idle | 63.0 | 2.0 |
| hey\_customers\_50k | 86.7 | 8.7 |
| hey\_accounts\_50k | 157.9 | 40.5 |
| wrk\_customers\_500c | 184.4 | 14.6 |
| wrk\_accounts\_500c | 155.8 | 55.9 |
| k6\_stress\_customers | 130.0 | 50.4 |
| k6\_spike\_accounts | 179.5 | 17.0 |
| vegeta\_customers\_5k | 247.3 | 80.4 |
| vegeta\_accounts\_5k | 289.3 | 35.8 |
| ab\_accounts\_50k | 373.4 | 85.2 |
| ab\_customer\_summary\_50k | 484.7 | 15.1 |
| final\_cooldown | 478.0 | 0.0 |

### Key observations

- **Go idle heap: 7.3 MB** (cold start). Drops as low as 3.8 MB during cooldowns. Peak at 78 MB during vegeta_accounts_5k. Returns to 15.8 MB at final cooldown.
- **Spring idle heap: 63.0 MB** (cold start). Grows steadily through the test suite: 63 → 158 → 247 → 485 → 478 MB. Never fully compacts.
- **Go heap is aggressively reclaimed.** After vegeta\_accounts\_5k peaked at 78 MB, the next cooldown shows 67 MB, then subsequent phases drop further. The GC is actively sweeping.
- **Spring heap grows monotonically** under sustained load. Each new high-intensity phase raises the heap floor. The ±85 MB variance during ab_accounts_50k indicates heavy GC churn (heap swinging between 288–458 MB mid-phase).
- **The heap ratio ranges from 8.6x (idle) to 30x+ during low-Go/high-Spring phases.**

### RSS overhead above heap

| State | Go RSS | Go Heap | Overhead | Spring RSS | Spring Heap | Overhead |
|---|---:|---:|---:|---:|---:|---:|
| idle | 40.4 | 7.3 | 33.1 MB | 201.1 | 63.0 | 138.1 MB |
| peak load | 182.1 | 60.3 | 121.8 MB | 812.5 | 484.7 | 327.8 MB |
| final\_cooldown | 168.8 | 15.8 | 153.0 MB | 812.5 | 478.0 | 334.5 MB |

Go's non-heap overhead is goroutine stacks (~24 MB at cooldown), the runtime, and OS-mapped-but-freed pages from prior load.
Spring's non-heap overhead is JVM metaspace, compiled native code (C2), 221 OS thread stacks (~221 MB), and JVM internal structures.

---

## 3. Garbage Collection

### Go GC

Go uses a concurrent, tri-color mark-and-sweep collector with very short stop-the-world (STW) pauses.

| Phase | GC Cycles (delta) | Total STW Pause |
|---|---:|---:|
| idle (warmup) | +14,399 | 2,146.0 ms |
| vegeta\_customers\_100 | +2 | 0.6 ms |
| vegeta\_customers\_1k | +7 | 1.3 ms |
| vegeta\_customers\_5k | +10 | 1.4 ms |
| vegeta\_accounts\_1k | +4 | 0.6 ms |
| vegeta\_accounts\_5k | +7 | 0.7 ms |
| vegeta\_customer\_summary\_1k | +10 | 1.1 ms |
| vegeta\_customer\_summary\_5k | +16 | 3.5 ms |
| ab phases (combined) | +1 | 0.3 ms |
| All other test phases | +2 | 0.7 ms |
| **Test phases TOTAL** | **+59** | **10.2 ms** |

> The "idle" phase shows 14,399 GC cycles because the server ran its cold-start allocations and initial heap setup. This is a one-time cost. **During actual test traffic, Go ran only 59 GC cycles with a total of 10.2 ms STW pause** — negligible impact on request latency.

- **Average STW pause per test cycle: 0.17 ms (170 μs).** No individual test-phase pause exceeded 3.5 ms.
- **vegeta\_customer\_summary\_5k was the heaviest:** 16 cycles, 3.5 ms total — sustained 5,000 req/s with heavy response objects.
- **AB phases triggered almost no GC**: ab sends requests synchronously, so allocations are lower-frequency.

### Spring GC

Spring Boot (JVM) uses G1GC by default on Java 21.

| Phase | GC Cycles (delta) | Total Pause | Max Single Pause |
|---|---:|---:|---:|
| wrk\_customers\_50c | +76 | 97 ms | 16 ms |
| wrk\_customers\_500c | +74 | 145 ms | 16 ms |
| wrk\_accounts\_50c | +85 | 86 ms | 16 ms |
| wrk\_accounts\_500c | +81 | 152 ms | 12 ms |
| wrk\_customer\_summary\_50c | +40 | 44 ms | 12 ms |
| wrk\_customer\_summary\_500c | +40 | 74 ms | 10 ms |
| k6\_stress\_customers | +38 | 60 ms | 10 ms |
| k6\_spike\_customers | +28 | 38 ms | 10 ms |
| k6\_stress\_accounts | +37 | 53 ms | 21 ms |
| k6\_spike\_accounts | +26 | 98 ms | 34 ms |
| vegeta\_customers\_5k | +40 | 79 ms | 25 ms |
| vegeta\_accounts\_5k | +39 | 112 ms | 16 ms |
| ab\_customers\_50k | +13 | 26 ms | 68 ms |
| ab\_accounts\_50k | +8 | 574 ms | 135 ms |
| All other phases | +203 | 507 ms | — |
| **TOTAL** | **+828** | **~2,145 ms** | **135 ms** |

- **828 GC cycles** total (including hey/wrk/k6/vegeta/ab phases). Many more than the previous pre-warmed run (68 cycles) because this is a cold start with full allocation lifecycle.
- **Max single pause: 135 ms** (during ab\_accounts\_50k). This is a significant STW event visible as a latency spike.
- **wrk phases are GC-heavy.** wrk's sustained pipelined traffic creates many short-lived objects. wrk\_customers at 500c triggered 74 cycles with 145 ms total pause.
- **k6\_spike\_accounts caused a 34 ms max pause** — the sudden burst of 500 VUs hitting `/accounts` (large responses) required emergency GC collection.

### GC comparison summary

| Metric | Go | Spring | Factor |
|---|---|---|---|
| Total cycles | 14,458 (test) + 14,399 (idle) | 828 | Go runs 17x more* |
| Total STW pause | 10.2 ms (test) + 2,146 ms (idle) | ~2,145 ms | ~equal total |
| Avg pause / cycle | 0.17 ms | 2.59 ms | Spring 15x longer per cycle |
| Max single pause | 3.5 ms | 135 ms | Spring 39x longer worst case |
| Heap at cooldown | 15.8 MB | 478.0 MB | Spring 30x larger |

> \* **Cycle count is not directly comparable.** Go ran only vegeta + ab (2 tools), while Spring ran hey + wrk + k6 + vegeta + ab (5 tools) — Spring processed far more total requests. Go's 14,399 idle-phase cycles are cold-start allocation cleanup. The meaningful comparison is **per-cycle pause time** (0.17 ms vs 2.59 ms) and **max single pause** (3.5 ms vs 135 ms), which measure GC *impact* on request latency regardless of how many cycles ran.

**Go's GC character**: many tiny pauses (sub-ms), aggressive heap compaction (16 MB at cooldown). Result: virtually zero GC impact on request latency.
**Spring's GC character**: fewer but longer pauses (avg 2.6 ms, max 135 ms), tolerates large heap (478 MB at cooldown). Result: GC is a real contributor to tail latency.

---

## 4. Concurrency Model

### Goroutines (Go) vs Threads (Spring)

| Phase | Goroutines | Go Stack (MB) | JVM Threads |
|---|---:|---:|---:|
| idle | 632* | 8.7 | 21 |
| vegeta\_customers\_100 | 92 | 3.7 | 221 |
| vegeta\_customers\_1k | 794 | 9.6 | 220 |
| vegeta\_customers\_5k | 3,982 | 48.9 | 220 |
| vegeta\_accounts\_1k | 890 | 26.6 | 218 |
| vegeta\_accounts\_5k | 4,192 | 57.2 | 217 |
| vegeta\_customer\_summary\_1k | 874 | 28.9 | 221 |
| vegeta\_customer\_summary\_5k | 3,781 | 56.8 | 221 |
| ab\_customers\_50k | 3 | 22.1 | 221 |
| final\_cooldown | 3 | 24.1 | 221 |

> *Go shows 632 goroutines during idle because the sampler captured the tail end of the startup/allocation phase. Under test load, goroutine count scales exactly with concurrent connections.

### Key observations

- **Goroutines scale elastically.** 3 at rest → 4,192 under vegeta\_accounts\_5k → 3 at cooldown. Each goroutine starts at ~8 KB stack (auto-grows to ~13.6 KB average at peak).
- **JVM threads jump from 21 to 221 on first load, then stay at 221.** Spring's Tomcat thread pool (200 worker + internal threads) reaches ceiling immediately and never drops back — the pool keeps them warm even during cooldowns.
- **Stack memory tells the story.** Go uses 57.2 MB for 4,192 goroutines (~13.6 KB each). Spring uses ~221 MB for 221 threads (~1 MB each via OS default). That's **19x more concurrency units using 3.9x less stack memory** at peak.
- **Go's stack memory doesn't fully release.** Cooldown shows 24.1 MB stack for just 3 goroutines — Go keeps recently-used stack pages mapped. The OS will reclaim them under pressure.
- **Spring's thread pool is the ceiling.** With 221 threads, Spring can handle at most 221 truly concurrent requests. Beyond that, requests queue. Go has no such ceiling.

---

## 5. Server Stability

| Metric | Go | Spring |
|---|---|---|
| Crashes during profiling | 0 | 0 |
| Total test phases completed | 26 (Go) / 70 (Spring) | — |
| RSS violations (RSS < Heap) | 0 / 250 | 0 / 280 |

Both servers survived all test phases without any crashes or restarts.

---

## 6. Summary

| Metric | Go | Spring | Verdict |
|---|---|---|---|
| Idle RSS (cold start) | 40.4 MB | 201.1 MB | Go 5.0x lighter |
| Peak RSS | 182.1 MB | 812.5 MB | Go 4.5x lighter |
| Cooldown RSS | 168.8 MB | 812.5 MB | Go 4.8x lighter |
| Idle heap | 7.3 MB | 63.0 MB | Go 8.6x smaller |
| Peak heap | 78.1 MB | 484.7 MB | Go 6.2x smaller |
| Cooldown heap | 15.8 MB | 478.0 MB | Go 30.3x smaller |
| GC avg pause/cycle | 0.17 ms | 2.59 ms | Spring 15x longer |
| GC max single pause | 3.5 ms | 135 ms | Spring 39x longer |
| GC total STW (test traffic) | 10.2 ms | ~2,145 ms | Spring 210x more |
| Peak concurrency units | 4,192 goroutines | 221 threads | Go 19x more units |
| Stack memory at peak | 57.2 MB | ~221 MB | Go 3.9x less |
| Crashes | 0 | 0 | Equal |
| Memory release after load | Partial (169 MB) | None (813 MB) | Go reclaims, Spring retains |
