# results/

Each cycle saves its evidence here as `<UTC time>-<app id>/`. The folder is
ignored by Git: link to it from your project's plan instead of committing it.

| File | Contents |
| --- | --- |
| `result.json` | candidate, hashes, SDK commit, host exit, app status, suggested classification |
| `cycle.log` | everything the cycle and the host printed |
| `session.jsonl` | this cycle's slice of the host's structured session log |
| `preflight.json` | the checks run before anything touched the console |
| `saves/` | the app's save file after the run, if it has one |
