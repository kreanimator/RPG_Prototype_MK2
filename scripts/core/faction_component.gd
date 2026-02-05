extends Node
class_name FactionComponent

enum Faction { PLAYER, TOWN, RAIDERS, MUTANTS, ANIMALS, NONE }
enum Disposition { FRIENDLY, NEUTRAL, HOSTILE }

@export var faction: Faction = Faction.NONE

var reputation: Dictionary = {} # faction_id -> int (-100..100)


func get_disposition_to(other: FactionComponent) -> Disposition:
	if other == null:
		return Disposition.NEUTRAL

	# same faction
	if faction == other.faction and faction != Faction.NONE:
		return Disposition.FRIENDLY

	var rep := int(reputation.get(other.faction, 0))

	if rep >= 30:
		return Disposition.FRIENDLY
	if rep <= -30:
		return Disposition.HOSTILE

	return Disposition.NEUTRAL
	
