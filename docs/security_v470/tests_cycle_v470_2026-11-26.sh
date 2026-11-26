#!/usr/bin/env bash
# دورة v470 الكاملة على قاعدة اختبار فقط. التشغيل من جذر المستودع:
#   TEST_DB='<رابط قاعدة الاختبار>' docs/security_v470/tests_cycle_v470_2026-11-26.sh
# الشاشة: أسماء الاختبارات PASS/FAIL وأكواد SQLSTATE فقط. السجل الكامل (قد يحوي نصوص أخطاء) يُحفظ خارج المستودع في
#   ${V470_LOG_DIR:-$HOME/.v470-test-logs}
set -euo pipefail
: "${TEST_DB:?اضبط TEST_DB برابط قاعدة الاختبار (ليست الإنتاج)}"
case "$TEST_DB" in *xehjwzszhsaqdqmcatum*) echo "REFUSED prod-ref"; exit 2;; esac
D="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="${V470_LOG_DIR:-$HOME/.v470-test-logs}"; mkdir -p "$LOG_DIR"; LOG="$LOG_DIR/cycle_$(date +%Y%m%d_%H%M%S).log"
case "$LOG_DIR" in "$(cd "$D/../.." && pwd)"*) echo "REFUSED log-dir-inside-repo"; exit 2;; esac
P=(psql "$TEST_DB" -X -q -v ON_ERROR_STOP=1 -v keep_verbosity=1 -v VERBOSITY=verbose)
show(){ grep -oE '(PASS|FAIL) [^:]*$|ERROR: +[0-9A-Z]{5}' | sed -E 's/ERROR: +/ERROR /' || true; }
step(){ echo "== $1"; echo "== $1" >>"$LOG"; }
run(){ "${P[@]}" "$@" >>"$LOG" 2>&1; }
runshow(){ local rc=0; "${P[@]}" "$@" 2>&1 | tee -a "$LOG" | show; rc=${PIPESTATUS[0]}; return $rc; }
q(){ "${P[@]}" -At -c "$1" 2>>"$LOG"; }
die(){ echo "FAIL $1"; exit 1; }

step "marker";    [ "$(q "select to_regclass('v470_test_marker.marker') is not null")" = t ] || die "no-test-marker"
step "sentinel";  SENT=$(q "insert into public.audit_log(actor_role, action, entity_type, entity_id) values ('admin','v470_cycle_sentinel','test','v470') returning id" | head -1)
[[ "$SENT" =~ ^[0-9]+$ ]] || die "sentinel-insert"
snap(){ "${P[@]}" -f "$D/snapshot_v470.sql" 2>>"$LOG" | grep -E '^[a-z_]+=' ; }
post_rollback_checks(){
  [ "$(q "select to_regclass('private.v470_backup') is null")" = t ] || die "backup-table-still-present"
  [ "$(q "select count(*) from public.audit_log where action='v470_close_roleless_access'")" = 0 ] || die "apply-audit-row-still-present"
  [ "$(q "select count(*) from public.audit_log where id=$SENT and action='v470_cycle_sentinel'")" = 1 ] || die "sentinel-row-affected"
  [ "$(snap)" = "$SNAP0" ] || die "definitions-or-fingerprints-differ-after-rollback"
  echo "PASS post-rollback: backup absent, apply row removed, sentinel intact, definitions+grants+owners+rows identical"
}
rows(){ grep '^rows_'; }

step "snapshot before"; SNAP0="$(snap)"; [ -n "$SNAP0" ] || die "snapshot"
step "tests before";    runshow -v phase=before -f "$D/tests_v470_2026-11-26.sql"
step "apply";           runshow -f "$D/v470_close_roleless_access_2026-11-26.sql"
step "apply again (expect V4701 only)"
OUT=$("${P[@]}" -f "$D/v470_close_roleless_access_2026-11-26.sql" 2>&1 || true); echo "$OUT" >>"$LOG"
CODES=$(echo "$OUT" | grep -oE 'ERROR: +[0-9A-Z]{5}' | sed -E 's/ERROR: +//' | sort -u | tr '\n' ' ')
[ "$CODES" = "V4701 " ] && echo "PASS apply-twice rejected with V4701" || die "apply-twice codes=[${CODES}]"
step "tests after";     runshow -v phase=after -f "$D/tests_v470_2026-11-26.sql"
step "fingerprints authorized roles unchanged by apply"
[ "$(snap | rows)" = "$(echo "$SNAP0" | rows)" ] && echo "PASS rows+lookup for admin/coordinator/supervisor/senior_teacher identical" || die "authorized-fingerprints-changed"
step "rollback";        runshow -f "$D/rollback_v470_close_roleless_access_2026-11-26.sql"; post_rollback_checks
step "tests before (restored)"; runshow -v phase=before -f "$D/tests_v470_2026-11-26.sql"
step "apply #2";        runshow -f "$D/v470_close_roleless_access_2026-11-26.sql"
step "tests after #2";  runshow -v phase=after -f "$D/tests_v470_2026-11-26.sql"
step "rollback #2";     runshow -f "$D/rollback_v470_close_roleless_access_2026-11-26.sql"; post_rollback_checks
step "cleanup sentinel"; [ "$(q "with d as (delete from public.audit_log where id=$SENT and action='v470_cycle_sentinel' returning 1) select count(*) from d")" = 1 ] || die "sentinel-cleanup"
echo "CYCLE PASS (log: $LOG)"
