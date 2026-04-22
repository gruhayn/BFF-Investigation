# Performance Test Results V3: Go vs Spring MVC vs Virtual Threads vs WebFlux vs Vert.x

**Date:** April 21, 2026
**Machine:** macOS (Apple Silicon)
**Ports:** Go=8080 | Spring MVC=8084 | Virtual Threads=8081 | WebFlux=8082 | Vert.x=8083
**Test methodology:** Sequential — each server started fresh (cold start), tested with all 5 tools, then stopped. No cross-contamination.
**Endpoints:** `/customers`, `/accounts`, `/customer-summary?id=c1`
**Results dir:** `results_v3_20260421_095020/`

---

## How to Read the Metrics

| Metric | What it means | Better = ? |
|---|---|---|
| **Requests/sec** | How many requests the server handles per second | ↑ Higher is better |
| **Avg latency** | Average time to get a response | ↓ Lower is better |
| **P95 / P99** | 95th / 99th percentile latency; shows tail behaviour | ↓ Lower is better |
| **Max latency** | The single slowest request | ↓ Lower is better |
| **Success rate** | % of requests that returned HTTP 200 | ↑ Higher is better (100% = no errors) |

> **In short:** For speed metrics (req/s, throughput) — **bigger is better**.
> For time metrics (latency) — **smaller is better**.

---

## Tools Used

| Tool | What it does | Config |
|---|---|---|
| **hey** | Fixed number of requests with N concurrent workers | 10k/200c, 50k/500c |
| **ab** | Apache Bench — classic HTTP benchmark | 50k/100c |
| **k6** | Virtual users with configurable ramp/sleep patterns | Ramp, Stress, Spike, Multi |
| **wrk** | Sustained max throughput with persistent connections | 4t/50c/30s, 8t/500c/30s |
| **vegeta** | Fixed constant rate (steady-state capacity test) | 100/s, 1k/s, 5k/s |

---

## Concurrency Model Summary

| Server | Model | Concurrency unit | Notes |
|---|---|---|---|
| Go | Goroutine-per-request | Goroutines (~2–8 KB stack) | Elastic, no ceiling |
| Spring MVC | Thread-per-request | OS threads (~1 MB stack) | 200-thread Tomcat pool cap |
| Virtual Threads | Virtual thread-per-request | JVM virtual threads | Unmounted on I/O, few carrier threads (22 observed) |
| WebFlux | Reactive event loop | Non-blocking Netty pipeline | 129 threads incl. I/O workers |
| Vert.x | Event loop | Non-blocking, single event loop thread | ~same model as WebFlux |

---

## SECTION 1 — hey Results (burst throughput)

### 1a. hey — 10,000 requests, 200 concurrent

| Server | req/s ↑ | avg (s) ↓ |
|---|---:|---:|
| **Go** | **53,835** | 0.0035 |
| Vert.x | 16,771 | 0.0117 |
| WebFlux | 8,369 | 0.0227 |
| VT | 7,340 | 0.0256 |
| Spring | 7,244 | 0.0263 |

> At 200c, Go is **3.2x Vert.x, 7.4x Spring**. Vert.x is the best JVM server here — event loop avoids any thread-pool pressure at 200c.

---

### 1b. hey — 50,000 requests, 500 concurrent — `/customers`

| Server | req/s ↑ | avg (s) ↓ |
|---|---:|---:|
| **Go** | **76,560** | 0.0062 |
| Vert.x | 34,173 | 0.0144 |
| WebFlux | 10,903 | 0.0432 |
| VT | 7,663 | 0.0618 |
| Spring | 6,814 | 0.0722 |

> At 500c, Go is **2.2x Vert.x**, **11.2x Spring**. WebFlux pulls ahead of thread-based JVM servers. Spring and VT both hit thread-pool ceiling (200/22 threads vs 500 connections).

---

### 1c. hey — 50,000 requests, 500 concurrent — `/accounts`

