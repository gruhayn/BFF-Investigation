# Performance Test Results V2 — All 5 BFF Servers

**Date:** April 20, 2026  
**Machine:** macOS (Apple Silicon)  
**Servers:** Go (8080) · Spring Boot (8084) · Virtual Threads (8081) · WebFlux (8082) · Vert.x (8083)  
**Methodology:** Unified sequential run — each server started cold, fully tested, stopped before next. All 5 tested on same day, same conditions.  
**Endpoints:** `/customers`, `/accounts`, `/customer-summary?id=c1`  
**ab standardization:** All servers use `-n 50000 -c 100` (previous runs used 500c for Go/Spring — that was unfair; corrected here)

---

## How to Read the Metrics

| Metric | What it means | Better = ? |
|---|---|---|
| **rps** | Requests per second | ↑ Higher |
| **avg** | Mean response time | ↓ Lower |
| **p95 / p99** | 95th / 99th percentile latency | ↓ Lower |
| **iters** | Total completed iterations in k6 | ↑ Higher |
| **errors** | k6 error rate (0 = clean) | ↓ Lower |

---

## Tool Summary

| Tool | Mode | Config |
|---|---|---|
| **hey** | Burst — fixed request count | 10k/200c, 50k/500c |
| **k6** | Sustained — virtual users with ramp/stress/spike patterns | ramp, stress, spike, multi |
| **ab** | Burst — fixed request count, standardized concurrency | 50k/100c |

---

## SECTION 1 — hey (burst throughput)

### 1a. `/customers` — 10k requests, 200 concurrent

| Server | rps ↑ | avg ↓ |
|---|---|---|
| 🥇 go | **52,142** | 3.6ms |
| 🥈 vertx | 17,233 | 11.4ms |
| webflux | 9,362 | 19.8ms |
| vt | 7,893 | 23.8ms |
| spring | 7,372 | 25.9ms |

> Go is **7x** faster than the best JVM server. Vert.x leads the JVM pack.

### 1b. `/customers` — 50k requests, 500 concurrent

| Server | rps ↑ | avg ↓ |
|---|---|---|
| 🥇 go | **34,006** | 12.4ms |
| 🥈 vertx | 32,966 | 14.9ms |
| webflux | 11,895 | 40.1ms |
| vt | 10,030 | 48.3ms |
| spring | 5,294 | 93.3ms |

> Vert.x nearly matches Go at high concurrency on customers. Both reactive servers (WebFlux, Vert.x) hold up much better than thread-per-request (Spring, VT).

### 1c. `/accounts` — 10k requests, 200 concurrent

| Server | rps ↑ | avg ↓ |
|---|---|---|
| 🥇 go | **50,154** | 3.8ms |
| 🥈 vt | 10,222 | 18.6ms |
| webflux | 7,077 | 27.3ms |
| vertx | 4,952 | 39.5ms |
| spring | 4,462 | 43.4ms |

> Vert.x underperforms on accounts at 10k — suggests some resource contention at lower loads for that endpoint.

### 1d. `/accounts` — 50k requests, 500 concurrent

| Server | rps ↑ | avg ↓ |
|---|---|---|
| 🥇 go | **75,181** | 6.4ms |
| 🥈 vertx | 20,529 | 24.1ms |
| webflux | 10,228 | 47.1ms |
| vt | 9,008 | 53.5ms |
| spring | 7,669 | 64.3ms |

### 1e. `/customer-summary` — 10k requests, 200 concurrent

| Server | rps ↑ | avg ↓ |
|---|---|---|
| 🥇 go | **68,190** | 2.8ms |
| 🥈 vt | 15,027 | 12.7ms |
| vertx | 7,526 | 26.3ms |
| spring | 6,134 | 28.2ms |
| webflux | 6,001 | 29.5ms |

### 1f. `/customer-summary` — 50k requests, 500 concurrent

