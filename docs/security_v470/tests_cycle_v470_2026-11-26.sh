#!/usr/bin/env bash
# دورة كاملة على قاعدة اختبار فقط: قبل ← تطبيق ← بعد ← رجوع ← قبل ← تطبيق ← بعد ← رجوع.
# كل خطوة تفشل السكربت فورًا عند أي خطأ. الاستعمال: TEST_DB='postgresql://...test...' ./tests_cycle_v470_2026-11-26.sh
set -euo pipefail
: "${TEST_DB:?اضبط TEST_DB برابط قاعدة الاختبار (ليست الإنتاج)}"
case "$TEST_DB" in *xehjwzszhsaqdqmcatum*) echo "رفض: هذا رابط الإنتاج"; exit 2;; esac
D="$(cd "$(dirname "$0")" && pwd)"
run(){ PGOPTIONS="-c v470.i_am_test_db=yes" psql "$TEST_DB" -X -q -v ON_ERROR_STOP=1 "$@"; }
t(){ run -v phase="$1" -f "$D/tests_v470_2026-11-26.sql" 2>&1 | grep -E 'PASS|FAIL|ERROR' ; }
echo "== before";            t before
echo "== apply";             run -f "$D/v470_close_roleless_access_2026-11-26.sql"
echo "== apply again (must fail)"; if run -f "$D/v470_close_roleless_access_2026-11-26.sql" 2>/dev/null; then echo "FAIL: apply twice"; exit 1; else echo "PASS apply twice rejected"; fi
echo "== after";             t after
echo "== rollback";          run -f "$D/rollback_v470_close_roleless_access_2026-11-26.sql"
echo "== before (restored)"; t before
echo "== apply #2";          run -f "$D/v470_close_roleless_access_2026-11-26.sql"
echo "== after #2";          t after
echo "== rollback #2";       run -f "$D/rollback_v470_close_roleless_access_2026-11-26.sql"
echo "CYCLE PASS"
