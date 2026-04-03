#!/usr/bin/env bash
# ─── ab load tests: 3 endpoints × 1 config = 3 tests ──────────────────────────
# Usage: test_ab.sh <BASE_URL> <OUTPUT_DIR> <SERVER_NAME>
set -uo pipefail
source "$(dirname "$0")/../lib/common.sh"

BASE_URL=$1
OUTPUT_DIR=$2
SERVER_NAME=$3

ENDPOINTS=("/customers" "/accounts" "/customer-summary?id=c1")
EP_NAMES=("customers" "accounts" "customer_summary")

echo "=== ab tests ($SERVER_NAME) ==="

for i in 0 1 2; do
  ep="${ENDPOINTS[$i]}"
  name="${EP_NAMES[$i]}"

  # 50k requests / 500 concurrency
  PHASE="ab_${name}_50k_500c"
  set_phase "$PHASE"
  echo ">>> ab: ${name} 50k/500c"
  ab -n 50000 -c 500 "${BASE_URL}${ep}" > "${OUTPUT_DIR}/ab_${name}_50k.txt" 2>&1
  sample_to_csv "$PHASE"
  health_check "$SERVER_NAME" "$PHASE"
  cooldown "$PHASE"
done

echo "=== ab tests complete ==="