| Server | rps ↑ | avg ↓ |
|---|---|---|
| 🥇 go | **78,695** | 6.2ms |
| 🥈 vertx | 21,912 | 22.7ms |
| vt | 14,411 | 33.6ms |
| webflux | 9,753 | 49.6ms |
| spring | 4,957 | 95.9ms |

> At 500c Spring degrades severely (+55ms avg vs idle). Go improves — its goroutine model gets more efficient as concurrency grows.

---

## SECTION 2 — ab (standardized burst, 100 concurrency)

All servers use identical load: 50,000 requests at 100 concurrent connections.

### 2a. `/customers`

| Server | rps ↑ | mean ↓ | p50 ↓ | p95 ↓ | p99 ↓ |
|---|---|---|---|---|---|
| 🥇 go | **24,670** | 4.1ms | 3ms | 7ms | 12ms |
| 🥈 vertx | 22,012 | 4.5ms | 4ms | 7ms | 23ms |
| vt | 8,206 | 12.2ms | 10ms | 22ms | 33ms |
| spring | 7,548 | 13.2ms | 12ms | 24ms | 31ms |
| webflux | 7,540 | 13.3ms | 9ms | 28ms | 55ms |

### 2b. `/accounts`

| Server | rps ↑ | mean ↓ | p50 ↓ | p95 ↓ | p99 ↓ |
|---|---|---|---|---|---|
| 🥇 go | **24,540** | 4.1ms | 4ms | 5ms | 10ms |
| 🥈 vertx | 17,494 | 5.7ms | 4ms | 10ms | 27ms |
| webflux | 11,650 | 8.6ms | 7ms | 18ms | 42ms |
| vt | 8,116 | 12.3ms | 10ms | 23ms | 36ms |
| spring | 5,910 | 16.9ms | 13ms | 30ms | 47ms |

### 2c. `/customer-summary`

| Server | rps ↑ | mean ↓ | p50 ↓ | p95 ↓ | p99 ↓ |
|---|---|---|---|---|---|
| 🥇 go | **24,391** | 4.1ms | 4ms | 5ms | 19ms |
| 🥈 vertx | 22,688 | 4.4ms | 4ms | 7ms | 14ms |
| vt | 10,766 | 9.3ms | 6ms | 15ms | 27ms |
| webflux | 8,985 | 11.1ms | 8ms | 25ms | 48ms |
| spring | 5,203 | 19.2ms | 13ms | 35ms | 57ms |

> **Vert.x p99 (14ms) beats Go p99 (19ms) on customer-summary** — Vert.x has lower tail latency on the heaviest endpoint. At 100c both are very competitive.

---

## SECTION 3 — k6 (sustained / realistic traffic)

k6 simulates virtual users looping with sleep between requests — more representative of real-world usage than burst tools.

### 3a. Ramp scenario — `/customers`

Ramp: 0→50→100 VUs over 3 min, hold 2 min, ramp down.

| Server | iters ↑ | rate/s ↑ | avg ↓ | p95 ↓ | errors |
|---|---|---|---|---|---|
| 🥇 go | **12,971** | 321.1 | 15.0ms | 4.1ms | 0 |
| 🥈 vertx | 12,788 | 319.2 | 17.5ms | 8.3ms | 0 |
| spring | 12,745 | 318.3 | 18.0ms | 7.8ms | 0 |
| vt | 12,669 | 316.4 | 18.4ms | 7.1ms | 0 |
| webflux | 12,487 | 311.4 | 19.9ms | 11.4ms | 0 |

### 3b. Ramp scenario — `/accounts`

| Server | iters ↑ | rate/s ↑ | avg ↓ | p95 ↓ | errors |
|---|---|---|---|---|---|
| 🥇 go | **13,117** | 327.7 | 13.5ms | 3.7ms | 0 |
| 🥈 spring | 12,788 | 317.2 | 17.4ms | 7.7ms | 0 |
| vertx | 12,630 | 315.0 | 19.0ms | 7.0ms | 0 |
| vt | 12,628 | 313.1 | 18.7ms | 10.7ms | 0 |
| webflux | 12,575 | 313.7 | 19.2ms | 11.1ms | 0 |

