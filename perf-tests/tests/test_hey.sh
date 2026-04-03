#!/usr/bin/env bash
# ─── hey load tests: 3 endpoints × 2 loads = 6 tests ──────────────────────────
# Usage: test_hey.sh <BASE_URL> <OUTPUT_DIR> <SERVER_NAME>
set -uo pipefail
source "$(dirname "$0")/../lib/common.sh"

BASE_URL=$1
OUTPUT_DIR=$2
SERVER_NAME=$3

ENDPOINTS=("/customers" "/accounts" "/customer-summary?id=c1")
EP_NAMES=("customers" "accounts" "customer_summary")

echo "=== hey tests ($SERVER_NAME) ==="

for i in 0 1 2; do
  ep="${ENDPOINTS[$i]}"
  name="${EP_NAMES[$i]}"

  # 10k requests / 200 concurrency
  PHASE="hey_${name}_10k_200c"
  set_phase "$PHASE"
  echo ">>> hey: ${name} 10k/200c"
  hey -n 10000 -c 200 "${BASE_URL}${ep}" > "${OUTPUT_DIR}/hey_${name}_10k.txt" 2>&1
  sample_to_csv "$PHASE"
  health_check "$SERVER_NAME" "$PHASE"
  cooldown "$PHASE"

  # 50k requests / 500 concurrency
  PHASE="hey_${name}_50k_500c"
  set_phase "$PHASE"
  echo ">>> hey: ${name} 50k/500c"
  hey -n 50000 -c 500 "${BASE_URL}${ep}" > "${OUTPUT_DIR}/hey_${name}_50k.txt" 2>&1
  sample_to_csv "$PHASE"
  health_check "$SERVER_NAME" "$PHASE"
  cooldown "$PHASE"
done

echo "=== hey tests complete ==="
