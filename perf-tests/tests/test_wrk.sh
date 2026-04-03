#!/usr/bin/env bash
# ─── wrk load tests: 3 endpoints × 2 configs = 6 tests ────────────────────────
# Usage: test_wrk.sh <BASE_URL> <OUTPUT_DIR> <SERVER_NAME>
set -uo pipefail
source "$(dirname "$0")/../lib/common.sh"

BASE_URL=$1
OUTPUT_DIR=$2
SERVER_NAME=$3

ENDPOINTS=("/customers" "/accounts" "/customer-summary?id=c1")
EP_NAMES=("customers" "accounts" "customer_summary")

echo "=== wrk tests ($SERVER_NAME) ==="

for i in 0 1 2; do
  ep="${ENDPOINTS[$i]}"
  name="${EP_NAMES[$i]}"

  # 50 connections / 30s
  PHASE="wrk_${name}_50c"
  set_phase "$PHASE"
  echo ">>> wrk: ${name} 50c/30s"
  wrk -t4 -c50 -d30s "${BASE_URL}${ep}" > "${OUTPUT_DIR}/wrk_${name}_50c.txt" 2>&1
  sample_to_csv "$PHASE"
  health_check "$SERVER_NAME" "$PHASE"
  cooldown "$PHASE"

  # 500 connections / 30s
  PHASE="wrk_${name}_500c"
  set_phase "$PHASE"
  echo ">>> wrk: ${name} 500c/30s"
  wrk -t8 -c500 -d30s "${BASE_URL}${ep}" > "${OUTPUT_DIR}/wrk_${name}_500c.txt" 2>&1
  sample_to_csv "$PHASE"
  health_check "$SERVER_NAME" "$PHASE"
  cooldown "$PHASE"
done

echo "=== wrk tests complete ==="
