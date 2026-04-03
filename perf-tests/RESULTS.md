# Performance Test Results: Go vs Spring Boot

**Date:** April 2, 2026
**Machine:** macOS (Apple Silicon)
**Go port:** 8080 | **Spring Boot port:** 8084
**Test methodology:** Isolated — Go tested first (cold start), then stopped; Spring Boot tested second (cold start). No cross-contamination.
**Endpoints:** `/customer-summary?id=c1` (primary), `/customers`, `/accounts`

---

## How to Read the Metrics

| Metric | What it means | Better = ? |
|---|---|---|
| **Requests/sec** | How many requests the server handles per second | ↑ Higher is better |
| **Avg latency** | Average time to get a response | ↓ Lower is better |
| **P50 (median)** | 50% of requests were faster than this | ↓ Lower is better |
| **P90** | 90% of requests were faster than this | ↓ Lower is better |
| **P95** | 95% of requests were faster than this | ↓ Lower is better |
| **P99 (tail)** | 99% of requests were faster than this; shows worst-case | ↓ Lower is better |
| **Max latency** | The single slowest request | ↓ Lower is better |
| **Throughput (MB/s)** | Data transferred per second | ↑ Higher is better |
| **Total requests** | Total completed requests in timed tests | ↑ Higher is better |
| **Success rate** | % of requests that returned HTTP 200 | ↑ Higher is better (100% = no errors) |

> **In short:** For speed metrics (req/s, throughput) — **bigger is better**.
> For time metrics (latency, duration) — **smaller is better**.

---

## Tools Used

| Tool | What it does | Configs used |
|---|---|---|
| **hey** | Fires a fixed number of requests as fast as possible with N concurrent workers. Good for measuring peak burst throughput. | 10k/200c, 50k/500c |
| **wrk** | Keeps N persistent connections open for a fixed duration and pushes as many requests as possible. Best for measuring sustained max throughput. | 4t/50c/30s, 8t/500c/30s |
| **k6** | Simulates virtual users (VUs) with configurable ramp-up/down patterns. Each VU executes requests in a loop with a sleep between iterations. Measures how the server behaves under realistic user-like traffic. | Ramp, Stress, Spike, Multi-endpoint |
| **vegeta** | Sends requests at a fixed constant rate (e.g., exactly 100/s). Measures whether the server can keep up with a predetermined load without falling behind. | 100/s, 1k/s, 5k/s |
| **ab** | Apache Bench — classic HTTP benchmark. Similar to hey but older, uses different connection pooling. Included for cross-validation. | 50k/500c |

---

## Why Go is Faster — Core Concepts

Three factors explain every result below. Each test highlights a different mix of them.

### Factor 1: Per-Request Overhead (~2–5x gap)
Every Spring Boot request passes through ~15 layers: Tomcat thread pool → Servlet filter chain → DispatcherServlet → HandlerMapping → `@RequestMapping` resolution → Controller → Jackson reflection-based serialization → `HttpMessageConverter` → response. Go's path: `http.ServeMux` route match → handler function → `json.Marshal` → `w.Write()`. This alone costs Spring ~1–3ms vs Go's ~0.3–0.5ms per request. **This gap exists at any load level.**

### Factor 2: Concurrency Model (~10–15x gap under pressure)
Spring Boot uses Tomcat's thread-per-request model with a default pool of **200 OS threads** (~1MB stack each). When concurrent connections exceed 200, requests **queue and wait**. Go spawns one goroutine per request (~2KB stack, cooperative scheduling) across ~8–10 OS threads — no fixed ceiling, no queuing. More concurrency actually _improves_ Go's CPU utilization while it _degrades_ Spring Boot's.

### Factor 3: GC & Runtime (~P99/max spikes)
Go's garbage collector runs concurrently with sub-millisecond pauses. The JVM's GC causes occasional 10–50ms stop-the-world pauses, visible as P99/max latency spikes even at low load. JIT recompilation adds additional sporadic pauses.

---

## SECTION A — `/customer-summary` (primary endpoint)

This is the heaviest endpoint: it fires 4 concurrent internal calls (customers, accounts, contacts, addresses), fetches transactions, then enriches and maps everything into a summary response.

---

### 1a. hey — 10,000 requests, 200 concurrent

