#!/usr/bin/env bash
# ─── Supplemental wrk + vegeta tests for V2 run ───────────────────────────────
# Appends wrk and vegeta result files into an existing V2 results directory.
# Each server is started fresh, tested, then stopped — same methodology as
# run_master_v2.sh.
#
# wrk:    3 endpoints × 2 configs (50c/30s, 500c/30s)  = 6 tests per server
# vegeta: 3 endpoints × 3 rates  (100, 1k, 5k rps/30s) = 9 tests per server
#
# Usage: bash run_wrk_vegeta_v2.sh <results_v2_dir>
# Example: bash run_wrk_vegeta_v2.sh results_v2_20260420_170456
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/common_v2.sh"

if [[ $# -lt 1 ]]; then
    echo "Usage: bash run_wrk_vegeta_v2.sh <results_v2_dir>"
    exit 1
fi

ARG="$1"
if [[ "$ARG" != /* ]]; then
    RESULTS_DIR="${SCRIPT_DIR}/${ARG}"
else
    RESULTS_DIR="$ARG"
fi

if [[ ! -d "$RESULTS_DIR" ]]; then
    echo "ERROR: results dir not found: $RESULTS_DIR"
    exit 1
fi

echo "=================================================================="
echo " wrk + vegeta Supplemental Tests V2"
echo " Go | Spring | Virtual Threads | WebFlux | Vert.x"
echo " Results dir: ${RESULTS_DIR}"
echo " Started: $(date)"
echo "=================================================================="
echo ""

# ─── Ensure all ports are free ────────────────────────────────────────────────
echo ">>> Ensuring all ports are free..."
for port_name in "$GO_PORT:Go" "$SPRING_PORT:Spring" "$VT_PORT:VT" "$WF_PORT:WebFlux" "$VERTX_PORT:Vertx"; do
    port="${port_name%%:*}"
    name="${port_name##*:}"
    stop_server "$port" "${name} (cleanup)" 2>/dev/null || true
done
sleep 3

# ─── Run wrk+vegeta for one server ────────────────────────────────────────────
run_extra_tests() {
    local server_type=$1
    local base_url=$2
    local output_dir=$3
    local server_port=$4

    local server_upper
    server_upper=$(echo "$server_type" | tr '[:lower:]' '[:upper:]')

    echo ""
    echo "=============================="
    echo " ${server_upper} — wrk + vegeta"
    echo "=============================="
    echo ""

    # Start server
    case "$server_type" in
        go)      start_go_server ;;
        spring)  start_spring_server ;;
        vt)      start_vt_server ;;
        webflux) start_webflux_server ;;
        vertx)   start_vertx_server ;;
    esac

    verify_endpoints "$base_url" "$server_upper"

    local ep_urls=("/customers" "/accounts" "/customer-summary?id=c1")
    local ep_names=("customers" "accounts" "customer_summary")

    # ─── wrk tests ───────────────────────────────────────────────────────────
    echo ""
    echo "--- wrk tests ---"
    for i in 0 1 2; do
        local ep="${ep_urls[$i]}"
        local name="${ep_names[$i]}"

        echo ">>> wrk: ${name} 50c/30s"
        wrk -t4 -c50 -d30s "${base_url}${ep}" > "${output_dir}/wrk_${name}_50c.txt" 2>&1
        sleep "$COOLDOWN_SECONDS"

        echo ">>> wrk: ${name} 500c/30s"
        wrk -t8 -c500 -d30s "${base_url}${ep}" > "${output_dir}/wrk_${name}_500c.txt" 2>&1
        sleep "$COOLDOWN_SECONDS"
    done

    # ─── vegeta tests ────────────────────────────────────────────────────────
    echo ""
    echo "--- vegeta tests ---"
    local rates=("100" "1000" "5000")
    local rate_names=("100" "1k" "5k")

    for i in 0 1 2; do
        local ep="${ep_urls[$i]}"
        local name="${ep_names[$i]}"

        for r in 0 1 2; do
            local rate="${rates[$r]}"
            local rate_name="${rate_names[$r]}"

            echo ">>> vegeta: ${name} ${rate_name} rps/30s"
            echo "GET ${base_url}${ep}" \
                | vegeta attack -rate="$rate" -duration=30s \
                | vegeta report > "${output_dir}/vegeta_${name}_${rate_name}.txt" 2>&1
            sleep "$COOLDOWN_SECONDS"
        done
    done

    stop_server "$server_port" "$server_upper"
    echo "  ${server_upper} extra tests done — output: ${output_dir}"
}

# ─── Run all 5 servers ────────────────────────────────────────────────────────
run_extra_tests "go"      "$GO_URL"     "${RESULTS_DIR}/go"      "$GO_PORT"
echo ">>> Pausing 5s between servers..."; sleep 5

run_extra_tests "spring"  "$SPRING_URL" "${RESULTS_DIR}/spring"  "$SPRING_PORT"
echo ">>> Pausing 5s between servers..."; sleep 5

run_extra_tests "vt"      "$VT_URL"     "${RESULTS_DIR}/vt"      "$VT_PORT"
echo ">>> Pausing 5s between servers..."; sleep 5

run_extra_tests "webflux" "$WF_URL"     "${RESULTS_DIR}/webflux" "$WF_PORT"
echo ">>> Pausing 5s between servers..."; sleep 5

run_extra_tests "vertx"   "$VERTX_URL"  "${RESULTS_DIR}/vertx"   "$VERTX_PORT"

echo ""
echo "=================================================================="
echo " ALL wrk + vegeta TESTS COMPLETE"
echo " Finished: $(date)"
echo " Results:  ${RESULTS_DIR}"
echo ""
echo " Run extractor:"
echo "   python3 extract_perf_v2.py ${RESULTS_DIR}"
echo "=================================================================="
