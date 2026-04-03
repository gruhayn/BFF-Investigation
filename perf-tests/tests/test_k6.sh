#!/usr/bin/env bash
# ─── k6 load tests: 3 endpoints × 3 scenarios + 1 multi = 10 tests ────────────
# Usage: test_k6.sh <BASE_URL> <OUTPUT_DIR> <SERVER_NAME>
set -uo pipefail
source "$(dirname "$0")/../lib/common.sh"

BASE_URL=$1
OUTPUT_DIR=$2
SERVER_NAME=$3

K6_DIR="$(dirname "$0")/.."

ENDPOINTS=("/customers" "/accounts" "/customer-summary?id=c1")
EP_NAMES=("customers" "accounts" "customer_summary")

SCENARIOS=("k6_test.js:ramp" "k6_stress.js:stress" "k6_spike.js:spike")

echo "=== k6 tests ($SERVER_NAME) ==="

# Single-endpoint scenarios: 3 endpoints × 3 scenarios = 9 tests
for i in 0 1 2; do
  ep="${ENDPOINTS[$i]}"
  name="${EP_NAMES[$i]}"

  for scenario_entry in "${SCENARIOS[@]}"; do
    js_file="${scenario_entry%%:*}"
    scenario="${scenario_entry##*:}"

    PHASE="k6_${scenario}_${name}"
    set_phase "$PHASE"
    echo ">>> k6: ${scenario} / ${name}"
    BASE_URL="$BASE_URL" ENDPOINT="$ep" k6 run "${K6_DIR}/${js_file}" \
      --summary-export "${OUTPUT_DIR}/k6_${scenario}_${name}.json" \
      > "${OUTPUT_DIR}/k6_${scenario}_${name}.txt" 2>&1
    sample_to_csv "$PHASE"
    health_check "$SERVER_NAME" "$PHASE"
    cooldown "$PHASE"
  done
done

# Multi-endpoint scenario (randomizes across all 3 endpoints)
PHASE="k6_multi"
set_phase "$PHASE"
echo ">>> k6: multi-endpoint"
BASE_URL="$BASE_URL" k6 run "${K6_DIR}/k6_multi_endpoint.js" \
  --summary-export "${OUTPUT_DIR}/k6_multi.json" \
  > "${OUTPUT_DIR}/k6_multi.txt" 2>&1
sample_to_csv "$PHASE"
health_check "$SERVER_NAME" "$PHASE"
cooldown "$PHASE"

echo "=== k6 tests complete ==="
