# LEAK HUNT — status (updated 2026-08-29 ~11:00)

## Verdict so far
- The game itself does NOT leak. Idle game (main.tscn as main scene, 120s) and
  the mem_probe (dynamic boot + 35s active run + 45s HUB idle) are FLAT at ~110-118MB.
- The SMOKE TEST process leaks ~370MB/s, linearly, until the process ends
  (plateau = test quit or timeout kill).
- Leak exists WITHOUT CHRONOLOG (bus logger ruled out; logger now capped at 500 lines anyway).
- Leak exists with pre-boot script/JSON loads skipped (SMOKE_SKIP=compile,json ruled those out).
- Leak A (probe + steps 4-8: economy test, spawnwait loop, combat kill, rewind,
  chronolith kill + HUB wait) reproduces it.
- LEAK A also froze: after rewind + chronolith kill, the main loop stopped firing
  physics frames (HUB-wait loop never progressed; 3s process_always timer never fired)
  while RAM kept growing. Ramp onset (t≈4-5s) ≈ the RESET→HUB transition time (t≈4.8s).

## Ruled out (all read & bounded)
- All 15 _process/_physics_process callbacks: main, waves, enemy, chronolith, crystal,
  rover, rover_body, build, building, hud, input_forwarder, mars_map, audio, economy.
- All while loops in game code (enemy history, chronolith buffer, rover harvest/rewind
  buffer, waves spawn, hud toasts) — all bounded.
- contracts.gd, event_bus.gd, bus_logger.gd, game_state.gd, hub_screen.gd, meta,
  economy, build, ui, waves, chronolith, rover controllers — all event handlers bounded.
- Godot binary: official 4.7.1 stable, no ASAN/valgrind.
- CHRONOLOG bus logger (capped now), pre-boot loads, preload constants,
  two-process sampling artifact (only in the B arm; A data is valid).

## Open question
What in the test process (not the game) drives a ~370MB/s allocation once
~4-5s after process start, and (in A) freezes the main loop at the RESET→HUB
phase transition?

## Running now
tests/leak_matrix.gd — 4 arms, 40s each, sequential (ONE godot at a time),
boot+run+skip-calm common base + exactly ONE mechanic:
  1. LEAK_ARM=spawnwait  → spawn-wait while-loop w/ alive_count() per frame
  2. LEAK_ARM=kill       → one laser kill (rover_fired 9999)
  3. LEAK_ARM=rewind     → one rewind activation
  4. LEAK_ARM=killhub    → chronolith kill + HUB-wait while-loop
Results: .rss-matrix-<arm>, .log-matrix-<arm>. Watcher: job bash-1.

## Reading the results
- Arm ramps → that mechanic (or its combo with the run) is the trigger → subdivide.
- All flat → the trigger is in something still shared (game-boot-under-test-root?
  the await pattern? something at ~t=4-5s wall clock) → next: run leak_matrix with
  NO game booted at all (just the awaits) to test the test-harness itself.

## Process rules (learned the hard way)
- NEVER run two godot processes at once (killed a session: A-tail + B overlapped ~40GB).
- Keep each leak-prone run ≤ ~60s (≤ ~22GB). Session survived single runs to ~24GB.
- Always: detached (setsid nohup), RSS→workspace file every 2s, logs→workspace file,
  pgrep -x godot, one watcher job for completion.
- The 11GB llama-server (PID from /home/marc/Downloads/run.sh) + godot + Chrome is the
  real budget: 30GB RAM + 8GB swap. One heavy process at a time.
