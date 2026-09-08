# Chronolith — Start Here

7 September 2026 · Replacement design pack v1.0

## Reading order

1. `chronolith-gdd.md` — player experience, story, persistence, wave gates and ending.
2. `chronolith-architecture.md` — ownership, 3D migration, pause, transactions and saves.
3. `chronolith-agent-tasks.md` — sequential playable milestones for Qwen.

These replace the earlier three documents. Latest decisions are incorporated: third-person 3D; the fixed crystal prison; shard-linked Vael; wave-earned engrams; complete planning pause; multiple capability barriers; at least five attempts; limited nukes; alternative research routes and deliberate overlevelling; mandatory warrior mech; one definitive ending; optional endless play.

The numbers in the illustrative gate table are not a validated final economy. Its arithmetic assumes two nukes and no alternate bypass. Actual costs, alternate routes, research respec and mech timing require simulation and playtesting. The GDD marks locked requirements, tuning proposals and deferred features separately.

Validation performed for this pack: an exhaustive reachable-state check of that simplified model, including voluntary early resets and nuke placements, produced cumulative maxima of 5, 14, 27 and 44 engrams after four attempts, with victory first possible on attempt five. This confirms only the reference arithmetic; no Godot build or real gameplay balance was tested.

No game code has been changed or audited. Existing prototype assets and rules may be reusable, but a 3D implementation requires real movement, collision, navigation, aiming and camera work. Reference-image filenames identify Marc's supplied artwork; the images are not included in this text archive.

## First assignment for Qwen

**Asset ownership:** Marc will supply final 3D assets in a later version. Use simple primitive models/blockouts now; do not spend time creating detailed finished models. Build replaceable visual components and document required dimensions, sockets and animations so supplied assets can be integrated later without rewriting gameplay.

Read the three documents and local repository instructions. Complete M0, then work on M1: preserve the current prototype, create an isolated 3D entry scene, and establish third-person rover driving, orbit camera and manual aiming on a small rough arena. Report verified reuse choices and the exact launch procedure. Show the result before expanding into the full gameplay systems.

Do not begin by building every module or the complete research tree. Do not ask Marc to implement Core or perform routine integration. Keep a short progress file so later tasks can continue without rereading the whole repository.

## Still to be tuned or authored

Blueprint graph and individual prices; capability/enemy combinations; resource rates; nuke availability; handling/camera values; mech silhouette and weapons; final dialogue/choreography; performance budgets. These are implementation/playtest work, not missing direction that blocks the first milestone.