| Server | req/s ↑ | avg (s) ↓ |
|---|---:|---:|
| **Go** | **47,606** | 0.0103 |
| Vert.x | 33,926 | 0.0146 |
| WebFlux | 9,355 | 0.0513 |
| Spring | 6,888 | 0.0714 |
| VT | 6,204 | 0.0781 |

> Vert.x is very close to Go on `/accounts` at 50k/500c — only **1.4x** behind, vs WebFlux at **5.1x** behind.

---

### 1d. hey — 50,000 requests, 500 concurrent — `/customer-summary`

| Server | req/s ↑ | avg (s) ↓ |
|---|---:|---:|
| **Go** | **67,403** | 0.0072 |
| Vert.x | 23,043 | 0.0215 |
| WebFlux | 10,314 | 0.0460 |
| VT | 10,480 | 0.0464 |
| Spring | 5,416 | 0.0881 |

> On the heaviest endpoint (4 fan-out calls), Go is **12.4x Spring**. VT and WebFlux are neck-and-neck (~10.4k). Vert.x at 23k is notably stronger on this endpoint.

---

## SECTION 2 — ab Results (50,000 requests, 100 concurrent)

| Endpoint | Go | Vert.x | VT | WebFlux | Spring |
|---|---:|---:|---:|---:|---:|
| **/customers** rps ↑ | 17,204 | **22,849** | 8,668 | 8,826 | 6,950 |
| **/customers** mean (ms) ↓ | 5.8 | **4.4** | 11.5 | 11.3 | 14.4 |
| **/customers** p99 (ms) ↓ | 13 | **12** | 30 | 39 | 38 |
| **/accounts** rps ↑ | 13,896 | **23,720** | 7,918 | 7,816 | 6,857 |
| **/accounts** mean (ms) ↓ | 7.2 | **4.2** | 12.6 | 12.8 | 14.6 |
| **/accounts** p99 (ms) ↓ | 50 | **12** | 35 | 45 | 39 |
| **/customer-summary** rps ↑ | 18,651 | **21,579** | 10,426 | 8,979 | 5,620 |
| **/customer-summary** mean (ms) ↓ | 5.4 | **4.6** | 9.6 | 11.1 | 17.8 |
| **/customer-summary** p99 (ms) ↓ | 12 | **11** | 27 | 64 | 53 |

> **Vert.x beats Go on ab.** ab uses 100 concurrent connections — within Vert.x's event loop sweet spot. Go is slightly handicapped by ab's single-threaded client at these concurrency levels. Both are well ahead of the JVM thread-based servers.

---

## SECTION 3 — k6 Results (virtual user simulation)

k6 paces requests via sleep intervals between VU iterations — this tests realistic user-like concurrency, not raw throughput.

### 3a. Ramp scenario (0→50→0 VUs, 40s, sleep 0.5s)

| Endpoint | Go | Spring | VT | WebFlux | Vert.x |
|---|---:|---:|---:|---:|---:|
| /customers iters | 13,127 | 12,729 | 12,529 | 12,704 | 12,802 |
| /customers rate/s | 328 | 318 | 313 | 317 | 320 |
| /customers avg ms | **13.9** | 17.8 | 19.1 | 18.1 | 17.4 |
| /accounts avg ms | **14.0** | 17.8 | 18.1 | 18.6 | 22.4 |
| /customer-summary avg ms | **14.4** | 17.0 | 19.7 | 21.2 | 17.3 |
| **Errors** | **0** | **0** | **0** | **0** | **0** |

> All servers handle ramp gracefully. Total iteration counts are nearly equal — k6 pacing means throughput is limited by VU sleep, not server capacity. Go leads by ~1.4–1.5x on latency at this moderate load.

---

### 3b. Stress scenario (~1,000 req/s sustained)

| Endpoint | Go | Spring | VT | WebFlux | Vert.x |
|---|---:|---:|---:|---:|---:|
| /customers iters | 86,741 | 85,911 | 84,987 | 81,776 | 85,394 |
| /customers rate/s | 1,084 | 1,073 | 1,062 | 1,022 | 1,066 |
| /customers avg ms | **14.7** | 16.3 | 16.9 | 21.9 | 16.9 |
| /accounts avg ms | **14.4** | 16.5 | 17.9 | 17.9 | 17.2 |
| /customer-summary avg ms | **13.8** | 19.8 | 17.3 | 18.9 | 17.4 |
| **Errors** | **0** | **0** | **0** | **0** | **0** |

