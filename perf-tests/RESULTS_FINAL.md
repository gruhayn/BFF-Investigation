# Performance Test Results — All 5 Servers

**Date:** April 20, 2026  
**Machine:** macOS (Apple Silicon)  
**Ports:** Go=8080 | Spring=8084 | Virtual Threads=8081 | WebFlux=8082 | Vert.x=8083  
**Methodology:** Isolated — each server tested cold, then stopped before the next starts.  
**Go & Spring data:** `results_20260402_201751/`  
**VT, WebFlux, Vert.x data:** `results_new_20260420_151648/`  
**Endpoints:** `/customers`, `/accounts`, `/customer-summary?id=<id>`

---

## Server Architectures

| Server | Framework | Concurrency Model | Port |
|---|---|---|---|
| Go | net/http | Goroutines (M:N, 2–8KB stack) | 8080 |
| Spring MVC | Spring Boot 3.2 / Tomcat | Platform threads (1 thread/request) | 8084 |
| Virtual Threads (VT) | Spring Boot 3.2 / Tomcat | JVM Virtual Threads (Project Loom) | 8081 |
| WebFlux | Spring Boot 3.2 / Netty | Reactive Mono/Flux, event loop | 8082 |
| Vert.x | Vert.x 4 / Netty | Kotlin coroutines + event loop | 8083 |

---

## Metrics Guide

| Metric | Meaning | Better |
|---|---|---|
| RPS | Requests per second | ↑ higher |
| Avg / Mean | Average response time | ↓ lower |
| P99 | 99th percentile latency (tail) | ↓ lower |

---

## 1. hey Results

`hey` fires a fixed total of requests at fixed concurrency.  
Tests: 10k requests/200c and 50k requests/500c.  
RPS = requests/sec (higher = better). Avg = average latency in ms (lower = better).

### /customers

| Server | 10k/200c RPS | Avg | 50k/500c RPS | Avg |
|---|---:|---:|---:|---:|
| go | 55,668 | 3.4ms | 76,896 | 6.3ms |
| spring | 6,587 | 28.7ms | 6,351 | 77.1ms |
| vt | 6,207 | 30.7ms | 8,297 | 58.4ms |
| webflux | 7,632 | 24.3ms | 11,837 | 39.9ms |
| vertx | 17,859 | 11.0ms | 31,895 | 15.5ms |

> 🥇 **Best (10k):** Go — 55,668 rps  
> 🥇 **Best (50k):** Go — 76,896 rps  
> 🥈 **Best JVM:** Vert.x — 17,859 / 31,895 rps

### /accounts

| Server | 10k/200c RPS | Avg | 50k/500c RPS | Avg |
|---|---:|---:|---:|---:|
| go | 60,827 | 3.1ms | 35,668 | 13.7ms |
| spring | 3,749 | 51.2ms | 3,868 | 126.7ms |
| vt | 8,782 | 21.6ms | 8,033 | 59.4ms |
| webflux | 11,504 | 16.6ms | 9,239 | 51.9ms |
| vertx | 25,858 | 7.6ms | 42,975 | 11.5ms |

