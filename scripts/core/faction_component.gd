extends Node
class_name FactionComponent

enum Faction { PLAYER, TOWN, RAIDERS, MUTANTS, ANIMALS, NONE }
enum Disposition { FRIENDLY, NEUTRAL, HOSTILE }

@export var faction: Faction = Faction.NONE

# faction_id -> int (-100..100)
var reputation: Dictionary = {}


# Base relations between factions (default behavior)
const BASE_RELATIONS := {
	Faction.MUTANTS: {
		Faction.PLAYER: Disposition.HOSTILE,
		Faction.TOWN: Disposition.HOSTILE,
		Faction.RAIDERS: Disposition.HOSTILE,
		Faction.ANIMALS: Disposition.HOSTILE,
		Faction.MUTANTS: Disposition.FRIENDLY,
	},
	Faction.RAIDERS: {
		Faction.PLAYER: Disposition.HOSTILE,
		Faction.TOWN: Disposition.HOSTILE,
		Faction.MUTANTS: Disposition.HOSTILE,
		Faction.ANIMALS: Disposition.NEUTRAL,
		Faction.RAIDERS: Disposition.FRIENDLY,
	},
	Faction.ANIMALS: {
		Faction.PLAYER: Disposition.HOSTILE,
		Faction.TOWN: Disposition.HOSTILE,
		Faction.RAIDERS: Disposition.HOSTILE,
		Faction.MUTANTS: Disposition.HOSTILE,
		Faction.ANIMALS: Disposition.FRIENDLY,
	},
	Faction.TOWN: {
		Faction.PLAYER: Disposition.FRIENDLY,
		Faction.RAIDERS: Disposition.HOSTILE,
		Faction.MUTANTS: Disposition.HOSTILE,
		Faction.ANIMALS: Disposition.HOSTILE,
		Faction.TOWN: Disposition.FRIENDLY,
	},
	Faction.PLAYER: {
		Faction.TOWN: Disposition.FRIENDLY,
		Faction.RAIDERS: Disposition.HOSTILE,
		Faction.MUTANTS: Disposition.HOSTILE,
		Faction.ANIMALS: Disposition.HOSTILE,
		Faction.PLAYER: Disposition.FRIENDLY,
	},
}


func get_disposition_to(other: FactionComponent) -> Disposition:
	if other == null:
		return Disposition.NEUTRAL

	# Same faction (except NONE)
	if faction == other.faction and faction != Faction.NONE:
		return Disposition.FRIENDLY

	# 1) Base faction rules
	var base := Disposition.NEUTRAL
	if BASE_RELATIONS.has(faction):
		base = BASE_RELATIONS[faction].get(other.faction, Disposition.NEUTRAL)

	# 2) Reputation overrides (if exists)
	if reputation.has(other.faction):
		var rep := int(reputation[other.faction])
		if rep >= 30:
			return Disposition.FRIENDLY
		if rep <= -30:
			return Disposition.HOSTILE

	return base
