class_name ResearchTree
extends RefCounted
## M3: small deterministic research tree (3 lines x 2 tiers). Engrams are the
## meta currency; effects apply to newly built/spawned physical gear.

const NODES := {
	"t1": {
		"name": "Hornet Rounds", "line": "TURRET", "cost": 1, "req": [],
		"effect": {"turret_damage": 5}, "desc": "Turret shots deal +5 damage",
	},
	"t2": {
		"name": "Twin Links", "line": "TURRET", "cost": 2, "req": ["t1"],
		"effect": {"turret_cooldown": 0.3}, "desc": "Turret cooldown -0.3 s",
	},
	"f1": {
		"name": "Reinforced Plating", "line": "FORT", "cost": 1, "req": [],
		"effect": {"wall_hp": 30}, "desc": "Walls built with +30 max hp",
	},
	"f2": {
		"name": "Auto-Welder", "line": "FORT", "cost": 2, "req": ["f1"],
		"effect": {"wall_repair": 2.0}, "desc": "Buildings self-repair 2 hp/s",
	},
	"r1": {
		"name": "Heavy Chassis", "line": "ROVER", "cost": 1, "req": [],
		"effect": {"rover_hp": 50}, "desc": "Rover starts with +50 hp",
	},
	"r2": {
		"name": "Ion Coils", "line": "ROVER", "cost": 2, "req": ["r1"],
		"effect": {"rover_speed": 1.5}, "desc": "Rover speed +1.5 m/s",
	},
}

const ORDER := ["t1", "t2", "f1", "f2", "r1", "r2"]