> 🥇 **Best (10k):** Go — 60,827 rps  
> 🥇 **Best (50k): Vert.x — 42,975 rps** (beats Go's 35,668 — Netty scales past net/http at 500c)  
> 🥈 **Best JVM (10k):** Vert.x — 25,858 rps (6.9× Spring, 2.2× WebFlux)

### /customer-summary

| Server | 10k/200c RPS | Avg | 50k/500c RPS | Avg |
|---|---:|---:|---:|---:|
| go | 53,073 | 3.6ms | 74,524 | 6.5ms |
| spring | 4,759 | 36.6ms | 5,018 | 95.5ms |
| vt | 11,345 | 17.0ms | 11,714 | 41.2ms |
| webflux | 5,099 | 38.0ms | 8,878 | 54.3ms |
| vertx | 9,273 | 21.2ms | 17,433 | 28.5ms |

> 🥇 **Best:** Go — 53,073 / 74,524 rps  
> 🥈 **Best JVM (10k):** VT — 11,345 rps (virtual thread fan-out is more efficient than WebFlux Mono.zip at 200c)  
> 🥈 **Best JVM (50k):** Vert.x — 17,433 rps

---

## 2. k6 Results

k6 controls Virtual Users (VUs) with ramp profiles. Results show sustained throughput under realistic concurrency shapes.

### Ramp scenario — 0 → 400 → 0 VUs over ~4 min

| Endpoint | Best overall | Best JVM |
|---|---|---|
| /customers | Go (327.6/s · 14.1ms) | Vert.x (316.2/s · 18.5ms) |
| /accounts | Go (328.8/s · 13.6ms) | Vert.x (311.3/s · 19.2ms) |
| /customer-summary | Go (329.3/s · 13.5ms) | Vert.x (316.2/s · 18.8ms) |

<details>
<summary>Full ramp tables</summary>

#### /customers

| Server | Iterations | Rate (/s) | Avg |
|---|---:|---:|---:|
| go | 13,112 | 327.6 | 14.1ms |
| spring | 12,662 | 316.4 | 18.5ms |
| vt | 12,450 | 310.8 | 20.8ms |
| webflux | 12,127 | 302.6 | 23.4ms |
| vertx | 12,651 | 316.2 | 18.5ms |

#### /accounts

| Server | Iterations | Rate (/s) | Avg |
|---|---:|---:|---:|
| go | 13,194 | 328.8 | 13.6ms |
| spring | 12,856 | 320.8 | 16.8ms |
| vt | 12,549 | 313.0 | 19.7ms |
| webflux | 11,735 | 292.9 | 27.7ms |
| vertx | 12,582 | 311.3 | 19.2ms |

#### /customer-summary

| Server | Iterations | Rate (/s) | Avg |
|---|---:|---:|---:|
| go | 13,200 | 329.3 | 13.5ms |
| spring | 12,701 | 317.3 | 18.5ms |
| vt | 12,457 | 311.1 | 19.9ms |
| webflux | 12,290 | 306.5 | 21.5ms |
| vertx | 12,653 | 316.2 | 18.8ms |

</details>

---

### Stress scenario — sustained 1000 VUs, ~80s

| Endpoint | Best overall | Best JVM |
|---|---|---|
| /customers | Go (1,086.2/s · 14.5ms) | Vert.x (1,057.5/s · 17.8ms) |
| /accounts | Go (1,085.5/s · 14.2ms) | Vert.x / VT (~1,055/s, within margin) |
| /customer-summary | Go (1,085.8/s · 14.4ms) | Spring (1,068.3/s) — all JVM within 3% |

> ⚠️ All JVM servers converge within ~4% at 1000 VUs — the bottleneck shifts to k6 orchestration, not server capacity.

<details>
<summary>Full stress tables</summary>

#### /customers

| Server | Iterations | Rate (/s) | Avg |
|---|---:|---:|---:|
| go | 86,942 | 1,086.2 | 14.5ms |
| spring | 85,147 | 1,063.2 | 17.4ms |
| vt | 84,128 | 1,051.2 | 18.3ms |
| webflux | 80,926 | 1,011.2 | 22.7ms |
| vertx | 84,645 | 1,057.5 | 17.8ms |

#### /accounts

| Server | Iterations | Rate (/s) | Avg |
|---|---:|---:|---:|
| go | 86,858 | 1,085.5 | 14.2ms |
| spring | 84,512 | 1,055.2 | 18.1ms |
| vt | 84,453 | 1,054.9 | 18.0ms |
| webflux | 84,377 | 1,053.4 | 18.2ms |
| vertx | 84,438 | 1,055.3 | 18.1ms |

#### /customer-summary

| Server | Iterations | Rate (/s) | Avg |
|---|---:|---:|---:|
| go | 86,931 | 1,085.8 | 14.4ms |
| spring | 85,554 | 1,068.3 | 16.8ms |
| vt | 83,290 | 1,040.3 | 19.4ms |
| webflux | 83,668 | 1,045.0 | 19.1ms |
| vertx | 84,027 | 1,045.3 | 19.0ms |

</details>

---

### Spike scenario — 0 → 2000 → 0 VUs, abrupt

| Endpoint | Best overall | Best JVM |
|---|---|---|
| /customers | Go (2,209.3/s · 14.6ms) | VT (2,166.4/s · 17.5ms) |
| /accounts | Go (2,193.3/s · 14.7ms) | **WebFlux (2,188.7/s · 15.9ms — within 0.2% of Go)** |
| /customer-summary | Go (2,213.3/s · 14.3ms) | **VT (2,203.9/s · 15.1ms — within 0.4% of Go)** |

> 💡 **VT fan-out insight:** On `/customer-summary` spike, VT matches Go nearly exactly. Virtual thread concurrent fan-out (4 downstream calls in parallel) is as efficient as goroutines under spike load.  
> ⚠️ Spring `/accounts` spike: 26.9ms avg vs Go's 14.7ms — thread pool backlog under abrupt VU ramp.

<details>
<summary>Full spike tables</summary>

#### /customers

| Server | Iterations | Rate (/s) | Avg |
|---|---:|---:|---:|
| go | 66,435 | 2,209.3 | 14.6ms |
| spring | 64,931 | 2,160.7 | 17.8ms |
| vt | 65,069 | 2,166.4 | 17.5ms |
| webflux | 61,587 | 2,046.7 | 23.7ms |
| vertx | 64,691 | 2,149.1 | 17.9ms |

#### /accounts

| Server | Iterations | Rate (/s) | Avg |
|---|---:|---:|---:|
| go | 65,926 | 2,193.3 | 14.7ms |
| spring | 59,777 | 1,990.0 | 26.9ms |
| vt | 61,490 | 2,045.5 | 24.0ms |
| webflux | 65,734 | 2,188.7 | 15.9ms |
| vertx | 64,588 | 2,145.9 | 17.7ms |

#### /customer-summary

| Server | Iterations | Rate (/s) | Avg |
|---|---:|---:|---:|
| go | 66,462 | 2,213.3 | 14.3ms |
| spring | 60,725 | 1,991.4 | 25.5ms |
| vt | 66,219 | 2,203.9 | 15.1ms |
| webflux | 64,773 | 2,152.5 | 17.4ms |
| vertx | 64,439 | 2,144.0 | 18.5ms |

</details>

---

### Multi-endpoint scenario — all 3 endpoints mixed

| Server | Iterations | Rate (/s) | Avg |
|---|---:|---:|---:|
| go | 17,491 | 349.4 | 13.8ms |
| spring | 16,766 | 334.7 | 19.2ms |
| vt | 16,636 | 332.5 | 19.8ms |
| webflux | 16,451 | 327.8 | 20.9ms |
| vertx | 16,956 | 338.8 | 17.9ms |

> 🥇 **Best overall:** Go — 349.4/s  
> 🥈 **Best JVM:** Vert.x — 338.8/s · 17.9ms avg (lowest latency of all JVM servers in mixed load)

---

## 3. ab Results — 50k requests / 100 concurrent

`ab` runs sustained fixed-concurrency and reports P50/P99 latency percentiles.

### /customers

| Server | RPS | Mean | P50 | P99 |
|---|---:|---:|---:|---:|
| go | 18,096 | 27.6ms | 12ms | 247ms |
| spring | 6,908 | 72.4ms | 21ms | 116ms |
| vt | 7,550 | 13.2ms | 10ms | 35ms |
| webflux | 9,594 | 10.4ms | 8ms | 34ms |
| vertx | 21,707 | 4.6ms | 4ms | 19ms |

> 🥇 **Best overall: Vert.x — 21,707 rps** (beats Go's 18,096 at 100c)  
> 🥇 **Best latency:** Vert.x — 4.6ms mean · 4ms P50 · 19ms P99

### /accounts

| Server | RPS | Mean | P50 | P99 |
|---|---:|---:|---:|---:|
| go | 13,376 | 37.4ms | 18ms | 298ms |
| spring | 1,357 | 368ms | 179ms | 4,185ms |
| vt | 8,629 | 11.6ms | 9ms | 33ms |
| webflux | 9,644 | 10.4ms | 8ms | 39ms |
| vertx | 25,265 | 4.0ms | 4ms | 13ms |

> 🥇 **Best overall: Vert.x — 25,265 rps** (nearly 2× Go's 13,376; Go has high tail latency at 100c)  
> 🥇 **Best latency:** Vert.x — 4.0ms mean · 4ms P50 · 13ms P99  
> 💥 **Spring collapse:** 1,357 rps · 368ms mean · 4,185ms P99 — classic thread pool exhaustion

### /customer-summary

| Server | RPS | Mean | P50 | P99 |
|---|---:|---:|---:|---:|
| go | 19,059 | 26.2ms | 12ms | 239ms |
| spring | 5,728 | 87.3ms | 23ms | 610ms |
| vt | 10,058 | 9.9ms | 7ms | 38ms |
| webflux | 10,630 | 9.4ms | 6ms | 51ms |
| vertx | 13,831 | 7.2ms | 6ms | 27ms |

> 🥇 **Best overall:** Go — 19,059 rps  
> 🥈 **Best JVM:** Vert.x — 13,831 rps · 7.2ms mean  
> 🏅 **Best tail latency (JVM):** Vert.x — 27ms P99 (WebFlux matches on P50 at 6ms but falls to 51ms P99)

---

## 4. Rankings Summary

### Raw throughput (hey — burst, high concurrency)

| Rank | Server | RPS range (hey) | Note |
|---|---|---|---|
| 1 | **Go** | 53–77k rps | Dominates at 200–500c |
| 2 | **Vert.x** | 17–43k rps | Beats Go on `/accounts` 50k |
| 3 | **WebFlux** | 5–12k rps | |
| 4 | **VT** | 6–11k rps | Beats WebFlux on fan-out endpoints |
| 5 | **Spring** | 3–7k rps | Degrades at 500c |

### Latency under sustained 100c load (ab)

| Rank | Server | Mean range | Note |
|---|---|---|---|
| 1 | **Vert.x** | 4–7ms | Beats all servers including Go |
| 2 | **WebFlux** | 9–10ms | |
| 3 | **VT** | 10–13ms | |
| 4 | **Go** | 26–37ms | ab penalizes connection model |
| 5 | **Spring** | 72–368ms | Collapses on `/accounts` |

### Spike resilience (k6 spike — 0→2000 VUs abrupt)

| Rank | Server | Note |
|---|---|---|
| 1 | **Go** | Consistent across all 3 endpoints |
| 2 | **VT** | Best JVM on `/customers` + `/customer-summary`; 0.4% behind Go on fan-out |
| 3 | **WebFlux** | Best JVM on `/accounts`; 0.2% behind Go |
| 4 | **Vert.x** | Solid, consistent |
| 5 | **Spring** | Degrades on heavy-I/O endpoints under abrupt load |

---

## 5. Key Takeaways

| Finding | Detail |
|---|---|
| **Vert.x wins latency** | Best mean/P99 across all ab tests — Netty coroutines have less overhead than Spring's reactive layer |
| **Vert.x beats Go on `/accounts` hey 50k** | 42,975 vs 35,668 rps — Go's net/http degrades at 500c, Netty scales |
| **VT matches Go on fan-out spike** | `/customer-summary` spike: 2,204 vs 2,213 rps — virtual thread fan-out is as efficient as goroutines |
| **VT >> Spring MVC on `/accounts`** | 8,629 vs 1,357 rps (ab) — Virtual Threads eliminate thread pool exhaustion entirely |
| **k6 stress convergence** | All JVM servers within 4% at 1000 VUs — bottleneck is not the server at this level |
| **Spring is unsuitable for I/O-bound workloads** | 4,185ms P99 on `/accounts` at 100c sustained; avoid for high-concurrency fan-out patterns |