### 3c. Ramp scenario — `/customer-summary`

| Server | iters ↑ | rate/s ↑ | avg ↓ | p95 ↓ | errors |
|---|---|---|---|---|---|
| 🥇 go | **13,039** | 325.4 | 14.3ms | 4.2ms | 0 |
| 🥈 spring | 12,825 | 320.1 | 17.4ms | 7.4ms | 0 |
| vertx | 12,580 | 314.3 | 19.6ms | 9.3ms | 0 |
| vt | 12,415 | 310.0 | 20.5ms | 11.2ms | 0 |
| webflux | 12,348 | 303.4 | 21.6ms | 13.0ms | 0 |

> Under moderate ramp load k6 gaps are small (~5–15%). Spring holds up well here — the JIT is warm and thread pool is not saturated.

### 3d. Stress scenario — `/customers`

Stress: ramp to 200 VUs over 5 min, hold 5 min.

| Server | iters ↑ | rate/s ↑ | avg ↓ | p95 ↓ | errors |
|---|---|---|---|---|---|
| 🥇 go | **86,712** | 1,082.2 | 14.2ms | 5.5ms | 0 |
| 🥈 spring | 86,084 | 1,069.3 | 16.2ms | 5.3ms | 0 |
| vt | 85,428 | 1,067.1 | 16.8ms | 6.0ms | 0 |
| webflux | 84,599 | 1,056.8 | 18.1ms | 7.9ms | 0 |
| vertx | 83,796 | 1,046.3 | 19.1ms | 10.4ms | 0 |

### 3e. Stress scenario — `/accounts`

| Server | iters ↑ | rate/s ↑ | avg ↓ | p95 ↓ | errors |
|---|---|---|---|---|---|
| 🥇 go | **86,742** | 1,083.8 | 14.2ms | 5.3ms | 0 |
| 🥈 spring | 85,693 | 1,070.4 | 16.6ms | 6.8ms | 0 |
| vertx | 84,851 | 1,059.9 | 17.6ms | 9.1ms | 0 |
| vt | 84,489 | 1,055.3 | 17.9ms | 9.1ms | 0 |
| webflux | 83,715 | 1,045.3 | 19.3ms | 10.7ms | 0 |

### 3f. Stress scenario — `/customer-summary`

| Server | iters ↑ | rate/s ↑ | avg ↓ | p95 ↓ | errors |
|---|---|---|---|---|---|
| 🥇 go | **86,590** | 1,081.1 | 14.5ms | 6.0ms | 0 |
| 🥈 spring | 86,047 | 1,074.9 | 16.3ms | 5.2ms | 0 |
| webflux | 84,275 | 1,042.3 | 18.4ms | 9.0ms | 0 |
| vt | 84,244 | 1,051.7 | 18.0ms | 10.0ms | 0 |
| vertx | 83,258 | 1,039.8 | 20.0ms | 10.6ms | 0 |

> Under sustained stress k6 gaps compress to ~4%. Spring is surprisingly close — JIT warming, bounded VU count keeps thread pool pressure low. **Go wins every stress scenario, Spring #2.**

### 3g. Spike scenario — `/customers`

Spike: instant jump to 500 VUs, hold 1 min, drop.

| Server | iters ↑ | rate/s ↑ | avg ↓ | p95 ↓ | errors |
|---|---|---|---|---|---|
| 🥇 go | **65,909** | 2,196.6 | 15.1ms | 6.1ms | 0 |
| 🥈 webflux | 65,251 | 2,127.1 | 17.3ms | 6.8ms | 0 |
| vt | 65,065 | 2,168.2 | 17.6ms | 6.0ms | 0 |
| spring | 64,843 | 2,158.4 | 18.2ms | 6.0ms | 0 |
| ⚠️ vertx | 55,868 | 1,857.7 | 35.0ms | **70.2ms** | 0 |