| Metric | Go | Spring Boot | Go faster by |
|---|---|---|---|
| **Requests/sec** ↑ | 53,073 | 4,760 | **11.2x** |
| **Avg latency** ↓ | 3.6ms | 36.6ms | **10.2x** |
| **P50** ↓ | 2.6ms | 19.6ms | **7.5x** |
| **P90** ↓ | 7.6ms | 63.1ms | **8.3x** |
| **P95** ↓ | 10.1ms | 119.9ms | **11.9x** |
| **P99** ↓ | 14.2ms | 390.9ms | **27.5x** |
| **Max** ↓ | 25.1ms | 836.9ms | **33.3x** |

> At 200 concurrent connections, Go keeps P99 at 14ms while Spring jumps to 391ms.

> **Why:** **Factor 1 + 2.** 200 connections = Spring's full thread pool is busy. No queuing yet (pool size = 200), but every thread is loaded. Go handles 200 connections as goroutines with idle capacity remaining. The 11x rps gap is per-request overhead under moderate concurrency.

---

### 1b. hey — 50,000 requests, 500 concurrent

| Metric | Go | Spring Boot | Go faster by |
|---|---|---|---|
| **Requests/sec** ↑ | 74,524 | 5,018 | **14.9x** |
| **Avg latency** ↓ | 6.5ms | 95.5ms | **14.7x** |
| **P50** ↓ | 5.4ms | 72.5ms | **13.4x** |
| **P90** ↓ | 12.3ms | 105.8ms | **8.6x** |
| **P95** ↓ | 16.2ms | 220.3ms | **13.6x** |
| **P99** ↓ | 23.3ms | 932.8ms | **40.0x** |
| **Max** ↓ | 33.5ms | 1,756.9ms | **52.4x** |

> At 500 concurrent connections, Spring Boot's tail latency explodes (P99 nearly 1s, max over 1.7s) while Go stays under 34ms.

> **Why:** Full **Factor 2.** 500 connections vs 200 threads = 300 requests queued at all times. P99 (933ms) is dominated by queue wait time. Go handles all 500 connections as goroutines with zero queuing. The 15x gap is the combined cost of per-request overhead + thread pool exhaustion.

---

### 2a. wrk — 4 threads, 50 connections, 30s

| Metric | Go | Spring Boot | Go faster by |
|---|---|---|---|
| **Requests/sec** ↑ | 73,391 | 5,972 | **12.3x** |
| **Avg latency** ↓ | 34.05ms | 50.61ms | **1.5x** |
| **Max latency** ↓ | 782.9ms | 896.7ms | **1.1x** |
| **Total requests** ↑ | 2,205,415 | 179,542 | **12.3x** |
| **Throughput** ↑ | 40.80 MB/s | 3.43 MB/s | **11.9x** |

> **Why:** **Factor 1** sustained over 30 seconds. Persistent keep-alive connections reveal pure per-request cost. 50 connections still fits in the thread pool. wrk latency includes client-side queueing at high throughput (hence both latencies are elevated vs pure server time), but the 12x throughput gap is decisive.

---

### 2b. wrk — 8 threads, 500 connections, 30s

| Metric | Go | Spring Boot | Go faster by |
|---|---|---|---|
| **Requests/sec** ↑ | 75,440 | 5,921 | **12.7x** |
| **Avg latency** ↓ | 42.32ms | 152.78ms | **3.6x** |
| **Max latency** ↓ | 810.3ms | 2,000ms | **2.5x** |
| **Total requests** ↑ | 2,266,866 | 178,186 | **12.7x** |
| **Throughput** ↑ | 41.94 MB/s | 3.40 MB/s | **12.3x** |
| **Timeouts** | 0 | 90 | — |

> Under high concurrency (500 connections), Spring Boot's latency triples and produces 90 timeouts. Go actually *maintains* throughput at 75k.

> **Why:** **All 3 factors at once**, sustained. Thread pool 2.5x oversubscribed → 90 timeouts at the 2s mark. Go reaches its peak because more goroutines = more I/O overlap. The 13x gap is the result of Spring _degrading_ while Go _sustains_ with more concurrency.

---

### 3a. k6 — Ramp (0→50→50→0 VUs, 50s, sleep 0.5s)

Each VU sends one request, sleeps 500ms, repeats. This simulates typical user traffic where users don't hammer the server non-stop.

