#!/usr/bin/env bash
# kavach Module 0 integrated verification (iOS + backend + SpacetimeDB).
# Plan: docs/testing/module0-integration-test-plan.md
#
#   scripts/module0-integration.sh                     # L1-L4, L6 build, security checks
#   scripts/module0-integration.sh --with-simulator    # + L5 xcodebuild test on an iOS simulator
#   scripts/module0-integration.sh --with-spacetime    # + L6 local publish/reducer/query
#
# Starts the backend on 127.0.0.1:${KAVACH_TEST_PORT:-3101} and always stops it. Prints no secrets.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PORT="${KAVACH_TEST_PORT:-3101}"
BASE="http://127.0.0.1:${PORT}"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/kavach-m0.XXXXXX")"
WITH_SIM=0; WITH_STDB=0
for arg in "$@"; do
  case "$arg" in
    --with-simulator) WITH_SIM=1 ;;
    --with-spacetime) WITH_STDB=1 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

API_PID=""; STDB_PID=""
cleanup() {
  [ -n "$API_PID" ] && kill "$API_PID" 2>/dev/null && wait "$API_PID" 2>/dev/null
  [ -n "$STDB_PID" ] && kill "$STDB_PID" 2>/dev/null && wait "$STDB_PID" 2>/dev/null
  true
}
trap cleanup EXIT INT TERM

RESULTS=(); FAILED=0
# Statuses: PASS, FAIL, SKIP (not requested), BLOCKED (requested but the environment cannot run it).
# Exit code is non-zero on any FAIL; BLOCKED is reported but is never counted as a pass.
record() { RESULTS+=("$(printf '%-8s %s' "$1" "$2")"); [ "$1" = FAIL ] && FAILED=1; return 0; }
step() { echo; echo "==> $1"; }
run() { # run <label> <command...>
  local label="$1"; shift
  if "$@" >"$WORK/out.log" 2>&1; then record PASS "$label"; else record FAIL "$label"; tail -20 "$WORK/out.log"; fi
}

# ---------------------------------------------------------------- L1 backend
step "L1/L2/L3 backend: install, tests, typecheck, build"
cd "$ROOT/backend"
[ -d node_modules ] || npm ci --no-audit --no-fund >/dev/null 2>&1
run "backend npm test (unit, HTTP, real socket, iOS fixture parity)" npm test
grep -E "Tests " "$WORK/out.log" | tail -1
run "backend typecheck" npm run -s typecheck
run "backend build" npm run -s build

# ---------------------------------------------------------------- start API
step "Start backend on ${BASE}"
if lsof -nP -iTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1; then
  record FAIL "port ${PORT} already in use; set KAVACH_TEST_PORT"; API_UP=0
else
  HOST=127.0.0.1 PORT="$PORT" ANALYSIS_PROVIDER=mock node dist/server.js >"$WORK/api.log" 2>&1 &
  API_PID=$!
  if curl -s -o /dev/null --retry 20 --retry-connrefused --retry-delay 1 "$BASE/health"; then API_UP=1; else API_UP=0; record FAIL "backend did not start"; fi
fi

if [ "$API_UP" = 1 ]; then
  step "API smoke (contract section 8 commands)"
  code() { curl -s -o "$WORK/body.json" -w '%{http_code}' "$@"; }
  [ "$(code "$BASE/health")" = 200 ] && grep -q '"service":"kavach-api"' "$WORK/body.json" \
    && record PASS "GET /health -> 200" || record FAIL "GET /health"
  [ "$(code -X POST "$BASE/api/v1/analyze" -H 'Content-Type: application/json' -d '{"kind":"call","content":"My bank says to urgently wire money."}')" = 200 ] \
    && grep -q '"riskLevel":"critical"' "$WORK/body.json" && grep -q '"source":"mock"' "$WORK/body.json" \
    && record PASS "POST analyze valid -> 200 critical mock" || record FAIL "POST analyze valid"
  [ "$(code -X POST "$BASE/api/v1/analyze" -H 'Content-Type: application/json' -d '{"kind":"unknown","content":"test"}')" = 400 ] \
    && grep -q '"code":"VALIDATION_ERROR"' "$WORK/body.json" \
    && record PASS "POST analyze invalid kind -> 400 VALIDATION_ERROR" || record FAIL "POST analyze invalid kind"
  [ "$(code -X POST "$BASE/api/v1/analyze" -H 'Content-Type: application/json' -d '{"kind":')" = 400 ] \
    && grep -q '"code":"INVALID_JSON"' "$WORK/body.json" \
    && record PASS "POST analyze bad JSON -> 400 INVALID_JSON" || record FAIL "POST analyze bad JSON"

  bound="$(lsof -nP -iTCP:"$PORT" -sTCP:LISTEN 2>/dev/null | awk 'NR>1{print $9}' | sort -u | tr '\n' ' ')"
  [ "$bound" = "127.0.0.1:${PORT} " ] && record PASS "S2 backend bound to loopback only" || record FAIL "S2 bind address: ${bound}"

  # S1: a marker sent in content/context/phone must never reach the log.
  curl -s -o /dev/null -X POST "$BASE/api/v1/analyze" -H 'Content-Type: application/json' -H 'Authorization: Bearer MARKERTOKEN9931' \
    -d '{"kind":"sms","content":"MARKERCONTENT9931 tell me the code","context":"MARKERCONTEXT9931","phoneNumber":"+12025550199"}'

  # ------------------------------------------------------------ L3/L4 Swift
  step "L3/L4 Swift host tests incl. live round trip against ${BASE}"
  if command -v swift >/dev/null; then
    KAVACH_LIVE_API_URL="$BASE" swift test --package-path "$ROOT/ios" --scratch-path "$WORK/swift" >"$WORK/swift.log" 2>&1
    swift_rc=$?
    summary="$(grep -E 'Executed [0-9]+ tests' "$WORK/swift.log" | tail -1 | sed 's/^[[:space:]]*//')"
    echo "$summary"
    if [ $swift_rc -eq 0 ] && ! grep -q "LiveBackendIntegrationTests.*skipped" "$WORK/swift.log" \
       && grep -q "Test Suite 'LiveBackendIntegrationTests' passed" "$WORK/swift.log"; then
      record PASS "Swift tests incl. LiveBackendIntegrationTests (${summary})"
    else
      record FAIL "Swift tests (${summary:-no summary})"; grep -E "error:|failed" "$WORK/swift.log" | head -20
    fi
  else
    record SKIP "Swift toolchain not found"
  fi

  if grep -qE "MARKER|2025550199" "$WORK/api.log"; then record FAIL "S1 submitted text found in backend log"; else record PASS "S1 backend log free of submitted text, phone, token"; fi
  # The backend stays up through L5: the iOS UI test testLiveMockResponseDisclosure needs it on 127.0.0.1:3101.
