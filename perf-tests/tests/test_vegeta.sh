#!/usr/bin/env bash
# ─── vegeta load tests: 3 endpoints × 3 rates = 9 tests ──────────────────────
# Usage: test_vegeta.sh <BASE_URL> <OUTPUT_DIR> <SERVER_NAME>
set -uo pipefail
source "$(dirname "$0")/../lib/common.sh"

BASE_URL=$1
OUTPUT_DIR=$2
SERVER_NAME=$3

ENDPOINTS=("/customers" "/accounts" "/customer-summary?id=c1")
EP_NAMES=("customers" "accounts" "customer_summary")

RATES=("100" "1000" "5000")
RATE_NAMES=("100" "1k" "5k")

echo "=== vegeta tests ($SERVER_NAME) ==="

for i in 0 1 2; do
  ep="${ENDPOINTS[$i]}"
  name="${EP_NAMES[$i]}"

  for r in 0 1 2; do
    rate="${RATES[$r]}"
    rate_name="${RATE_NAMES[$r]}"

    PHASE="vegeta_${name}_${rate_name}"
    set_phase "$PHASE"
    echo ">>> vegeta: ${name} ${rate_name} rps"
    echo "GET ${BASE_URL}${ep}" | vegeta attack -rate="$rate" -duration=30s | vegeta report \
      > "${OUTPUT_DIR}/vegeta_${name}_${rate_name}.txt" 2>&1
    sample_to_csv "$PHASE"
    health_check "$SERVER_NAME" "$PHASE"
    cooldown "$PHASE"
  done
done

echo "=== vegeta tests complete ==="
