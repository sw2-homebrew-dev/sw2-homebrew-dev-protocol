# sw2-homebrew-dev-protocol

A shared way of working for developers who test Switch 2 homebrew on real
consoles, plus the scripts that make each hardware run short, exact and
recorded. It works with [sw2-sdk](https://github.com/sw2-homebrew-dev/sw2-sdk) (HBLauncher base, native and
GPUBrew apps) on **Linux** and on **macOS through mac2jb**.

It gives you two things:

- **A protocol.** Change one thing, freeze the exact bytes, run one bounded
  console cycle, and record one classified result that points to its evidence.
- **Automation.** `sw2-freeze.sh` and `sw2-cycle.sh` lock a shared console,
  check the bytes, preflight the session, launch the app once, collect the
  host and app logs, and suggest a classification. Nobody needs to touch a
  controller to launch anything.

## Why it is simpler than on other consoles

On this platform the **PC is the host**. Apps live on the PC. The host maps
an app into the SmileBASIC process, waits for it to return, and unmaps it.
There is no install step, no title registration, and no kill payload.
"Deploy" means pointing the host at a folder. "Close" means the app returns,
because its frame budget ran out or the user pressed B. The cost to keep down
is **sessions**: when a session goes wrong, someone has to restart SmileBASIC
and redo the 4/4 setup by hand.

## Quick start

```sh
# on any machine that builds (Linux, or macOS with Homebrew LLVM)
sw2 build apps/my-app
SW2_SDK=~/sw2-sdk SW2_LABEL="pr-12 menu fix" \
  scripts/sw2-freeze.sh apps/my-app ~/candidates/menu-fix-1

# offline first: the same cycle against the mock backend (native apps)
SW2_SDK=~/sw2-sdk SW2_MOCK=1 scripts/sw2-cycle.sh ~/candidates/menu-fix-1

# on the machine next to the console, with a verified 4/4 session
export SW2_SDK=~/sw2-sdk            # checkout, or an unpacked `sw2 host-bundle`
export SW2_LOCK=/shared/sw2-console-a   # or SW2_DEDICATED=1
export SW2_RUN=/path/to/held/run    # macOS: mac2jb's run folder; Linux: optional
scripts/sw2-cycle.sh ~/candidates/menu-fix-1
```

Each cycle writes `results/<time>-<id>/` (see [results/README.md](results/README.md)),
prints a suggested classification, and exits 0 only when the app returned
`HBX_OK`. It never retries.

## The protocol in brief

1. **Plan.** Keep numbered, measurable goals (`G1`, `G2`, …) in the project's
   own repository ([template](docs/PLAN_TEMPLATE.md)).
2. **Finish offline first.** Do builds, unit tests, the mock run and preview
   frames on the PC, and commit the exact candidate.
3. **Run one bounded cycle.** Lock, verify, preflight, launch once, collect,
   unlock ([runbook](docs/RUNBOOK.md)).
4. **Classify and record** with exactly one of `pass`, `partial-pass`,
   `failed`, `inconclusive`, `transport-failure`, `no-run`, written as a
   one-line milestone that points to the evidence.

## Safety

- Block system updates (90DNS) before connecting a console. Never open
  Settings, and never accept an update.
- Use only sessions the console's owner started. Never send mac2jb's remove
  twice in one SmileBASIC session.
- A session that stops answering ends the work. Restart SmileBASIC (or the
  console) and set up a new session. **Don't retry into a broken session.**
- On a shared console, hold the lock for one cycle only, and never remove
  someone else's lock.
- After a crash or a hang, keep the evidence and analyze it offline.

## Layout

| Path | |
| --- | --- |
| [docs/RUNBOOK.md](docs/RUNBOOK.md) | the procedure for one case |
| [docs/SESSION.md](docs/SESSION.md) | setting up a 4/4 session on Linux and macOS (mac2jb) |
| [docs/FAST_CYCLES.md](docs/FAST_CYCLES.md) | getting the most from each session |
| [docs/PLAN_TEMPLATE.md](docs/PLAN_TEMPLATE.md), [docs/HANDOFF_TEMPLATE.md](docs/HANDOFF_TEMPLATE.md) | project plan and handoff |
| `scripts/sw2-freeze.sh` | freeze a built app as a candidate |
| `scripts/sw2-cycle.sh` | one bounded cycle |
| `scripts/sw2-result.cjs` | writes `result.json` and the suggested classification |
| [AGENTS.md](AGENTS.md) | rules for coding agents |

## License

MIT. The PS5 protocol this is modelled on is GPL-3.0. No text or code is
shared with it: the procedure was rewritten for this platform and the scripts
are new.
