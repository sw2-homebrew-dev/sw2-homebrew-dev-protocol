# Fast cycles

The scarce resource is console sessions, not minutes. Every session someone
has to rebuild by hand costs everyone who shares that console.

## Answer on the PC what the PC can answer

- **Mock backend.** `SW2_MOCK=1 scripts/sw2-cycle.sh` exercises package
  loading, the host lifecycle, the save block and the services mailbox
  without a console.
- **Preview frames.** sw2-sdk renders the UI with real Vulkan (lavapipe), so
  check layout there before spending a launch on it.
- **Script the state machine.** Compile the app's logic for the PC with stub
  input, as sw2-store's `tests/store_harness.c` does, and assert the
  results.
- **Fake the remote side with a file.** For anything that talks to a remote
  service, point it at a local file. For example, the store reads
  `SW2_CATALOG_URL=file://.../index.json`.

## Make each launch count

- **Give the app a bounded run.** A test build should finish by itself: set
  `limits.frames` in the manifest, or return after a scripted sequence. Then
  the cycle never needs the watchdog.
- **Make the build say what it is.** Set `SW2_LABEL` when freezing, show it
  in the app, and log it at start. Two builds with the same version can't be
  told apart otherwise.
- **Log checkpoints** with `hbx_log` at each stage the criterion needs. The
  ring buffer is collected into `result.json` even when the run fails.
- **One question per cycle.** If a run answers two questions, neither answer
  can be trusted.

## Between cycles

- Run the next cycle in the same session only if the previous one ended
  cleanly (`app-ok` or `failed` with the host exiting normally).
- After `inconclusive` or `transport-failure`, restart the session and run
  the known-good control first.
