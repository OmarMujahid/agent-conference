#!/usr/bin/env bash
# Run Codex participants of an agent conference detached, and wait on them safely.
# Usage:
#   codex-conference.sh launch -d DIR -r ROLE -p PROMPT_FILE -o OUT_FILE [-m MODEL] [-e EFFORT] [-C REPO]
#   codex-conference.sh wait   -d DIR [-t SECONDS]   exit 0 = all done, 3 = still running (call again)
#   codex-conference.sh status -d DIR
# The participant's final message is written to OUT_FILE (read-only sandbox, it never writes files itself).
# Run state lives in DIR/.runs/<role>.{log,exit}; the .exit file is the done signal.
set -uo pipefail

CMD="${1:-}"; shift || true
DIR=""; ROLE=""; PROMPT_FILE=""; OUT=""; MODEL="gpt-6-sol"; EFFORT="high"; REPO="$PWD"; WAIT_SECS=540
while getopts "d:r:p:o:m:e:C:t:" opt; do
  case "$opt" in
    d) DIR="$OPTARG" ;; r) ROLE="$OPTARG" ;; p) PROMPT_FILE="$OPTARG" ;; o) OUT="$OPTARG" ;;
    m) MODEL="$OPTARG" ;; e) EFFORT="$OPTARG" ;; C) REPO="$OPTARG" ;; t) WAIT_SECS="$OPTARG" ;;
    *) sed -n '2,9p' "$0" >&2; exit 2 ;;
  esac
done
[ -z "$DIR" ] && { sed -n '2,9p' "$0" >&2; exit 2; }
DIR="$(cd "$DIR" && pwd)" || exit 2
RUNS="$DIR/.runs"; mkdir -p "$RUNS"

status() {
  local pending=0 f role
  for f in "$RUNS"/*.started; do
    [ -e "$f" ] || { echo "no runs in $RUNS"; return 0; }
    role="$(basename "$f" .started)"
    if [ -f "$RUNS/$role.exit" ]; then
      echo "$role: DONE $(cat "$RUNS/$role.exit") -> $(cat "$f")"
    else
      pending=$((pending + 1))
      echo "$role: RUNNING since $(date -r "$f" +%H:%M) -> $(cat "$f")"
    fi
  done
  return $pending
}

case "$CMD" in
  launch)
    [ -z "$ROLE" ] || [ -z "$PROMPT_FILE" ] || [ -z "$OUT" ] && { sed -n '2,9p' "$0" >&2; exit 2; }
    [ -f "$PROMPT_FILE" ] || { echo "error: no prompt file $PROMPT_FILE" >&2; exit 2; }
    case "$OUT" in /*) ;; *) OUT="$DIR/$OUT" ;; esac
    [ -f "$RUNS/$ROLE.started" ] && [ ! -f "$RUNS/$ROLE.exit" ] && { echo "error: $ROLE is still running" >&2; exit 1; }
    rm -f "$RUNS/$ROLE.exit"
    echo "$OUT" > "$RUNS/$ROLE.started"
    PROMPT="$(cat "$PROMPT_FILE")

Output rule: you are in a read-only sandbox. Do not try to write files. Your final message IS the document; it is saved verbatim to $(basename "$OUT")."
    # The exit line is written by the detached shell itself, so waiting never depends on a pid or pgrep.
    setsid nohup bash -c '
      timeout "${CONF_TIMEOUT:-3600}" codex exec --model "$1" -c model_reasoning_effort="$2" \
        --sandbox read-only --cd "$3" --skip-git-repo-check --color never --ephemeral \
        -o "$4" "$5" </dev/null >"$6.log" 2>&1
      rc=$?
      [ -s "$4" ] || [ "$rc" -ne 0 ] || rc=1
      echo "exit=$rc" > "$6.exit"
    ' _ "$MODEL" "$EFFORT" "$REPO" "$OUT" "$PROMPT" "$RUNS/$ROLE" </dev/null >/dev/null 2>&1 &
    echo "launched $ROLE ($MODEL, $EFFORT) -> $OUT"
    ;;
  wait)
    end=$((SECONDS + WAIT_SECS))
    while :; do
      status >/dev/null && { status; exit 0; }
      [ $SECONDS -ge $end ] && { status; echo "still running; call wait again"; exit 3; }
      sleep 15
    done
    ;;
  status) status; exit 0 ;;
  *) sed -n '2,9p' "$0" >&2; exit 2 ;;
esac
