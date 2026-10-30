#!/bin/sh
# One bounded console cycle for a frozen candidate:
#   lock -> verify bytes -> preflight -> stage -> launch once -> collect -> unlock
#
#   scripts/sw2-cycle.sh <candidate-dir>
#
# Environment
#   SW2_SDK        sw2-sdk checkout or unpacked host bundle (required)
#   SW2_RUN        held 4/4 run folder.  Linux: optional (newest ns2jb run is
#                  used).  macOS: the run folder mac2jb holds ("rpc already held").
#   SW2_LOCK       lock path shared by everyone using this console, or
#   SW2_DEDICATED  =1 when only you use the console (no lock)
#   SW2_SECONDS    watchdog for the whole launch (default 180).  The app's own
#                  manifest frame budget should end it first.
#   SW2_RESULTS    evidence root (default ./results)
#   SW2_MOCK       =1 runs against the mock backend: no console, no lock
#
# Exit: 0 when the app returned HBX_OK, 1 otherwise.  Never retries.
# POSIX sh; runs on Linux and macOS.
set -eu

say() { printf '%s %s\n' "$(date -u +%H:%M:%S)" "$*"; }
die() { say "STOP: $*"; exit 1; }
[ $# -eq 1 ] || { echo "usage: $0 <candidate-dir>" >&2; exit 2; }

CANDIDATE=$(cd "$1" && pwd)
SDK=${SW2_SDK:?set SW2_SDK to an sw2-sdk checkout or host bundle}
SDK=$(cd "$SDK" && pwd)
SECONDS_LIMIT=${SW2_SECONDS:-180}
MOCK=${SW2_MOCK:-0}
HERE=$(cd "$(dirname "$0")/.." && pwd)
RESULTS=${SW2_RESULTS:-$HERE/results}

[ -f "$CANDIDATE/CANDIDATE.json" ] && [ -f "$CANDIDATE/SHA256SUMS" ] ||
  die "$CANDIDATE is not a frozen candidate (scripts/sw2-freeze.sh)"
ID=$(node -e 'process.stdout.write(JSON.parse(require("fs").readFileSync(process.argv[1])).id)' "$CANDIDATE/CANDIDATE.json")
STAMP=$(date -u +%Y%m%dT%H%M%SZ)
EVIDENCE="$RESULTS/$STAMP-$ID"
mkdir -p "$EVIDENCE"
LOG="$EVIDENCE/cycle.log"
log() { say "$*" | tee -a "$LOG"; }

sha256() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$@"; else shasum -a 256 "$@"; fi
}

# --- 1. lock ---------------------------------------------------------------
LOCKDIR=""
TOKEN="$(hostname)-$$-$STAMP"
release() {
  if [ -n "$LOCKDIR" ] && [ "$(cat "$LOCKDIR/token" 2>/dev/null)" = "$TOKEN" ]; then
    rm -rf "$LOCKDIR"
    log "unlocked"
  fi
}
trap release EXIT
trap 'exit 130' INT TERM
if [ "$MOCK" = 1 ] || [ "${SW2_DEDICATED:-0}" = 1 ]; then
  log "lock: not needed ($([ "$MOCK" = 1 ] && echo mock || echo dedicated console))"
else
  [ -n "${SW2_LOCK:-}" ] || die "set SW2_LOCK (shared console) or SW2_DEDICATED=1"
  # mkdir is atomic on every local and network filesystem we care about.
  until mkdir "$SW2_LOCK.d" 2>/dev/null; do
    log "lock held by $(cat "$SW2_LOCK.d/token" 2>/dev/null || echo '?'); waiting 15 s (never assumed stale)"
    sleep 15
  done
  LOCKDIR="$SW2_LOCK.d"
  printf '%s\n' "$TOKEN" > "$LOCKDIR/token"
  log "locked $LOCKDIR"
fi

