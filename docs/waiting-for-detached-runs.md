# Waiting for a detached run (from an agent's shell)

Long `codex exec` runs outlive an agent's tool timeout, so they get launched detached and waited on. Three common ways to wait are broken.

## 1. `pgrep -f "<command text>"` never finishes

```bash
while pgrep -f "codex exec --model gpt-6-astra" >/dev/null; do sleep 10; done   # never exits
```

The loop runs inside a shell whose own command line contains that string, so `pgrep` matches the waiting shell itself. Never wait on the command text.

## 2. A bare `setsid` pid is dead immediately

```bash
setsid nohup codex exec ... </dev/null >run.log 2>&1 &
echo $! > run.pid
kill -0 "$(cat run.pid)" && echo RUNNING || echo DONE      # says DONE at once
```

Agent shells often run with job control on (`set -m`; check `echo $-` for an `m`). A backgrounded job then leads its own process group, and `setsid` forks when it's a group leader. `$!` is the pid of the `setsid` that already exited, not of codex. Under a plain `bash -c` the same code works.

**Fix:** `setsid -w` waits for its child, so `$!` stays alive exactly as long as the run.

## 3. Polling file size says "done" too early

Tools that write output at the end (`codex exec -o`, most wrappers) leave the file at 0 bytes for the whole run. A "stopped growing" check reports done immediately.

## What works

**Exit file (preferred).** The detached shell writes its own completion signal:

```bash
setsid nohup bash -c 'codex exec ... -o out.md "$PROMPT" </dev/null >run.log 2>&1; echo "exit=$?" > run.exit' </dev/null >/dev/null 2>&1 &
until [ -f run.exit ]; do sleep 10; done; cat run.exit out.md
```

**pid, done right.** Use `setsid -w`, in the same shell call as the `&`:

```bash
setsid -w nohup codex exec ... </dev/null >run.log 2>&1 &
echo $! > run.pid
kill -0 "$(cat run.pid)" 2>/dev/null && echo RUNNING || echo DONE
```

Also:
- **Always `</dev/null`.** `codex exec` reads stdin when it isn't a TTY, and an inherited pipe hangs the run until the timeout.
- **Keep each wait under the tool timeout** (e.g. 9 minutes), then return "still running" and call again. `codex-conference.sh wait` does this: exit 0 = done, exit 3 = call again.