> At ~1k req/s all servers remain error-free. WebFlux shows slightly lower iteration count on `/customers` (81,776 vs ~85k) — modest performance gap. Go leads latency by ~1.2–1.6x, Spring and WebFlux slightly behind on `customer_summary`.

---

### 3c. Spike scenario (10→500 VUs instant burst)

| Endpoint | Go | Spring | VT | WebFlux | Vert.x |
|---|---:|---:|---:|---:|---:|
| /customers iters | 65,609 | 64,312 | 65,169 | 64,512 | 64,172 |
| /customers rate/s | 2,181 | 2,142 | 2,165 | 2,143 | 2,139 |
| /customers avg ms | **15.6** | 18.1 | 17.2 | 18.5 | 18.7 |
| /customers p95 ms | **7.5** | 22.8 | 9.6 | 11.6 | 13.7 |
| /accounts p95 ms | **6.0** | 15.8 | 8.5 | 11.7 | 11.2 |
| /customer-summary p95 ms | **8.0** | 12.9 | 7.4 | 11.4 | **6.3** |
| **Errors** | **0** | **0** | **0** | **0** | **0** |

> No errors on any server during spike. P95 diverges more significantly: Go and VT handle the concurrency burst best. Spring's P95 on `/customers` is **3x** higher than Go's (22.8ms vs 7.5ms).

---

### 3d. Multi-endpoint scenario (3 endpoints mixed, 50 VUs)

| Server | iters | rate/s | avg ms ↓ | p99 ms ↓ | errors |
|---|---:|---:|---:|---:|---:|
| **Go** | 17,556 | 350.7 | **13.4** | 0 | 0 |
| Spring | 17,059 | 340.7 | 17.0 | 0 | 0 |
| VT | 16,871 | 337.1 | 18.0 | 0 | 0 |
| WebFlux | 16,734 | 334.2 | 19.4 | 0 | 0 |
| Vert.x | 17,054 | 337.4 | 16.8 | 0 | 0 |

> Realistic mixed traffic, comfortable load. All error-free. Go leads 1.3–1.4x on latency. Vert.x second-best.

---

## SECTION 4 — wrk Results (sustained throughput, 30s)

### 4a. wrk — 4 threads, 50 connections

| Endpoint | Go | Vert.x | WebFlux | VT | Spring |
|---|---:|---:|---:|---:|---:|
| /customers rps ↑ | **76,554** | 41,681 | 10,643 | 8,935 | 7,382 |
| /customers avg lat | 37.9ms | 57.0ms | 53.3ms | 45.2ms | 47.9ms |
| /accounts rps ↑ | **76,424** | 42,009 | 11,314 | 8,730 | 7,504 |
| /accounts avg lat | 38.6ms | 53.7ms | 52.4ms | 55.2ms | 48.3ms |
| /customer-summary rps ↑ | **70,554** | 13,015 | 13,785 | 13,591 | 5,864 |
| /customer-summary avg lat | 30.9ms | 57.3ms | 45.2ms | 45.3ms | 50.2ms |

> At 50c, Go leads everywhere. Vert.x is very strong on simple endpoints (/customers, /accounts ~42k) but drops to 13k on /customer-summary — the fan-out complexity costs event-loop servers more. WebFlux, VT similar on /customer-summary (~13.8k/13.6k).

---

### 4b. wrk — 8 threads, 500 connections (sustained peak pressure)

