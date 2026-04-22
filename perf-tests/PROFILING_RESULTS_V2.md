# Profiling Results V2 — Memory, GC & Concurrency (All 5 Servers)

> **Scope**: Runtime profiling — physical memory (RSS), heap, GC, and concurrency primitives.
> Throughput and latency results are in [RESULTS_V2.md](RESULTS_V2.md).

**Setup**: All 5 servers tested sequentially in a single unified run (Apr 20, 2026).  
**Methodology:** Each server started cold, sampled every 5s throughout the full test lifecycle (idle → hey → k6 → ab → cooldown), then stopped before the next server started.  
**Sampling:** Go: `/memstats` endpoint (HeapAlloc, NumGoroutine, GC stats). Spring/VT/WebFlux: `/actuator/metrics` (JVM heap, threads, GC pause time + count). Vert.x: `/memstats` (custom endpoint, same schema). RSS measured via `vmmap --summary` (physical footprint, macOS).

| Server | Samples | Crashes |
|---|---|---|
| Go | 156 | 0 |
| Spring Boot | 163 | 0 |
| Virtual Threads | 159 | 0 |
| WebFlux | 158 | 0 |
| Vert.x | 157 | 0 |

---

## 1. Physical Memory (RSS)

RSS = actual physical pages assigned by the OS. Measured with `vmmap --summary` (more accurate than `ps` on macOS, especially for JVM processes with compressed memory).

### Peak RSS across the full test run

| Server | Peak RSS (MB) | Notes |
|---|---|---|
| 🥇 go | **44.9** | Goroutine-per-request, no JVM overhead |
| 🥈 spring | 440.2 | Tomcat + class metadata + thread stacks |
| vertx | 442.0 | Similar to Spring at peak despite reactive model |
| vt | 730.5 | **Highest JVM** — virtual thread overhead accumulates under load |
| webflux | 926.5 | **Highest of all** — Netty buffers + reactive pipeline allocations |

### Key observations

- **Go's RSS is ~10–20x lower** than JVM servers. The binary is small, the goroutine stack is 2–8KB vs 512KB–1MB per OS thread, and there is no JVM metadata overhead.
- **WebFlux RSS (926MB) exceeds even VT (730MB)** despite using fewer threads. Netty's off-heap byte buffer pools contribute substantially to physical footprint — these appear in RSS but not heap metrics.
- **Vert.x (442MB) nearly matches Spring (440MB)** despite its reactive architecture. Both run on the JVM with similar startup class-loading overhead.
- **VT (730MB) is highest JVM heap user** — the virtual thread scheduler itself has per-carrier-thread overhead, and VT's heap allocations during load were higher than other JVM servers.

---

## 2. Heap Memory

Heap = managed memory tracked by the GC. Go reports `HeapAlloc`; JVM servers report `jvm.memory.used` (heap area).

### Peak Heap

| Server | Peak Heap (MB) | Notes |
|---|---|---|
| 🥇 go | **20.1** | Live heap only — GC keeps this tight |
| 🥈 vertx | 200.6 | Well-managed heap for a JVM server |
| spring | 204.9 | Close to Vert.x at peak |
| webflux | 440.2 | ~2x Spring despite reactive design |
| vt | 503.9 | **Highest heap** — virtual thread continuations contribute to allocation pressure |

### Observations

- **Go heap (20 MB peak)** is 10–25x smaller than JVM peers. Go's escape analysis keeps many objects stack-allocated; the GC runs concurrently and collects eagerly.
- **VT heap is the highest JVM at 504MB.** Virtual thread continuations are heap-allocated objects — each blocked vthread parks its stack frame on the heap, driving allocation under load.
- **WebFlux heap (440MB) is surprising** — Reactor/Netty's publisher chains, FluxSink, and Mono/Flux wrappers generate significant short-lived allocations per request.
- **Vert.x and Spring are comparable (~200MB)** despite very different architectures. Spring's objects are fewer but larger; Vert.x creates many small event/handler objects.

---

## 3. Garbage Collection

### GC time and cycle count (cumulative across full test run)

| Server | GC Time (ms) | GC Cycles | Avg ms/cycle | Notes |
|---|---|---|---|---|
| 🥇 go | 321 | 1,024 | **0.31ms** | Sub-ms concurrent GC — 1024 very fast collections |
| 🥈 vertx | 329 | 141 | 2.33ms | Fewest cycles, moderate pause |
| webflux | 492 | 225 | 2.19ms | Low cycle count, moderate pause |
| spring | 673 | 333 | 2.02ms | More cycles than reactive servers |
| vt | 2,000 | 320 | **6.25ms** | **Highest GC time** — 6x Go total |

### Observations

