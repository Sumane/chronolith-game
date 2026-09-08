class_name MechData
extends RefCounted
## M5: shared Hybrid Mech parameters (game + progression model mirror).
## Blockout stats — the real tuning pass is the M5 scenario playtest.

const BUILD_COST := 8   # scrap consumed to construct (shared with model)
const MAX_HP := 250
const SPEED := 6.5      # slower than the rover, more presence
const ARMOR := 3        # flat mitigation on all hits
const GUN_DMG := 40     # heavy round, piercing (bypasses armor)
const GUN_CD := 0.5
const CAM_DIST := 5.0   # closer, tighter third-person framing