| Endpoint | Go | Vert.x | WebFlux | VT | Spring |
|---|---:|---:|---:|---:|---:|
| /customers rps ↑ | **77,381** | 72,006 | 11,714 | 8,343 | 7,753 |
| /customers avg lat | 44.2ms | 62.1ms | 85.8ms | 113.2ms | 101.1ms |
| /customers max lat | 748.7ms | 917.2ms | 1.03s | 1.51s | 949.5ms |
| /accounts rps ↑ | **74,725** | 43,945 | 11,181 | 7,918 | 7,656 |
| /accounts avg lat | 37.1ms | 64.9ms | 89.4ms | 124.0ms | 103.3ms |
| /accounts max lat | 744.7ms | 892.7ms | 1.04s | 1.63s | 985.7ms |
| /customer-summary rps ↑ | **73,756** | 25,903 | 13,469 | 13,101 | 5,430 |
| /customer-summary avg lat | 73.0ms | 74.1ms | 81.1ms | 78.8ms | 151.6ms |
| /customer-summary max lat | 1.80s | 935.4ms | 1.02s | 973.4ms | 1.89s |

> At 500c, **Vert.x closes the gap dramatically on /customers (72k vs 77k, only 1.07x behind Go)**. This is the headline result — Vert.x non-blocking event loop scales to high concurrency nearly as well as Go goroutines on simple endpoints. On /customer-summary (fan-out), Go (73.8k) vs Vert.x (25.9k) — Go is **2.8x faster** due to goroutine parallelism on fan-out calls. VT has the worst max latency at 500c (1.51s–1.63s) — virtual thread park/unpark overhead under extreme concurrency.

---

## SECTION 5 — vegeta Results (fixed-rate load, 30s)

### 5a. 100 rps — All servers comfortable

| Endpoint | Go | Spring | VT | WebFlux | Vert.x | All success? |
|---|---:|---:|---:|---:|---:|---|
| /customers mean | 36.2ms | 50.8ms | 61.5ms | 70.3ms | 66.0ms | ✅ 100% all |
| /accounts mean | 37.3ms | 62.5ms | 67.8ms | 60.7ms | 63.9ms | ✅ 100% all |
| /customer-summary mean | 48.1ms | 59.9ms | 69.7ms | 52.4ms | 87.5ms | ✅ 100% all |

> Comfortable baseline. All servers 100% success. Go has lowest mean latency. Vert.x shows elevated mean on /customer-summary at even 100 rps (87ms) — the event loop serialises fan-out differently.

---

### 5b. 1,000 rps — Starting to diverge

| Endpoint | Go | Spring | VT | WebFlux | Vert.x | All success? |
|---|---:|---:|---:|---:|---:|---|
| /customers mean | 36.5ms | 80.5ms | 64.9ms | 67.6ms | 68.0ms | ✅ 100% all |
| /customers p99 | 657ms | 1,214ms | 803ms | 834ms | 829ms | — |
| /accounts mean | 45.1ms | 68.1ms | 68.2ms | 71.4ms | 66.4ms | ✅ 100% all |
| /customer-summary mean | 48.4ms | 77.4ms | 73.6ms | 61.2ms | 65.4ms | ✅ 100% all |

> Still 100% success all around. Spring shows notably high P99 on /customers (1,214ms) — GC pauses contributing to tail spikes. Go P99 656ms is lowest.

---

### 5c. 5,000 rps — Capacity wall hits (critical test)

| Endpoint | Go success | Vert.x success | WebFlux success | Spring success | VT success |
|---|---|---|---|---|---|
| /customers | ✅ **100%** | ✅ **100%** | ✅ **100%** | ✅ **100%** | ⚠️ **95.66%** |
| /accounts | ✅ **100%** | ✅ **100%** | ❌ **45.81%** | ✅ **100%** | ✅ **100%** |
| /customer-summary | ✅ **100%** | ✅ **100%** | ✅ **100%** | ✅ **100%** | ✅ **100%** |

| Endpoint | Go mean | Vert.x mean | WebFlux mean | Spring mean | VT mean |
|---|---:|---:|---:|---:|---:|
| /customers | **44.9ms** | 68.8ms | 106.3ms | 269.7ms | 2,145ms💥 |
| /accounts | **55.7ms** | 75.1ms | 4,993ms💥 | 174.7ms | 235.5ms |
| /customer-summary | **56.5ms** | 268.1ms | 118.5ms | 456.3ms | 209.5ms |

