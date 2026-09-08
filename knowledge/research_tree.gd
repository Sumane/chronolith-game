class_name ResearchTree
extends RefCounted
## M3/M6: deterministic research tree. Engrams are the meta currency;
## effects apply to newly built/spawned physical gear (and the next
## attempt's body). M6: five lines, 14 nodes, total depth 45 engrams
## (= the wave-16 barrier threshold: a full catalog spend runs out
## exactly when the deepest barrier hits).

const NODES := {
	# TURRET line — automated defence (depth 14)
	"t1": {
		"name": "Hornet Rounds", "line": "TURRET", "cost": 1, "req": [],
		"effect": {"turret_damage": 5}, "desc": "Turret shots deal +5 damage",
	},
	"t2": {
		"name": "Twin Links", "line": "TURRET", "cost": 2, "req": ["t1"],
		"effect": {"turret_cooldown": 0.3}, "desc": "Turret cooldown -0.3 s",
	},
	"t3": {
		"name": "Rail Coils", "line": "TURRET", "cost": 4, "req": ["t2"],
		"effect": {"turret_range": 4.0}, "desc": "Turret range +4 m",
	},
	"t4": {
		"name": "Twin Phase Cartridge", "line": "TURRET", "cost": 7, "req": ["t3"],
		"effect": {"turret_damage": 10, "turret_split": 0.5},
		"desc": "Turret damage +10, cooldown halved (late-wave pressure)",
	},
	# FORT line — structures and the crystal (depth 9)
	"f1": {
		"name": "Reinforced Plating", "line": "FORT", "cost": 1, "req": [],
		"effect": {"wall_hp": 30}, "desc": "Walls built with +30 max hp",
	},
	"f2": {
		"name": "Auto-Welder", "line": "FORT", "cost": 3, "req": ["f1"],
		"effect": {"wall_repair": 2.0}, "desc": "Buildings self-repair 2 hp/s",
	},
	"f3": {
		"name": "Aegis Membrane", "line": "FORT", "cost": 5, "req": ["f2"],
		"effect": {"crystal_shield": 25.0}, "desc": "Crystal starts with +25 integrity",
	},
	# ROVER line — mobile counter (depth 13)
	"r1": {
		"name": "Heavy Chassis", "line": "ROVER", "cost": 1, "req": [],
		"effect": {"rover_hp": 50}, "desc": "Rover starts with +50 hp",
	},
	"r2": {
		"name": "Ion Coils", "line": "ROVER", "cost": 2, "req": ["r1"],
		"effect": {"rover_speed": 1.5}, "desc": "Rover speed +1.5 m/s",
	},
	"r3": {
		"name": "Ram Capacitor", "line": "ROVER", "cost": 4, "req": ["r2"],
		"effect": {"ram_recharge": 1.0}, "desc": "Ram cooldown -1.0 s (floor 1.0 s)",
	},
	"r4": {
		"name": "Mag Coil", "line": "ROVER", "cost": 6, "req": ["r3"],
		"effect": {"harvest_range": 1.5}, "desc": "Harvest/repair radius +1.5 m",
	},
	# TEMPORAL line — time control (depth 6)
	"x1": {
		"name": "Stasis Burst", "line": "TEMPORAL", "cost": 2, "req": [],
		"effect": {"time_factor": 0.7}, "desc": "C: enemies 30% slower for 2.5 s (12 s recharge)",
	},
	"x2": {
		"name": "Deep Stasis", "line": "TEMPORAL", "cost": 4, "req": ["x1"],
		"effect": {"time_factor": 0.5}, "desc": "Stasis deepens: 50% slower for 5 s (10 s recharge)",
	},
	# MECH line — the Hybrid payoff (depth 3)
	"mech": {
		"name": "Hybrid Chassis", "line": "MECH", "cost": 3, "req": ["r2"],
		"effect": {"mech_unlock": 1}, "desc": "Unlocks the Hybrid Mech (T: build, 8 scrap)",
	},
}

# Grouped by line so the research UI can page 7 / 7.
const ORDER := [
	"t1", "t2", "t3", "t4", "f1", "f2", "f3",
	"r1", "r2", "r3", "r4", "x1", "x2", "mech",
]