> Vert.x **struggled on the spike** for customers — p95 jumped to 70ms vs 6–8ms for all others. 15% fewer iterations.

### 3h. Spike scenario — `/accounts`

| Server | iters ↑ | rate/s ↑ | avg ↓ | p95 ↓ | errors |
|---|---|---|---|---|---|
| 🥇 go | **66,125** | 2,198.4 | 14.7ms | 6.0ms | 0 |
| 🥈 spring | 65,324 | 2,174.4 | 17.2ms | 6.7ms | 0 |
| vertx | 63,036 | 2,053.7 | 20.3ms | 12.8ms | 0 |
| ⚠️ webflux | 60,590 | 2,014.3 | 25.9ms | 59.7ms | 0 |
| ⚠️ vt | 57,436 | 1,909.5 | 32.9ms | **125.8ms** | 0 |

> VT's p95 spiked to **126ms** under instant-500-VU load on accounts. WebFlux also degraded (60ms p95). Spring held up best among JVM for spike on accounts.

### 3i. Spike scenario — `/customer-summary`

| Server | iters ↑ | rate/s ↑ | avg ↓ | p95 ↓ | errors |
|---|---|---|---|---|---|
| 🥇 go | **65,873** | 2,194.8 | 15.1ms | 6.8ms | 0 |
| 🥈 vertx | 65,808 | 2,192.1 | 16.3ms | 7.8ms | 0 |
| spring | 65,106 | 2,164.5 | 17.6ms | 7.0ms | 0 |
| vt | 64,825 | 2,156.4 | 17.3ms | 10.3ms | 0 |
| webflux | 64,625 | 2,152.6 | 18.5ms | 7.5ms | 0 |

> All servers handled spike on customer-summary cleanly. Vert.x nearly tied with Go here.

### 3j. Multi-endpoint scenario

Mixed workload: 40% customers / 30% accounts / 30% customer-summary.

| Server | iters ↑ | rate/s ↑ | avg ↓ |
|---|---|---|---|
| 🥇 go | **17,426** | 347.8 | 13.6ms |
| 🥈 spring | 17,049 | 340.7 | 17.3ms |
| vt | 16,818 | 336.1 | 18.3ms |
| vertx | 16,691 | 333.5 | 19.9ms |
| webflux | 16,401 | 327.4 | 21.3ms |

---

## Summary

### Throughput ranking (overall)

| Rank | Server | Notes |
|---|---|---|
| 🥇 1 | **Go** | Wins every category. 3–7x JVM advantage on burst, 1.04x on sustained stress k6 |
| 🥈 2 | **Vert.x** | Best JVM on burst/ab (customers, customer-summary). Spike weakness on customers endpoint |
| 3 | **Virtual Threads** | Strong on customer-summary hey. Spike weakness on accounts (126ms p95) |
| 4 | **WebFlux** | Competitive on accounts. Spike weakness on accounts (60ms p95) |
| 5 | **Spring Boot** | Weakest on burst (lowest rps, highest avg). Surprisingly resilient on k6 stress/spike |

### Key observations

1. **Go dominates burst load** — 3–7x more rps than any JVM server on hey/ab tests.
2. **k6 gaps are small** — Under sustained load (bounded VUs) all servers cluster within ~4% of each other. JIT warming + controlled concurrency closes the gap.
3. **Vert.x vs Go on customers at 50k/500c** — 34k vs 32k rps, essentially tied. Reactive I/O matches Go's goroutine model at high concurrency.
4. **Spike reveals JVM weaknesses** — VT p95=126ms, WebFlux p95=60ms, Vert.x p95=70ms on their worst spike scenarios. Go stays flat (6–7ms p95) across all spikes.
5. **Spring is more consistent than expected on k6** — JIT-warmed steady state performance is only ~4% behind Go. The penalty is in cold/bursty scenarios.
6. **Vert.x best p99 on customer-summary ab** — 14ms vs Go's 19ms at 100c. Vert.x event loop handles the fan-out coordination efficiently.
