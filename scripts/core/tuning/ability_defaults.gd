## The per-ability values. GENERATED FROM TUNABLES.md section 8.
##
## **`AbilityData` IS ONE CLASS FOR FOUR ABILITIES**, so a class default cannot
## carry a per-ability value: `duration` is 6 s of smoke for Cinderfall and 15 s of
## a false face for Second Face. Every other section's `.tres` is written from its
## own class's defaults, and this is where the ability writer reads its own.
##
## **IT REPLACES A HAND-WRITTEN TABLE OF 45 NUMBERS** inside
## `tools/generate_default_tuning.gd`, which had drifted far enough that running
## the documented command reverted `TUN-CINDERFALL-THROW-RANGE` to its
## pre-ADR-0013 value and dropped `TUN-CINDERFALL-DURATION` entirely (2026-09-04).
##
## BUILD-TIME ONLY. Nothing in a running game reads this: the shipped values come
## from the `.tres` files it is used to write.
class_name AbilityDefaults

const VALUES := {
	"cinderfall":
	{
		"cooldown": 45.0,
		"cast_time": 0.45,
		"throw_range": 0.0,
		"radius": 5.0,
		"duration": 6.0,
		"blocks_los": true,
		"blocks_kill": true,
		"suspicion_cost": 40.0,
		"startle_radius": 9.0,
		"tell_audio_radius": 25.0
	},
	"lunge":
	{
		"cooldown": 30.0,
		"distance": 6.0,
		"speed": 9.0,
		"windup": 0.25,
		"stunnable_during": true,
		"suspicion_cost": 40.0,
		"auto_kill": true,
		"whiff_stagger": 1.2,
		"startle_radius": 7.0,
		"tell_audio_radius": 20.0
	},
	"secondface":
	{
		"cooldown": 60.0,
		"cast_time": 0.8,
		"duration": 15.0,
		"break_speed": 6.2,
		"break_on_hit": true,
		"break_on_kill": true,
		"suspicion_cost": 10.0,
		"persona_source": &"nearest_clone",
		"break_tell_duration": 0.6,
		"tell_audio_radius": 8.0
	},
	"whisperbolt":
	{
		"cooldown": 40.0,
		"windup": 1.0,
		"range_min": 3.0,
		"range_max": 12.0,
		"projectile_speed": 22.0,
		"forces_exposed": true,
		"exposed_tail": 1.5,
		"suspicion_on_miss": 30.0,
		"requires_los": true,
		"tell_audio_radius": 30.0
	},
}