# --- 2. verify the frozen bytes ---------------------------------------------
(cd "$CANDIDATE" && while IFS= read -r line; do
  want=${line%% *}; file=${line#*  }
  [ -f "$file" ] || { echo "missing $file"; exit 1; }
  got=$(sha256 "$file"); got=${got%% *}
  [ "$got" = "$want" ] || { echo "changed $file"; exit 1; }
done < SHA256SUMS) >> "$LOG" 2>&1 || die "candidate no longer matches SHA256SUMS (see cycle.log)"
log "verified $(wc -l < "$CANDIDATE/SHA256SUMS" | tr -d ' ') files of $ID"

# --- 3. preflight ------------------------------------------------------------
HOST="$SDK/hbl-start"
RUN_ARGS=""
[ "$MOCK" = 1 ] && RUN_ARGS="--mock"
[ "$MOCK" != 1 ] && [ -n "${SW2_RUN:-}" ] && RUN_ARGS="--run $SW2_RUN"
# shellcheck disable=SC2086
if ! "$HOST" --preflight $RUN_ARGS > "$EVIDENCE/preflight.json" 2>>"$LOG"; then
  node "$HERE/scripts/sw2-result.cjs" "$EVIDENCE" "$CANDIDATE" no-run "preflight failed" "$SDK"
  die "preflight failed (preflight.json)"
fi
if [ "$MOCK" != 1 ]; then
  node -e '
const r = JSON.parse(require("fs").readFileSync(process.argv[1]));
const s = r.checks.find(c => c.name === "4/4 session");
if (!s || !s.ok) { console.error("no verified 4/4 session: " + (s ? s.detail : "unknown")); process.exit(1); }
' "$EVIDENCE/preflight.json" 2>>"$LOG" || {
    node "$HERE/scripts/sw2-result.cjs" "$EVIDENCE" "$CANDIDATE" no-run "no 4/4 session" "$SDK"
    die "no verified 4/4 session; establish one (docs/SESSION.md), do not retry blindly"
  }
fi
log "preflight ok"

# --- 4. stage ------------------------------------------------------------------
# A cycle-private apps folder holding only the candidate: nothing else can be
# launched, and the developer's apps/ is untouched.
mkdir -p "$EVIDENCE/apps"
cp -R "$CANDIDATE/$ID" "$EVIDENCE/apps/$ID"
SESSION_LOG="$SDK/build/hbl-session.log"
[ "$MOCK" = 1 ] && SESSION_LOG="$SDK/build/hbl-mock.log"
OFFSET=0
[ -f "$SESSION_LOG" ] && OFFSET=$(wc -c < "$SESSION_LOG" | tr -d ' ')

# --- 5. launch once ----------------------------------------------------------
if [ "$MOCK" = 1 ]; then
  set -- --mock --apps "$EVIDENCE/apps"
else
  set -- --apps "$EVIDENCE/apps" --app "$ID"
  [ -n "${SW2_RUN:-}" ] && set -- --run "$SW2_RUN" "$@"
fi
log "launch $ID (watchdog ${SECONDS_LIMIT}s): hbl-start $*"
STARTED=$(date +%s)
"$HOST" "$@" >> "$LOG" 2>&1 &
PID=$!
# The watchdog must not hold our stdout open, and must take its sleep with it
# when cancelled; otherwise a piped cycle waits out SW2_SECONDS after the end.
(
  trap 'kill "$nap" 2>/dev/null; exit 0' TERM
  sleep "$SECONDS_LIMIT" & nap=$!
  wait "$nap"
  kill -TERM "$PID" 2>/dev/null && echo timeout > "$EVIDENCE/.timeout"
) </dev/null >/dev/null 2>&1 &
WATCHDOG=$!
set +e
wait "$PID"; HOST_EXIT=$?
set -e
kill "$WATCHDOG" 2>/dev/null || true
ELAPSED=$(( $(date +%s) - STARTED ))
log "host exited $HOST_EXIT after ${ELAPSED}s"

# --- 6. collect ------------------------------------------------------------------
[ -f "$SESSION_LOG" ] && tail -c +"$((OFFSET + 1))" "$SESSION_LOG" > "$EVIDENCE/session.jsonl"
SAVES=${HBL_SAVES_DIR:-$SDK/saves}
if [ -f "$SAVES/$ID.sav" ]; then mkdir -p "$EVIDENCE/saves"; cp "$SAVES/$ID.sav" "$EVIDENCE/saves/"; fi
rm -rf "$EVIDENCE/apps"
TIMED_OUT=0; [ -f "$EVIDENCE/.timeout" ] && TIMED_OUT=1 && rm -f "$EVIDENCE/.timeout"

SW2_HOST_EXIT=$HOST_EXIT SW2_TIMED_OUT=$TIMED_OUT SW2_ELAPSED=$ELAPSED \
  node "$HERE/scripts/sw2-result.cjs" "$EVIDENCE" "$CANDIDATE" "" "" "$SDK"
CLASS=$(node -e 'process.stdout.write(JSON.parse(require("fs").readFileSync(process.argv[1])).suggested)' "$EVIDENCE/result.json")
log "suggested classification: $CLASS  (evidence: $EVIDENCE)"
if [ "$TIMED_OUT" = 1 ] && [ "$MOCK" != 1 ]; then
  log "the watchdog stopped the host; the console thread may still be running."
  log "restart SmileBASIC (and the session) before the next cycle. Do not retry."
fi
[ "$CLASS" = "app-ok" ]