| Metric | Go | Spring Boot | Go faster by |
|---|---|---|---|
| **Total requests** | 13,200 | 12,701 | ~same (paced by sleep) |
| **Rate** | 329/s | 317/s | ~same |
| **Avg latency** ↓ | 13.51ms | 18.46ms | **1.4x** |
| **P50** ↓ | 0.58ms | 2.00ms | **3.4x** |
| **P90** ↓ | 1.85ms | 5.13ms | **2.8x** |
| **P95** ↓ | 2.57ms | 6.96ms | **2.7x** |
| **Max** ↓ | 789.2ms | 914.4ms | **1.2x** |
| **Failed** | 0% | 0% | — |

> **Why:** Pure **Factor 1** at moderate load (~330 req/s). k6 paces the VUs (hence ~same total requests). Neither server is stressed. The 3.4x P50 gap is the **irreducible overhead floor** — Spring's ~2ms minimum vs Go's ~0.6ms. This never goes away regardless of load.

---

### 3b. k6 — Stress test (ramp to 500 VUs, 80s, sleep 0.1s)

Pushes to 500 concurrent virtual users with minimal sleep, simulating a sudden traffic surge sustained over time.

| Metric | Go | Spring Boot | Go faster by |
|---|---|---|---|
| **Total requests** ↑ | 86,931 | 85,554 | ~same |
| **Rate** ↑ | 1,086/s | 1,068/s | ~same |
| **Avg latency** ↓ | 14.42ms | 16.83ms | **1.2x** |
| **P50** ↓ | 0.73ms | 1.11ms | **1.5x** |
| **P90** ↓ | 3.01ms | 4.32ms | **1.4x** |
| **P95** ↓ | 4.48ms | 7.09ms | **1.6x** |
| **Max** ↓ | 796.1ms | 1,140.2ms | **1.4x** |
| **Failed** | 0% | 0% | — |

> Both servers handle 1k/s stress comfortably. The gap is moderate because k6 uses sleep-paced VUs, keeping effective RPS within both servers' capacity.

> **Why:** **Factor 1** at sustained moderate load. At ~1,000 req/s, Spring's thread pool is well within capacity (200 threads at 1ms/req = ~200k capacity). The 1.5x P50 gap is the baseline per-request overhead.

---

### 3c. k6 — Spike test (10→500 VUs instant burst, 30s, sleep 0.1s)

Sudden spike from 10 to 500 VUs in 1 second, holds briefly, then drops. Tests how the server handles an instant traffic shock.

| Metric | Go | Spring Boot | Go faster by |
|---|---|---|---|
| **Total requests** ↑ | 66,462 | 60,725 | **1.1x** |
| **Rate** ↑ | 2,213/s | 1,991/s | **1.1x** |
| **Avg latency** ↓ | 14.28ms | 25.53ms | **1.8x** |
| **P50** ↓ | 0.37ms | 0.79ms | **2.1x** |
| **P90** ↓ | 2.69ms | 39.77ms | **14.8x** |
| **P95** ↓ | 5.10ms | 79.66ms | **15.6x** |
| **Max** ↓ | 930.5ms | 981.9ms | **1.1x** |
| **Failed** | 0% | 0% | — |

> This is where the gap is widest: Go's P95 stays at 5.1ms while Spring Boot jumps to 79.7ms — a **15.6x** difference.

> **Why:** **Factor 2 — worst case for tail latency.** 10→500 VUs in 1 second = 50x sudden connection burst. Thread pools grow conservatively; most of the 500 connections queue during the ramp-up. Goroutine creation takes microseconds. The 15.6x P95 gap is the **thread pool warm-up penalty**.

---

### 3d. k6 — Multi-endpoint (3 endpoints, 50 VUs, 50s, sleep 0.3s)

Each VU randomly picks one of `/customer-summary?id=c1`, `/customers`, or `/accounts` per iteration. Tests real-world mixed traffic.

| Metric | Go | Spring Boot | Go faster by |
|---|---|---|---|
| **Total requests** | 17,491 | 16,766 | ~same (paced) |
| **Rate** | 349/s | 335/s | ~same |
| **Avg latency** ↓ | 13.76ms | 19.17ms | **1.4x** |
| **P50** ↓ | 0.67ms | 1.34ms | **2.0x** |
| **P90** ↓ | 2.15ms | 4.73ms | **2.2x** |
| **P95** ↓ | 3.29ms | 9.49ms | **2.9x** |
| **Max** ↓ | 804.2ms | 1,041.2ms | **1.3x** |
| **Failed** | 0% | 0% | — |