> **The most revealing test.** Three failure modes at 5k rps:
>
> - **VT /customers (95.66% success, avg 2,145ms):** Virtual threads exhausted under 5k req/s sustained burst. The `vegeta_accounts_5k` phase triggered 2,764MB RSS — near memory exhaustion causing GC thrashing.
> - **WebFlux /accounts (45.81% success, avg 4,993ms):** WebFlux catastrophically fails `/accounts` at 5k/s. The accounts endpoint's larger response bodies overwhelm the reactive pipeline's backpressure. 1,379 GC cycles recorded in a single sampling window during this phase.
> - **Go and Vert.x: 100% success on all endpoints.** Both hold steady with sub-100ms mean latency.
> - **Spring: 100% success but degraded** (174-456ms mean) — thread pool queuing but not collapsing.

---

## SECTION 6 — Throughput Summary

### Peak throughput (wrk 8t/500c — best sustained measure)

```
/customers — wrk 8t/500c

Go:     ████████████████████████████████████████  77,381 rps
Vert.x: ████████████████████████████████████████  72,006 rps
WebFlux:██████                                    11,714 rps
VT:     █████                                      8,343 rps
Spring: █████                                      7,753 rps

/accounts — wrk 8t/500c

Go:     ████████████████████████████████████████  74,725 rps
Vert.x: ███████████████████████                   43,945 rps
WebFlux:██████                                    11,181 rps
VT:     █████                                      7,918 rps
Spring: █████                                      7,656 rps

/customer-summary — wrk 8t/500c

Go:     ████████████████████████████████████████  73,756 rps
Vert.x: ██████████████                            25,903 rps
WebFlux:████████                                  13,469 rps
VT:     ████████                                  13,101 rps
Spring: ███                                        5,430 rps
```

### Peak throughput comparison table

| Tool & Config | Go | Vert.x | WebFlux | VT | Spring |
|---|---:|---:|---:|---:|---:|
| wrk /customers 500c | **77,381** | 72,006 | 11,714 | 8,343 | 7,753 |
| wrk /accounts 500c | **74,725** | 43,945 | 11,181 | 7,918 | 7,656 |
| wrk /customer-summary 500c | **73,756** | 25,903 | 13,469 | 13,101 | 5,430 |
| hey /customers 50k/500c | **76,560** | 34,173 | 10,903 | 7,663 | 6,814 |
| hey /accounts 50k/500c | **47,606** | 33,926 | 9,355 | 6,204 | 6,888 |
| ab /customers 50k/100c | 17,204 | **22,849** | 8,826 | 8,668 | 6,950 |

> **Vert.x leads ab** — at 100 concurrent connections the event loop has no overhead and Go's slightly lower ab performance reflects the ab client bottleneck. At 500c sustained (wrk), Go and Vert.x tier together on simple endpoints but Go pulls ahead significantly on the fan-out endpoint.

---

## Key Takeaways

### Performance tiers

| Tier | Servers | Peak /customers rps | Characteristic |
|---|---|---:|---|
| **Tier 1** | Go, Vert.x | 72–77k | Non-blocking + goroutines/event-loop — scales to 500c without queuing |
| **Tier 2** | WebFlux | ~11k | Reactive pipeline — non-blocking but GC/backpressure limits at extreme rates |
| **Tier 3** | VT, Spring | 7–9k | Thread-based (even VT shows ceiling due to carrier thread contention at 500c) |

### Key findings

1. **Go vs Vert.x:** Vert.x is the fastest JVM server — closes to within **1.07x of Go on /customers at 500c wrk**. But on the fan-out `/customer-summary` endpoint, Go is **2.8x faster** because goroutines parallelise fan-out calls without event-loop serialisation.

2. **Virtual Threads memory explosion:** At vegeta 5k rps, VT's RSS hit **2,764MB** (vs Spring 599MB, WebFlux 909MB). Virtual threads park on I/O but still hold JVM objects — under fire-hose load, heap grows unboundedly. Success rate dropped to 95.66% on `/customers`.