fi

# ---------------------------------------------------------------- L5 simulator
if [ "$WITH_SIM" = 1 ]; then
  step "L5 xcodebuild test on an iOS simulator"
  [ "$PORT" = 3101 ] || echo "note: testLiveMockResponseDisclosure expects 127.0.0.1:3101 and will skip on port ${PORT}"
  SIM_ID="$(xcrun simctl list devices available 2>/dev/null | grep -m1 -E '^\s+iPhone' | grep -oE '[0-9A-F-]{36}')"
  if [ -z "$SIM_ID" ]; then
    record SKIP "L5 no available iPhone simulator"
  else
    xcodebuild test -project "$ROOT/ios/Kavach.xcodeproj" -scheme Kavach -destination "platform=iOS Simulator,id=${SIM_ID}" \
      -derivedDataPath "$WORK/derived" CODE_SIGNING_ALLOWED=NO >"$WORK/xcode.log" 2>&1
    rc=$?
    grep -E "Executed [0-9]+ tests|\*\* TEST" "$WORK/xcode.log" | tail -3
    if [ $rc -eq 0 ]; then
      record PASS "L5 xcodebuild test (simulator ${SIM_ID})"
    elif grep -q "is not installed. Please download and install the platform" "$WORK/xcode.log"; then
      # Toolchain gap on this Mac, not a test result: report as NOT VERIFIED.
      record BLOCKED "L5 NOT VERIFIED: $(grep -oE 'iOS [0-9.]+ is not installed' "$WORK/xcode.log" | head -1) (Xcode > Settings > Components)"
    else
      record FAIL "L5 xcodebuild test (see $WORK/xcode.log)"; grep -E "error:|failed" "$WORK/xcode.log" | head -15
    fi
  fi
else
  record SKIP "L5 simulator tests (pass --with-simulator)"
fi

if [ -n "$API_PID" ]; then kill "$API_PID" 2>/dev/null; wait "$API_PID" 2>/dev/null; API_PID=""; fi

# ---------------------------------------------------------------- L6 SpacetimeDB
step "L6 SpacetimeDB module"
cd "$ROOT/spacetimedb"
[ -d node_modules ] || npm ci --no-audit --no-fund >/dev/null 2>&1
run "spacetimedb typecheck" npx tsc --noEmit
if command -v spacetime >/dev/null; then
  run "spacetimedb build" spacetime build
  if [ "$WITH_STDB" = 1 ]; then
    if lsof -nP -iTCP:3000 -sTCP:LISTEN >/dev/null 2>&1; then
      record SKIP "L6 local publish: port 3000 busy (a SpacetimeDB server may already be running)"
    else
      spacetime start >"$WORK/stdb.log" 2>&1 & STDB_PID=$!
      curl -s -o /dev/null --retry 20 --retry-connrefused --retry-delay 1 http://127.0.0.1:3000/v1/ping
      run "L6 local publish kavach-m0-test" spacetime publish --server local kavach-m0-test -y --no-config
      run "L6 reducer set_development_status" spacetime call --server local kavach-m0-test --no-config set_development_status integration m0-ok
      (cd "$WORK" && spacetime sql --server local kavach-m0-test "SELECT status FROM development_status WHERE component = 'integration'" 2>/dev/null) | grep -q '"m0-ok"' \
        && record PASS "L6 query returns reducer write" || record FAIL "L6 query"
      kill "$STDB_PID" 2>/dev/null; wait "$STDB_PID" 2>/dev/null; STDB_PID=""
    fi
  else
    record SKIP "L6 local publish/reducer/query (pass --with-spacetime)"
  fi
else
  record SKIP "spacetime CLI not installed"
fi

# ---------------------------------------------------------------- security
step "Security and configuration checks"
cd "$ROOT"
if grep -rIEn "nvapi-|sk-[A-Za-z0-9]{20}|NVIDIA_API_KEY|SPECTRUM_PROJECT_SECRET|NIM_API_KEY" ios --include='*.swift' --include='*.plist' --include='*.xcconfig' --include='*.json' >/dev/null 2>&1; then
  record FAIL "S3 secret-like strings in ios/"
else
  record PASS "S3 no secrets or provider key names in ios/"
fi
ignored=1
for f in .env backend/.env agent/.env ios/Configuration/Local.xcconfig; do git check-ignore -q "$f" || { ignored=0; echo "not ignored: $f"; }; done
[ $ignored = 1 ] && record PASS "S4 .env / Local.xcconfig are gitignored" || record FAIL "S4 ignore rules"

# ---------------------------------------------------------------- summary
echo; echo "================ Module 0 integration summary ================"
printf '%s\n' "${RESULTS[@]}"
echo "logs: $WORK"
exit $FAILED
