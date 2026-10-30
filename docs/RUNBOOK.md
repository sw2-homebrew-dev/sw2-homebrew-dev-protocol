# Runbook: one case

## 1. Define the case

Write these down before any console work:

- the goal (`G#`) and an acceptance criterion you can observe;
- the **one** thing that changed, and a known-good control (for example
  `hello-cpu` from sw2-sdk);
- console firmware, SmileBASIC edition, session host (Linux ns2jb or
  macOS mac2jb, and which host profile), the build toolchain (`gnu` or
  `llvm`, shown by `sw2 doctor`), and the stop condition;
- the source commit and the SDK commit.

Never mix changes to the app, the SDK or host, and the session in one
experiment.

## 2. Finish offline first

- Build and test on the PC: `sw2 build`, the project's unit tests, and
  `sh tests/run.sh` in sw2-sdk when the SDK changed.
- For native apps, run the same cycle against the mock backend:
  `SW2_MOCK=1 scripts/sw2-cycle.sh <candidate>`. This proves the package
  loads, the host lifecycle completes and the app returns. For screens, use
  `build/preview/hbl-preview` to render frames.
- Commit, then freeze: `scripts/sw2-freeze.sh <built-app> <candidate>`. Any
  rebuild, edit or repack is a new candidate.
- Copy the **whole candidate folder** to the console machine. Never rebuild
  there.

## 3. Run one console cycle

`scripts/sw2-cycle.sh <candidate>` does all of these steps:

1. **Lock.** On a shared console, the lock is created atomically with a token.
   If it's taken, the script waits 15 s and tries again. It never decides on
   its own that a lock is stale. On a dedicated console, set
   `SW2_DEDICATED=1` and write that down in `.local/ENVIRONMENT.md`.
2. **Verify.** Every file is checked against `SHA256SUMS`. If any byte
   changed, it stops.
3. **Preflight.** `hbl-start --preflight` must pass, and the session must be
   a verified 4/4. Without one it records `no-run`. Set up a session by hand
   ([SESSION.md](SESSION.md)). Don't loop on this step.
4. **Stage.** A private apps folder for this cycle holds only the candidate,
   so nothing else can launch and your `apps/` folder stays untouched.
5. **Launch once.** `hbl-start --app <id>` maps the app, enters it, and
   unmaps it when it returns. The app's manifest `limits.frames` bounds the
   run, and the watchdog (`SW2_SECONDS`) is only a backstop.
6. **Collect.** The script saves this cycle's slice of the session log, the
   app's log ring, the save file and the host exit status.
7. **Unlock.** The script removes the lock only if it still holds our token.

If the watchdog fires, the console thread may still be running. Restart
SmileBASIC and the session before the next cycle.

## 4. Classify and record

The script's `suggested` value covers execution only:

| Suggested | Meaning | You record |
| --- | --- | --- |
| `app-ok` | the app ran and returned `HBX_OK` | `pass` or `partial-pass`, judged against the criterion |
| `failed` | the app returned an error, or launch failed after entry | `failed` |
| `inconclusive` | the watchdog fired, or no status was recorded | `inconclusive` |
| `transport-failure` | the host never entered the app | `transport-failure` |
| `no-run` | blocked before the console (preflight, session, lock) | `no-run` |

Things the script can't see, such as what was on screen, sound, feel and
motion, need a person. Write down what they should check and what each
outcome means.

Record one line per milestone, about 200 characters at most. `result.json`
contains a draft:

```text
- YYYY-MM-DD | G# | commit | id@version | classification: highest stage | evidence path | next action
```

Keep raw logs in `results/`. Never paste them into plans or chat; quote
only a short, app-specific excerpt.

## 5. Continue

- Retry the same bytes **once**, and only after a proven transport problem.
- Never chain unattended cycles. Check that the session is healthy between
  runs, and stop at the first anomaly.
- If the environment is in doubt, run the known-good control before blaming
  the candidate.
