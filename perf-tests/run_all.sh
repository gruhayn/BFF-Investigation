#!/usr/bin/env bash
set -euo pipefail

GO_PORT=8080
SPRING_PORT=8084
GO_URL="http://localhost:${GO_PORT}"
SPRING_URL="http://localhost:${SPRING_PORT}"
ENDPOINT="/customer-summary?id=c1"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DIR="results_${TIMESTAMP}"
mkdir -p "$DIR"

echo "=== Results dir: $DIR ==="

wait_ready() {
  local url=$1 name=$2
  for i in $(seq 1 10); do
    if curl -sf "$url/health" > /dev/null 2>&1 || curl -sf "${url}${ENDPOINT}" > /dev/null 2>&1; then
      echo "$name is ready"
      return 0
    fi
    sleep 1
  done
  echo "WARNING: $name not responding"
  return 1
}

wait_ready "$GO_URL" "Go"
wait_ready "$SPRING_URL" "Spring"

# ─── hey ───────────────────────────────────────────────────────────────────────
echo ">>> hey: Go customers (10k)"
hey -n 10000 -c 200 "${GO_URL}/customers" > "$DIR/hey_go_customers.txt" 2>&1
echo ">>> hey: Spring customers (10k)"
hey -n 10000 -c 200 "${SPRING_URL}/customers" > "$DIR/hey_spring_customers.txt" 2>&1

echo ">>> hey: Go accounts (10k)"
hey -n 10000 -c 200 "${GO_URL}/accounts" > "$DIR/hey_go_accounts.txt" 2>&1
echo ">>> hey: Spring accounts (10k)"
hey -n 10000 -c 200 "${SPRING_URL}/accounts" > "$DIR/hey_spring_accounts.txt" 2>&1

echo ">>> hey: Go customers (50k)"
hey -n 50000 -c 500 "${GO_URL}/customers" > "$DIR/hey_go_customers_50k.txt" 2>&1
echo ">>> hey: Spring customers (50k)"
hey -n 50000 -c 500 "${SPRING_URL}/customers" > "$DIR/hey_spring_customers_50k.txt" 2>&1

echo ">>> hey: Go accounts (50k)"
hey -n 50000 -c 500 "${GO_URL}/accounts" > "$DIR/hey_go_accounts_50k.txt" 2>&1
echo ">>> hey: Spring accounts (50k)"
hey -n 50000 -c 500 "${SPRING_URL}/accounts" > "$DIR/hey_spring_accounts_50k.txt" 2>&1

echo ">>> hey: Go customer-summary (50k)"
hey -n 50000 -c 500 "${GO_URL}${ENDPOINT}" > "$DIR/hey_go_summary_50k.txt" 2>&1
echo ">>> hey: Spring customer-summary (50k)"
hey -n 50000 -c 500 "${SPRING_URL}${ENDPOINT}" > "$DIR/hey_spring_summary_50k.txt" 2>&1

# ─── wrk ───────────────────────────────────────────────────────────────────────
echo ">>> wrk: Go 50c"
wrk -t4 -c50 -d30s "${GO_URL}${ENDPOINT}" > "$DIR/wrk_go_50c.txt" 2>&1
echo ">>> wrk: Spring 50c"
wrk -t4 -c50 -d30s "${SPRING_URL}${ENDPOINT}" > "$DIR/wrk_spring_50c.txt" 2>&1

echo ">>> wrk: Go 500c"
wrk -t8 -c500 -d30s "${GO_URL}${ENDPOINT}" > "$DIR/wrk_go_500c.txt" 2>&1
echo ">>> wrk: Spring 500c"
wrk -t8 -c500 -d30s "${SPRING_URL}${ENDPOINT}" > "$DIR/wrk_spring_500c.txt" 2>&1

# ─── k6 ───────────────────────────────────────────────────────────────────────
echo ">>> k6: Go ramp"
BASE_URL="$GO_URL" k6 run k6_test.js --summary-export "$DIR/k6_go_ramp.json" > "$DIR/k6_go_ramp.txt" 2>&1
echo ">>> k6: Spring ramp"
BASE_URL="$SPRING_URL" k6 run k6_test.js --summary-export "$DIR/k6_spring_ramp.json" > "$DIR/k6_spring_ramp.txt" 2>&1

echo ">>> k6: Go stress"
BASE_URL="$GO_URL" k6 run k6_stress.js --summary-export "$DIR/k6_go_stress.json" > "$DIR/k6_go_stress.txt" 2>&1
echo ">>> k6: Spring stress"
BASE_URL="$SPRING_URL" k6 run k6_stress.js --summary-export "$DIR/k6_spring_stress.json" > "$DIR/k6_spring_stress.txt" 2>&1

echo ">>> k6: Go spike"
BASE_URL="$GO_URL" k6 run k6_spike.js --summary-export "$DIR/k6_go_spike.json" > "$DIR/k6_spike_go.txt" 2>&1
echo ">>> k6: Spring spike"
BASE_URL="$SPRING_URL" k6 run k6_spike.js --summary-export "$DIR/k6_spring_spike.json" > "$DIR/k6_spring_spike.txt" 2>&1

echo ">>> k6: Go multi"
BASE_URL="$GO_URL" k6 run k6_multi_endpoint.js --summary-export "$DIR/k6_go_multi.json" > "$DIR/k6_go_multi.txt" 2>&1
echo ">>> k6: Spring multi"
BASE_URL="$SPRING_URL" k6 run k6_multi_endpoint.js --summary-export "$DIR/k6_spring_multi.json" > "$DIR/k6_spring_multi.txt" 2>&1

# ─── vegeta ────────────────────────────────────────────────────────────────────
echo ">>> vegeta: Go 100 rps"
echo "GET ${GO_URL}${ENDPOINT}" | vegeta attack -rate=100 -duration=30s | vegeta report > "$DIR/vegeta_go_100.txt" 2>&1
echo ">>> vegeta: Spring 100 rps"
echo "GET ${SPRING_URL}${ENDPOINT}" | vegeta attack -rate=100 -duration=30s | vegeta report > "$DIR/vegeta_spring_100.txt" 2>&1

echo ">>> vegeta: Go 1k rps"
echo "GET ${GO_URL}${ENDPOINT}" | vegeta attack -rate=1000 -duration=30s | vegeta report > "$DIR/vegeta_go_1k.txt" 2>&1
echo ">>> vegeta: Spring 1k rps"
echo "GET ${SPRING_URL}${ENDPOINT}" | vegeta attack -rate=1000 -duration=30s | vegeta report > "$DIR/vegeta_spring_1k.txt" 2>&1

echo ">>> vegeta: Go 5k rps"
echo "GET ${GO_URL}${ENDPOINT}" | vegeta attack -rate=5000 -duration=30s | vegeta report > "$DIR/vegeta_go_5k.txt" 2>&1
echo ">>> vegeta: Spring 5k rps"
echo "GET ${SPRING_URL}${ENDPOINT}" | vegeta attack -rate=5000 -duration=30s | vegeta report > "$DIR/vegeta_spring_5k.txt" 2>&1

# ─── ab ────────────────────────────────────────────────────────────────────────
echo ">>> ab: Go 50k"
ab -n 50000 -c 500 "${GO_URL}${ENDPOINT}" > "$DIR/ab_go_50k.txt" 2>&1
echo ">>> ab: Spring 50k"
ab -n 50000 -c 500 "${SPRING_URL}${ENDPOINT}" > "$DIR/ab_spring_50k.txt" 2>&1

echo ""
echo "=== All tests complete. Results in: $DIR ==="
ls -la "$DIR"