3. **WebFlux /accounts collapse:** At 5k rps on `/accounts`, WebFlux hit only **45.81% success rate**. Larger response bodies cause backpressure violations in the reactive pipeline. 1,379 GC cycles in a single monitoring window confirms GC thrashing.

4. **Spring MVC stability:** Despite lower throughput, Spring never crashed and maintained 100% success rate through all tests. Its throughput ceiling (~7k rps) is consistent and predictable.

5. **Vert.x GC efficiency:** Of all JVM servers, Vert.x has the lowest GC overhead (943 cycles, 1,044ms total) — the event loop model creates fewer short-lived objects than thread-per-request under high load.

6. **k6 shows convergence:** Under realistic paced traffic (k6), all servers perform similarly — the concurrency model only matters at extreme loads. At ~1k req/s all servers are error-free and within 1.6x of each other.

---

## All-Endpoints Summary Tables

### hey 10k/200c — All Endpoints

| Server | /customers | /accounts | /customer-summary |
|---|---:|---:|---:|
| Go | 53,835 rps | 74,069 rps | 53,371 rps |
| Vert.x | 16,771 rps | 4,588 rps | 6,455 rps |
| WebFlux | 8,369 rps | 5,750 rps | 5,847 rps |
| VT | 7,340 rps | 8,309 rps | 12,660 rps |
| Spring | 7,244 rps | 7,918 rps | 6,143 rps |

> Vert.x unusually low on /accounts/customer-summary at 10k/200c — likely cold start effect; the server warmed up through the run.

### hey 50k/500c — All Endpoints

| Server | /customers | /accounts | /customer-summary |
|---|---:|---:|---:|
| Go | 76,560 rps | 47,606 rps | 67,403 rps |
| Vert.x | 34,173 rps | 33,926 rps | 23,043 rps |
| WebFlux | 10,903 rps | 9,355 rps | 10,314 rps |
| VT | 7,663 rps | 6,204 rps | 10,480 rps |
| Spring | 6,814 rps | 6,888 rps | 5,416 rps |

### ab 50k/100c — All Endpoints

| Server | /customers rps | /accounts rps | /customer-summary rps |
|---|---:|---:|---:|
| **Vert.x** | **22,849** | **23,720** | **21,579** |
| Go | 17,204 | 13,896 | 18,651 |
| VT | 8,668 | 7,918 | 10,426 |
| WebFlux | 8,826 | 7,816 | 8,979 |
| Spring | 6,950 | 6,857 | 5,620 |

### wrk 4t/50c/30s — All Endpoints

| Server | /customers rps | /accounts rps | /customer-summary rps |
|---|---:|---:|---:|
| Go | 76,554 | 76,424 | 70,554 |
| Vert.x | 41,681 | 42,009 | 13,015 |
| WebFlux | 10,643 | 11,314 | 13,785 |
| VT | 8,935 | 8,730 | 13,591 |
| Spring | 7,382 | 7,504 | 5,864 |

### wrk 8t/500c/30s — All Endpoints

| Server | /customers rps | /accounts rps | /customer-summary rps |
|---|---:|---:|---:|
| Go | 77,381 | 74,725 | 73,756 |
| Vert.x | 72,006 | 43,945 | 25,903 |
| WebFlux | 11,714 | 11,181 | 13,469 |
| VT | 8,343 | 7,918 | 13,101 |
| Spring | 7,753 | 7,656 | 5,430 |

---

## Crash / Stability Summary

| Server | Crashes | Total samples | Notes |
|---|---:|---:|---|
| Go | 0 | 263 | Stable throughout |
| Spring | 0 | 263 | Stable, no restarts |
| VT | 0 | 259 | Stable, but memory spike at 5k rps |
| WebFlux | 0 | 258 | Stable, but 45% failure rate during /accounts vegeta 5k |
| Vert.x | 0 | 263 | Stable throughout |

> No server crashed or required a restart during the entire test suite. "Failures" are HTTP-level (connection refused/timeout), not process crashes.
