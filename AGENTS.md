# Agent instructions

- Read `README.md` and `docs/RUNBOOK.md`, plus the project's plan and handoff.
  Open the other docs only when the task needs them.
- Use one cycle per question: `scripts/sw2-freeze.sh`, then
  `scripts/sw2-cycle.sh`. Run the cycle as a single command, in the
  background, and read its output when it ends.
- Never rebuild a candidate folder, and never edit files inside one.
- Never set up, restart or end a console session yourself. A missing 4/4
  session is a `no-run`; hand it to a person.
- Never retry after `inconclusive` or `transport-failure`. Report it and stop.
- Hold the lock only during a cycle, and never remove a lock you don't own.
- Keep raw logs in `results/`. Quote short, app-specific excerpts only.
- Record one milestone line per result.
- For anything a run can't verify (what was on screen, sound, feel), hand it
  to a person with the steps to check and what each outcome means.
- Never commit hosts, addresses, personal paths or raw evidence.
