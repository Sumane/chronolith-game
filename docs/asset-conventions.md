# CHRONOLITH v1 — Asset Conventions (M1)

Rules that let Marc's production models drop in without code changes.

## Common conventions

- 1 unit = 1 metre. Up = +Y. Forward = -Z (Godot standard).
- Entity origin sits at **ground contact** (chassis bottom / plinth bottom),
  so `position.y` is the terrain height, not the visual centre.
- Controller identity, HP, collision and sockets **never** depend on the mesh
  hierarchy. Every blockout visual lives under a `Visual` node that can be
  deleted and replaced with a model of any structure, as long as the socket
  nodes below are kept.

## Rover (PlayerRig > Rover > Visual)

| Item | Blockout value | Contract |
|---|---|---|
| Chassis | 1.6 w × 0.7 h × 2.2 l m, origin at bottom | keep footprint for collision (1.5×2.1 m box) |
| Turret pivot | `Visual/Turret` at (0, 0.85, -0.2) | named node; aim `look_at` target every frame |
| Muzzle socket | `Visual/Turret/Muzzle` (0.45 m ahead of turret centre) | named node; projectile/beam origin |
| Camera target | rig point +1.3 m above rover origin, rover kept lower-centre via look-at bias | fixed contract — camera code does not read the visual |
| Wheels | 4 cylinders at ±0.85 x, ±0.8 z | purely visual, no collision |

## Chronolith crystal (Arena > Chronolith)

2.8 m prism (1.5 m base) on a 1.4 m plinth; origin at plinth base; sphere
collision r=1.8 m at +1.8 m y (shots land on the crystal). Glow via emissive
material + point light — replace light with real bloom later.

## Target dummy (Arena > Target1/2/3)

0.8 × 1.6 × 0.8 m box, origin at base. `damageable` group + `damage(int)`
method is the damage contract. Respawn after 5 s when destroyed.

## Rocks / terrain

Terrain = 41×41 m heightmap, 1 m grid, flat buildable pad (d < 6 m) at centre,
rolling dunes beyond, west slope ridge. Rocks are spheres 1.1–1.8 m; all on
default collision layer (block rover, bullets, camera).

## Asset manifest (for Marc, M1 scope)

1. Rover chassis + turret model (sockets: Turret pivot, Muzzle)
2. Turret barrel + muzzle-flash FX
3. Chronolith crystal (2.8 m, replace `PrismMesh`)
4. Target dummy (any damageable prop works)
5. Rock mesh (replace sphere visual; collision can stay spherical)
6. Tracer/beam FX (replace the cylinder beam)

Nothing here blocks a milestone: "missing final art" is not a blocker —
blockouts stay until the models arrive.
