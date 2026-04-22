# Profiling Results — Memory, GC & Concurrency: All 5 Servers

**Date:** April 20, 2026  
**Machine:** macOS (Apple Silicon)  
**Go & Spring data:** `results_20260402_201751/` (April 2, 2026)  
**VT, WebFlux, Vert.x data:** `results_new_20260420_151648/` (April 20, 2026)  
**Metrics collected:** every 5s during all test phases via `metrics.csv`

> Throughput and latency results are in [RESULTS_FINAL.md](RESULTS_FINAL.md).

---

## Server Memory Models

| Server | Memory Model | GC | Concurrency Primitive |
|---|---|---|---|
| Go | Stack per goroutine (2–8KB, grows on demand) | Concurrent tri-color mark-sweep, <1ms pauses | Goroutines (M:N, mapped to OS threads) |
| Spring MVC | JVM heap + 1 platform thread per request (1MB stack each) | G1GC, 15–30ms pauses under load | 1 OS thread per concurrent request |
| Virtual Threads | JVM heap + virtual thread objects (few KB each, heap-allocated) | G1GC | ~8 carrier OS threads + unbounded virtual threads |
| WebFlux | JVM heap + Netty NIO direct buffers | G1GC, 9ms max pause measured | Event loop threads (≈CPU count) + bounded elastic pool |
| Vert.x | JVM heap + Netty buffers | G1GC | Event loop threads (≈CPU count) |

---

## 1. Physical Memory (RSS)

RSS = actual physical pages assigned by the OS, measured via `vmmap --summary` on macOS.

### Go vs Spring MVC — phase breakdown

| Phase | Go RSS (MB) | Spring RSS (MB) | Ratio |
|---|---:|---:|---:|
| idle (cold start) | 40.4 | 201.1 | 5.0× |
| under light load | ~45 | ~391 | 8.7× |
| under heavy load | ~170 | ~577 | 3.4× |
| final cooldown | 168.8 | 812.5 | 4.8× |

### VT / WebFlux / Vert.x — phase breakdown

| Server | Idle RSS (MB) | Peak RSS (MB) | Final RSS (MB) |
|---|---:|---:|---:|
| vt | ~260 | 905.0 | ~905 |
| webflux | ~240 | 784.0 | ~784 |
| vertx | ~180 | 471.4 | ~471 |

### All 5 servers — peak RSS comparison

| Server | Peak RSS (MB) | vs Go |
|---|---:|---:|
| go | 196.5 | 1.0× |
| vertx | 471.4 | 2.4× |
| webflux | 784.0 | 4.0× |
| spring | 812.5 | 4.1× |
| vt | 905.0 | 4.6× |