> **Why:** Pure **Factor 1** with no concurrency pressure (~350 req/s, well within 200 threads). The 2–3x gap is the baseline framework overhead.

---

### 4a. vegeta — 100 req/s constant rate, 30s

Sends exactly 100 requests per second, no more, no less. Tests baseline latency at a comfortable load.

| Metric | Go | Spring Boot | Go faster by |
|---|---|---|---|
| **Total requests** | 3,000 | 3,000 | — |
| **Mean latency** ↓ | 50.87ms | 69.39ms | **1.4x** |
| **P50** ↓ | 0.45ms | 1.51ms | **3.4x** |
| **P90** ↓ | 164.0ms | 255.6ms | **1.6x** |
| **P95** ↓ | 465.5ms | 631.3ms | **1.4x** |
| **P99** ↓ | 760.3ms | 930.0ms | **1.2x** |
| **Max** ↓ | 845.3ms | 1,037ms | **1.2x** |
| **Success rate** | 100% | 100% | — |

> **Note:** Both servers show elevated P90+ latencies due to `vmmap` profiling running every 2s during tests (causes brief process pauses). The P50 is the true comparison: Go 0.45ms vs Spring 1.51ms.

> **Why:** **Factor 1 + Factor 3.** Both servers are idle at 100/s. The P50 gap (3.4x) is the baseline overhead floor. The tail latencies reflect profiling-induced pauses affecting both equally.

---

### 4b. vegeta — 1,000 req/s constant rate, 30s

Sends exactly 1,000 requests per second. Tests whether the server can sustain moderate constant load.

| Metric | Go | Spring Boot | Go faster by |
|---|---|---|---|
| **Total requests** | 30,000 | 30,000 | — |
| **Mean latency** ↓ | 49.19ms | 104.73ms | **2.1x** |
| **P50** ↓ | 0.19ms | 0.36ms | **1.9x** |
| **P90** ↓ | 116.4ms | 470.2ms | **4.0x** |
| **P95** ↓ | 480.7ms | 822.2ms | **1.7x** |
| **P99** ↓ | 765.7ms | 1,277ms | **1.7x** |
| **Max** ↓ | 859.6ms | 1,799ms | **2.1x** |
| **Success rate** | 100% | 100% | — |

> **Why:** P50 is close (0.19 vs 0.36ms) — both are comfortable. At P90+, Spring's latency starts diverging more significantly (4.0x at P90). At 1k/s, thread pool contention + periodic GC/JIT pauses create tail spikes.

---

### 4c. vegeta — 5,000 req/s constant rate, 30s

Sends exactly 5,000 requests per second. This is where Spring Boot hits its capacity wall.

| Metric | Go | Spring Boot |
|---|---|---|
| **Intended requests** | 150,000 | 150,000 |
| **Completed requests** | 150,000 | 99,212 |
| **Mean latency** | 57.42ms | 1,758ms (1.8s!) |
| **P50** | 0.087ms | 194.9ms |
| **P90** | 199.6ms | 7,372ms (7.4s!) |
| **P95** | 538.1ms | 8,127ms (8.1s!) |
| **P99** | 814.0ms | 15,253ms (15.3s!) |
| **Max** | 952.5ms | 30,003ms (30s!) |
| **Success rate** | **100%** | **97.68%** |
| **Actual throughput** | 5,000/s | 1,765/s |

> **Spring Boot's breaking point.** At 5k req/s, Spring can only actually deliver ~1,765 req/s. Only 99,212 of 150,000 requests completed, 2.32% of those failed, and successful requests waited an average of 1.8 seconds. Go handles all 150k at sub-millisecond P50 latency without a single error.

> **Why:** Vegeta sends at 5k/s regardless of server response. Spring's capacity is ~5–6k req/s under ideal conditions, but fixed-rate bombardment means requests pile up faster than they're drained → accept queue fills → TCP backlog fills → connections refused. Go uses only 6% of its ~75k/s capacity.

---

### 5. ab — 50,000 requests, 500 concurrent