- **Go runs 1,024 GC cycles in 321ms total** — each cycle costs ~0.3ms and runs concurrently with application threads. No stop-the-world pauses visible in latency data.
- **VT has 2,000ms total GC time** — 6x more than Go, and 3x more than Spring. The combination of virtual thread continuation objects + heap pressure produces frequent, longer G1 pauses.
- **Vert.x has fewest GC cycles (141)** despite being reactive. The event-loop model minimizes object churn — fewer per-request allocations, fewer GC triggers.
- **WebFlux GC is moderate (492ms, 225 cycles)** — reactive chains generate allocations but the Netty buffer pool reuse limits pressure somewhat.
- **Spring GC (673ms, 333 cycles)** — classic servlet model allocates request/response wrappers per request, driving more frequent collections than reactive alternatives.

---

## 4. Concurrency Primitives

### Peak concurrency at max load

| Server | Model | Peak Concurrency | Notes |
|---|---|---|---|
| go | Goroutines | **682 goroutines** | Lightweight — 2–8KB each |
| spring | OS Threads | 221 threads | Tomcat pool, 200 workers |
| webflux | OS Threads | 129 threads | Netty event loops + small worker pool |
| vt | Virtual Threads | 22 carrier threads | JVM-managed, thousands of vthreads possible |
| vertx | N/A (event loop) | — | Not exposed via memstats endpoint |

### Observations

- **Go spawned 682 goroutines** during peak load — each goroutine costs ~2–8KB vs 512KB–1MB per OS thread. 682 goroutines cost less memory than 22 OS threads.
- **VT reports 22 carrier threads** (the OS threads backing the virtual thread scheduler). The actual number of virtual threads in flight is orders of magnitude higher but not directly exposed in the sampled metric. The low carrier count (22) is the main point — massive I/O parallelism on very few OS threads.
- **Spring peaks at 221 threads** — close to Tomcat's default 200-worker limit. At this count, any additional concurrency triggers queueing, explaining Spring's burst degradation vs reactive servers.
- **WebFlux uses 129 threads** — fewer than Spring because Netty's event loop handles I/O on a small fixed pool. Worker threads only run for CPU-bound post-decode work.
- **Vert.x thread data not available** — the `/memstats` endpoint for Vert.x does not expose OS thread counts in this schema. Based on Vert.x's event loop model, expect 2×CPU threads (≈16 on M-series) at peak.

---

## 5. Peak Summary Table

| Server | Peak RSS (MB) | Peak Heap (MB) | GC Time (ms) | GC Cycles | Concurrency |
|---|---|---|---|---|---|
| **go** | **44.9** | **20.1** | 321 | 1,024 | 682 goroutines |
| **spring** | 440.2 | 204.9 | 673 | 333 | 221 threads |
| **vt** | 730.5 | 503.9 | 2,000 | 320 | 22 carrier threads |
| **webflux** | 926.5 | 440.2 | 492 | 225 | 129 threads |
| **vertx** | 442.0 | 200.6 | 329 | 141 | — |

---

## 6. Conclusions

### Memory
Go uses **10–20x less physical memory** than any JVM server. JVM baseline overhead alone (class metadata, JIT compiled code, initial heap reservation) costs 200–440MB before any request is served. Go's binary contains only compiled native code — no runtime metadata, no managed heap warm-up cost.

**Among JVM servers:** Vert.x and Spring have the smallest RSS (~440MB), matching their smaller heap profiles. WebFlux is the memory-heaviest JVM server despite being reactive, due to Netty's off-heap buffer pools.

### GC
Go's concurrent, sub-ms GC makes 1,024 tiny collections invisible to latency. JVM G1GC pauses are 2–6ms each and explain the occasional p95/p99 spikes seen in k6 spike scenarios.

VT's 2,000ms total GC time is **the standout concern** — virtual thread continuations are heap objects. Under spike load, VT's GC pressure produced the worst spike p95 of any JVM server (126ms on accounts). This is the key trade-off for Virtual Threads: simple programming model, but heap pressure under burst load.

### Concurrency model and memory trade-off

| Model | Memory cost | Concurrency ceiling | Spike resilience |
|---|---|---|---|
| Go goroutines | Very low (2–8KB each) | Virtually unlimited | Excellent |
| VT virtual threads | High (continuation on heap) | Very high (but GC pressure) | Poor under burst |
| WebFlux reactive | Medium-high (Netty buffers) | High (event loop) | Moderate |
| Vert.x reactive | Low-medium (event loop) | High | Good except customers spike |
| Spring thread-per-request | Medium (OS threads) | Capped at 200 | Moderate (steady) |

### Overall verdict
- **Go** is the clear winner on every resource efficiency axis: smallest memory, fastest GC, highest concurrency per byte.
- **Vert.x** is the best JVM choice for pure throughput on burst workloads (competitive with Go on customers at 500c), with the lowest GC overhead of any JVM server.
- **Spring** trades resource efficiency for programming simplicity and surprising k6 stress steadiness — within 4% of Go on sustained low-spike load.
- **Virtual Threads** deliver Java's simplest async model but at a real memory and GC cost under burst load.
- **WebFlux** has the highest RSS of any server — Netty's buffer management is optimized for raw throughput, not memory economy.