> 🥇 **Best overall:** Go — 196.5 MB  
> 🥈 **Best JVM:** Vert.x — 471.4 MB (2.4× Go vs Spring's 4.1×, no Spring overhead)  
> ⚠️ VT RSS (905 MB) exceeds Spring (812 MB) — virtual thread objects live on the JVM heap, inflating it. The trade-off is 6–8× better throughput on I/O-bound endpoints.

---

## 2. JVM Heap Memory

Spring Actuator `/actuator/metrics/jvm.memory.used` for VT/WebFlux/Spring.  
Vert.x `/memstats` for heap. Go runtime stats for Go heap.

### All 5 servers — peak heap comparison

| Server | Idle Heap (MB) | Peak Heap (MB) | GC Count | Total GC Time (ms) | Max Pause (ms) |
|---|---:|---:|---:|---:|---:|
| go | ~15 | 93.3 | N/A | <10ms total | <1ms |
| spring | ~110 | 502.0 | ~200+ | N/A | ~15–30ms |
| vertx | ~80 | 239.4 | N/A* | N/A* | N/A* |
| webflux | ~110 | 367.2 | 270 | 682 | 9ms |
| vt | ~120 | 618.2 | 261 | 1,263 | 19ms |

> \* Vert.x `/memstats` exposes `heapUsed` / `heapMax` only — GC metrics via ManagementFactory are not wired up.

> 🥇 **Best overall:** Go — 93.3 MB peak heap  
> 🥈 **Best JVM heap:** Vert.x — 239.4 MB (closest to Go; no Spring lifecycle overhead)  
> 🥇 **Best JVM GC:** WebFlux — 682ms total · 9ms max pause (vs VT's 1,263ms · 19ms)  
> 💡 WebFlux generates fewer intermediate objects per request than VT — Netty's NIO path is GC-friendly; VT's Spring MVC interceptor chain allocates more per virtual thread context-switch.

---

## 3. Garbage Collection

### Summary across all servers

| Server | Max Pause | Total GC Time | GC Character |
|---|---:|---:|---|
| go | <1ms | <10ms total | Concurrent, incremental, negligible impact |
| spring | ~15–30ms | not measured | G1GC STW; pauses visible under load spikes |
| vertx | N/A | N/A | G1GC (metrics not plumbed) |
| webflux | 9ms | 682ms | G1GC; clean, NIO-friendly allocation |
| vt | 19ms | 1,263ms | G1GC; higher pressure from VT scheduling objects |

> 🥇 **Best overall:** Go — sub-millisecond concurrent GC, no stop-the-world  
> 🥈 **Best JVM:** WebFlux — 9ms max pause, 682ms total (2× less GC time than VT)  
> 💡 All JVM GC pauses (≤19ms) are well within acceptable production SLAs. Neither VT nor WebFlux shows GC as a bottleneck.

---

## 4. Concurrency

### Go goroutines

| Phase | Goroutines |
|---|---|
| idle | ~8 |
| under 200c load | ~50–200 |
| under 500c load | scales freely |

500 goroutines ≈ 1–4 MB of stack. No OS thread per goroutine — M:N scheduled.

### Spring MVC — platform threads

| Phase | Platform Threads |
|---|---|
| idle | ~21 |
| under 200c load | ~221 |
| under 500c load | 500+ (thread pool exhaustion risk) |

Each thread = ~1 MB OS stack. 500 threads = ~500 MB of stack memory alone.

### Virtual Threads — measured via Actuator

| Phase | Carrier Threads | Total JVM Threads |
|---|---|---|
| idle | ~8 | ~22 |
| hey 50k/500c (500 concurrent VTs) | ~8 | 22 |
| k6 stress 1000 VUs | ~8 | 22 |

**22 platform threads across all load phases.** Project Loom proof: 500–1000 concurrent virtual threads mapped onto 22 OS threads with zero growth. Only `spring.threads.virtual.enabled=true` separates this from Spring MVC's 221+ threads.

### WebFlux — measured via Actuator

| Phase | Total JVM Threads |
|---|---|
| idle | ~129 |
| under full load | 129 |

129 threads: ~8 Netty event loop + worker threads + `boundedElastic` pool + Spring Boot internals. Higher than expected for a reactive stack — Spring Boot adds overhead even on Netty.

### Vert.x — inferred

~8–16 threads (Netty event loop + Vert.x worker pool). Thread count not exposed via `/memstats`. Lowest theoretical thread overhead of all JVM servers.

### Concurrency summary — all 5 servers

| Server | Model | Platform Threads under 1000 VUs |
|---|---|---|
| go | Goroutines (M:N) | ~8–16 OS threads total |
| spring | 1 thread / request | ~221 |
| vt | Virtual Threads (Loom) | **22** |
| webflux | Netty event loop + elastic | 129 |
| vertx | Netty + coroutines | ~8–16 |

> 🥇 **Best overall:** Go — ~8–16 OS threads serving unlimited goroutines  
> 🥈 **Best JVM:** VT — **22 platform threads** serving 500–1000 concurrent requests (leanest JVM server by measured thread count)  
> ⚠️ Spring MVC would reach 500+ threads at 500c — OS context-switch overhead and stack memory become significant

---

## 5. Peak Metrics Summary

| Server | Peak RSS (MB) | Peak Heap (MB) | Peak Threads | Data source |
|---|---:|---:|---:|---|
| go | 196.5 | 93.3 | ~8–16 goroutine OS threads | April 2, 2026 |
| spring | 812.5 | 502.0 | 221 | April 2, 2026 |
| vt | 905.0 | 618.2 | 22 | April 20, 2026 |
| webflux | 784.0 | 367.2 | 129 | April 20, 2026 |
| vertx | 471.4 | 239.4 | ~8–16 (not metered) | April 20, 2026 |

> 🥇 **Best RSS:** Go (196.5 MB) | **Best JVM RSS:** Vert.x (471.4 MB)  
> 🥇 **Best heap:** Go (93.3 MB) | **Best JVM heap:** Vert.x (239.4 MB)  
> 🥇 **Best JVM thread count:** VT (22 — measured under full load)

---

## 6. Why Virtual Threads Beat Platform Threads

| Dimension | Platform Thread (Spring MVC) | Virtual Thread (VT) |
|---|---|---|
| Stack size | ~1 MB (OS stack) | ~few hundred bytes (JVM heap object) |
| Context switch cost | ~1–5μs (OS scheduler) | ~100ns (JVM unmount/remount) |
| I/O blocking | OS thread blocked — unusable | Carrier thread released immediately |
| Code style | Blocking (natural) | Blocking (natural) — no API change |
| 500 concurrent requests | 500 OS threads (~500 MB stack) | ~8 carrier threads + 500 VT objects |

---

## 7. Why Reactive (WebFlux / Vert.x) Has an Edge in Raw Throughput

- Event loop threads **never block** — zero OS thread waste on I/O waits
- No thread creation/destruction under load spikes
- Netty zero-copy NIO buffers reduce GC allocation per request
- `Mono.zip()` / `coroutineScope { async{} }` for fan-out with no thread parking

Trade-off: reactive programming model is more complex. Vert.x Kotlin coroutines are more ergonomic than WebFlux Reactor chains but still require understanding async execution.

---

## 8. Conclusions

### Memory

| Winner | Detail |
|---|---|
| **Go** | 196.5 MB RSS · 93.3 MB heap — baseline for all comparisons |
| **Vert.x (best JVM)** | 471.4 MB RSS · 239.4 MB heap — no Spring lifecycle overhead, bare Netty |
| VT uses most RSS | 905 MB > Spring's 812 MB — virtual thread objects live on heap; acceptable given throughput gains |

### GC

| Winner | Detail |
|---|---|
| **Go** | Concurrent GC, <1ms pauses, negligible total GC time |
| **WebFlux (best JVM)** | 9ms max pause · 682ms total — Netty NIO allocation is GC-friendly |
| VT higher GC pressure | 19ms max · 1,263ms total — Spring interceptor chain + VT scheduling allocates more objects |

### Concurrency

| Winner | Detail |
|---|---|
| **Go** | M:N goroutines, ~8–16 OS threads serve all load |
| **VT (best JVM)** | 22 platform threads under 1000 VUs — strongest proof of Project Loom |
| WebFlux unexpectedly high | 129 threads — Spring Boot adds thread pools even on Netty |
| Vert.x leanest reactive | ~8–16 threads — closest to Go's model among JVM servers |

### Overall Recommendation

| Use case | Choose |
|---|---|
| Maximum throughput + minimum resources | **Vert.x** — best JVM RSS, heap, and throughput; requires coroutine familiarity |
| Spring migration with minimal code change | **Virtual Threads** — one config flag, 6–8× better than Spring MVC, 22 platform threads |
| Existing Reactor/R2DBC ecosystem | **WebFlux** — cleaner GC than VT, reactive ecosystem integration |
| Avoid entirely for I/O-bound high-concurrency | **Spring MVC** — thread pool exhaustion is architectural, not tunable |