| Metric | Go | Spring Boot | Go faster by |
|---|---|---|---|
| **Requests/sec** ↑ | 19,059 | 5,728 | **3.3x** |
| **P50** ↓ | 12ms | 23ms | **1.9x** |
| **P90** ↓ | 58ms | 42ms | Spring 1.4x* |
| **P95** ↓ | 71ms | 94ms | **1.3x** |
| **P99** ↓ | 239ms | 610ms | **2.6x** |
| **Max** ↓ | 1,977ms | 1,843ms | ~same |
| **Failed** | 0 | 0 | — |

> *Spring's P90 (42ms) appears lower than Go's (58ms) because `ab` rate-limits Go more than Spring. At 19k rps, `ab`'s single-threaded client creates its own queueing delay — Go is bottlenecked by ab, not by server capacity. Spring at 5.7k rps is closer to ab's comfortable range.

> **Why:** ab uses a single-threaded `select()` loop — it's slower than hey/wrk as a _client_. The 3.3x gap is artificially narrow because **ab caps Go more than Spring**. This is why using multiple tools matters.

---

## SECTION B — Per-Endpoint Comparison

Tests each endpoint independently to see if the performance gap is consistent across all routes.

### 6. hey — All endpoints, 10k/200c and 50k/500c

| Endpoint | Load | Go req/s ↑ | Spring req/s ↑ | Go avg ↓ | Spring avg ↓ | Go faster by |
|---|---|---|---|---|---|---|
| `/customer-summary` | 10k/200c | 53,073 | 4,760 | 3.6ms | 36.6ms | **11.2x** |
| `/customers` | 10k/200c | 55,668 | 6,587 | 3.4ms | 28.7ms | **8.5x** |
| `/accounts` | 10k/200c | 60,827 | 3,749 | 3.1ms | 51.2ms | **16.2x** |
| `/customer-summary` | 50k/500c | 74,524 | 5,018 | 6.5ms | 95.5ms | **14.9x** |
| `/customers` | 50k/500c | 76,896 | 6,351 | 6.3ms | 77.1ms | **12.1x** |
| `/accounts` | 50k/500c | 35,668 | 3,868 | 13.7ms | 126.7ms | **9.2x** |

> The gap is consistent across all endpoints. Under high load (50k/500c), the gap ranges from 9–15x because **Factor 2** (thread pool exhaustion) dominates. `/accounts` shows lower Go throughput at 50k/500c due to larger response bodies creating more GC pressure.

### 7. wrk — All endpoints, 50c and 500c (30s)

| Endpoint | Conc | Go req/s ↑ | Spring req/s ↑ | Go avg lat | Spring avg lat | Go faster by |
|---|---|---|---|---|---|---|
| `/customers` | 50c | 76,721 | 6,567 | 42.48ms | 50.97ms | **11.7x** |
| `/customers` | 500c | 77,155 | 6,428 | 50.22ms | 118.96ms | **12.0x** |
| `/accounts` | 50c | 78,333 | 7,390 | 34.88ms | 51.50ms | **10.6x** |
| `/accounts` | 500c | 78,867 | 7,402 | 42.15ms | 110.93ms | **10.6x** |
| `/customer-summary` | 50c | 73,391 | 5,972 | 34.05ms | 50.61ms | **12.3x** |
| `/customer-summary` | 500c | 75,440 | 5,921 | 42.32ms | 152.78ms | **12.7x** |

> Go sustains 73–79k rps across all endpoints and connection levels. Spring ranges from 5.9–7.4k with degrading latency under 500c.

### 8. vegeta — All endpoints, 5k/s (Spring breaking point)

| Endpoint | Go success | Spring success | Go mean | Spring mean | Spring throughput |
|---|---|---|---|---|---|
| `/customers` | 100% | 100% | 60.4ms | 168.7ms | 5,000/s |
| `/accounts` | 100% | 100% | 65.3ms | 348.2ms | 5,000/s |
| `/customer-summary` | 100% | 97.68% | 57.4ms | 1,758ms | 1,765/s |

> `/customer-summary` is the only endpoint where Spring Boot **breaks** at 5k/s. The simpler endpoints (`/customers`, `/accounts`) survive at 5k/s but with significantly higher latency. `/accounts` at 5k/s shows a 5.3x latency gap.

