# CHRONOLITH — Progress (keep this file short)

## Current milestone

**M0 — Preserve and inspect: DONE (2026-09-07, branch `v1`).** Next: **M1 —
Establish the intended game view.**

## M0 acceptance (verified)

- [x] 2D prototype preserved and recoverable: untouched on branch `main`
      (last commit `7bf3557`); full suite re-run on `v1` HEAD: **71/71, exit 0**.
- [x] Working branch `v1` created from `main`; design pack v1.0 + 5 reference
      images committed (`ff22210`).
- [x] 3D entry exists and launches a real 3D world: `res://scenes/poc/poc.tscn`
      (Stage-0 tilt scene — drivable rover, crystal, trooper; headless probe
      `POC_SECONDS=5` exits 0). M1 builds the proper third-person entry under
      `scenes/v1/` and supersedes it.
- [x] Engine pinned locally: Godot **4.7.1.stable.official.a13da4feb**
      (`~/.bin/godot`); renderer `mobile` (desktop) / `gl_compatibility` (mobile).
- [x] Reuse assessment: `docs/migration-note.md` (keep / adapt / replace, with
      the legacy-save and reference-image-label notes).
- [x] Exact launch procedure: `docs/migration-note.md` §Launch (user + sandbox
      variants, one-godot-at-a-time rule).

## Launch the current 3D playable

```bash
cd /home/marc/AI/Chronolith-Game
godot --path . res://scenes/poc/poc.tscn   # WASD drives the rover (Stage-0 tilt)
```

## Known limitations

- POC movement mapping is inverted vs the camera view and the camera is fixed —
  both are M1 acceptance items (chase camera that follows the rover, correct
  WASD-to-view mapping, mouse orbit + aim, gamepad left/right stick).
- No enemies, research, build UI, saves or waves in 3D yet (M1 scope ends at
  driving/aiming/pause).
- v1 economy numbers are unvalidated; `data/*.json` values are v0 tuning only.

## Exact next task (M1, from chronolith-agent-tasks.md)

One small 3D arena with slopes, rocks, a fixed crystal and rover placeholder;
forgiving WASD vehicle control; mouse orbit/aim; camera obstruction handling;
one manually fired weapon that hits 3D targets and respects weapon
obstruction; basic pause + input contexts; placeholder visual separated from
controller/collision with scale/orientation/attachment conventions documented.
Show a screenshot/recording and get Marc's camera/feel feedback before the
presentation is treated as settled. Exclude: enemy roster, research,
procedural maps, final graphics.

## Changed files (this milestone)

- `chronolith-v1/*` (design pack v1.0, committed `ff22210`)
- `reference images/*` (Marc's art, committed `ff22210`)
- `docs/migration-note.md`, `docs/progress.md` (this file)
