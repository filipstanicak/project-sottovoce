extends RefCounted


static func roster() -> Array[Dictionary]:
	var players: Array[Dictionary] = []
	for actor: int in range(1, 7):
		(
			players
			. append(
				{
					"id": actor,
					"name": "Player %d" % actor,
					"placement": actor,
					"persona": Ids.PERSONA_VETRAIO,
					"abilities": [Ids.ABIL_CINDERFALL, Ids.ABIL_LUNGE],
					"passive": Ids.PASV_STILLNESS,
					"anonymous_seconds": 360.0 - actor * 10.0,
				}
			)
		)
	return players


static func event(
	id: int, actor: int, kind: StringName, points: float, group: int = 0
) -> ScoreEvent:
	return ScoreEvent.new(id, ScoreAward.new(10, kind, actor, 2, points), Tuning.match_rules, group)