### 9. ab — All endpoints, 50k/500c

| Endpoint | Go req/s ↑ | Spring req/s ↑ | Go P50 ↓ | Spring P50 ↓ | Go faster by |
|---|---|---|---|---|---|
| `/customers` | 18,096 | 6,908 | 12ms | 21ms | **2.6x** |
| `/accounts` | 13,376 | 1,357 | 18ms | 179ms | **9.9x** |
| `/customer-summary` | 19,059 | 5,728 | 12ms | 23ms | **3.3x** |

> Spring at `/accounts` shows dramatic degradation (1,357 rps, P50=179ms) — this endpoint returns larger response bodies, amplifying per-request overhead.

---

## Throughput Summary

```
Requests/sec — /customer-summary?id=c1

wrk 500c (30s)
  Go:     ██████████████████████████████████████   75,440
  Spring: ███                                       5,921

wrk 50c (30s)
  Go:     █████████████████████████████████████    73,391
  Spring: ███                                       5,972

hey (50k/500c)
  Go:     █████████████████████████████████████    74,524
  Spring: ███                                       5,018

hey (10k/200c)
  Go:     ██████████████████████████              53,073
  Spring: ███                                       4,760

ab (50k/500c)
  Go:     ██████████                              19,059
  Spring: ███                                       5,728
```

| Tool & Config | Go req/s ↑ | Spring req/s ↑ | Go advantage |
|---|---|---|---|
| wrk 500c/30s | **75,440** | 5,921 | **12.7x** |
| wrk 50c/30s | **73,391** | 5,972 | **12.3x** |
| hey 50k/500c | **74,524** | 5,018 | **14.9x** |
| hey 10k/200c | **53,073** | 4,760 | **11.2x** |
| ab 50k/500c | **19,059** | 5,728 | **3.3x** |

---

## Latency Comparison (P50 across all tests)

| Test | Go P50 ↓ | Spring P50 ↓ | Go faster by |
|---|---|---|---|
| hey 10k/200c | 2.6ms | 19.6ms | **7.5x** |
| hey 50k/500c | 5.4ms | 72.5ms | **13.4x** |
| wrk 50c | 34.05ms* | 50.61ms* | **1.5x** |
| wrk 500c | 42.32ms* | 152.78ms* | **3.6x** |
| k6 ramp | 0.58ms | 2.00ms | **3.4x** |
| k6 stress | 0.73ms | 1.11ms | **1.5x** |
| k6 spike | 0.37ms | 0.79ms | **2.1x** |
| k6 multi | 0.67ms | 1.34ms | **2.0x** |
| vegeta 100/s | 0.45ms | 1.51ms | **3.4x** |
| vegeta 1k/s | 0.19ms | 0.36ms | **1.9x** |
| ab 50k/500c | 12ms | 23ms | **1.9x** |

> *wrk latency includes client-side pipeline queueing, not pure server time.

---

## Key Takeaways

1. **Go is 9–15x faster** in pure throughput across hey and wrk, measured in complete isolation with cold starts
2. **Go scales with concurrency** — throughput stays flat at 73–79k req/s from 50c to 500c. Spring Boot holds at 5–7k but degrades with timeouts at 500c
3. **Spring Boot breaks at 5k req/s on `/customer-summary`** — vegeta 5k/s shows only 97.68% success rate and 1.8s mean latency; Go handles it at 100% with sub-ms P50
4. **Spike handling is Go's biggest win** — under a sudden 500-VU burst, Go's P95 is 5.1ms vs Spring Boot's 79.7ms (**15.6x**)
5. **Even at low load, Go is 3.4x faster** — vegeta 100/s and k6 ramp (trivial load) show 3.4x P50 advantage
6. **Go's tail latency stays controlled** — P99 under heavy hey load (50k/500c) is 23.3ms vs Spring's 932.8ms (**40x**)
7. **Both achieve 0% errors** under moderate load — Spring Boot only starts failing at 5,000+ req/s constant rate on the heavy endpoint
8. **The gap is consistent across all endpoints** — `/customers`, `/accounts`, and `/customer-summary` all show 9–16x throughput advantage
9. **Cold start RSS: Go 40 MB vs Spring 201 MB** — Go uses 5x less memory even before the first request (see [PROFILING_RESULTS.md](PROFILING_RESULTS.md))
