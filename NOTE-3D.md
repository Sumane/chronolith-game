# NOTE — THE GAME IS 3D (GODOT)

**Decision recorded 2026-08-27 by Marc (verbal, overnight build session):**
> "this game is 3d"

## What this means for the repo

- The design documents previously said *Perspective: TBD (top-down or isometric
  recommended)*. That is now overridden: **CHRONOLITH is a 3D game built in Godot.**
- **Everything currently in `core/` and `modules/` is a 2D (Node2D) vertical-slice
  prototype.** It proves the gameplay systems (EventBus architecture, economy
  ledger, wave director, dilation bubble, rewind, meta progression) but the
  *presentation* — mars map, crystal, rover, buildings, enemies, camera — is all
  2D and must be rebuilt in 3D.
- The module architecture (one `_controller.gd` door per module, contracts in
  `core/contracts.gd`, JSON tuning in `data/`) is presentation-agnostic and is
  intended to **survive the conversion unchanged**. The conversion replaces the
  `internal/` visual layer of each module and the world-space representation
  (Vector2 → Vector3, Node2D trees → Node3D trees), not the event contract.

## Where things stand

- `core/contracts.gd` payloads use `{"x": float, "y": float}` position dicts.
  The 3D conversion needs a 3D position convention (see `docs/3D-CONVERSION.md`,
  proposal: add `z`, keep `x/y`, default `z=0` so all existing consumers keep
  working until each module is converted — a deliberate migration seam).
- `project.godot` is still 2D-flavoured (`window/stretch/mode="canvas_items"`,
  `gl_compatibility` renderer). Fine for the prototype; the 3D build will need
  the standard renderer (mobile: gl_compatibility) and `stretch/mode="viewport"`.

## Next major work item

**The 3D conversion** — staged plan, risks, and a proof-of-concept scene
suggestion live in `docs/3D-CONVERSION.md`. Read it before touching any
visual-layer code for 3D work.
