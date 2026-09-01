## One ability's authored data. DATA_SCHEMA §4.1.
##
## A SINGLE class holding the union of every ability's fields, as the schema
## specifies with its "Whisperbolt only" / "Second Face" annotations. An ability
## leaves the fields it does not use at zero — four subclasses would make the
## `abilities` dictionary untypeable for the sake of a few unused floats.
##
## THE TELL FIELDS ARE NOT DECORATION. Design law 3: no ability resolves without
## the victim having had a perceivable chance to read it, and two tell channels
## are the minimum with at least one environmental or audio. That is asserted by
## test_ability_has_tell.gd against this resource, not left to review.
class_name AbilityData
extends Resource

## ABIL-*. Immutable once merged.
@export var id: StringName = &""

## Key into data/strings/en.csv. Never a user-facing literal.
@export var display_key: StringName = &""

## SFX-* played on cast. Tell channel 1 of 3.
@export var tell_sfx: StringName = &""

## extends AbilityEffect. The only per-ability code there is.
@export var effect_script: Script = null

## Tell channel 3. Arrives with the VFX pass.
@export var tell_vfx: PackedScene = null

## Roughly once per 90-second hunt cycle. It is an escape, not a tool.
## Used by: Cinderfall, Lunge, Secondface, Whisperbolt.
## TUN-CINDERFALL-COOLDOWN
@export_range(35.0, 60.0, 0.1) var cooldown: float = 0.0

## The wind-and-throw. Short enough to be a panic button, long enough to be a visible tell. Read
## for the first time at US-0067 — the pipeline began every effect on the press tick until then,
## so this value was an animation length and nothing else. It is now the gap between the tell
## going out and the cloud existing, which is the window design law 3 asks for. A caster killed
## during it drops no cloud; nothing else interrupts a cast.
## Used by: Cinderfall, Secondface.
## TUN-CINDERFALL-CAST-TIME
@export_range(0.3, 0.7, 0.01) var cast_time: float = 0.0

## You may place it ahead of you or at your feet. Placing it ahead is the aggressive use (deny a
## chaser's line); at your feet is the escape.
## Used by: Cinderfall.
## TUN-CINDERFALL-THROW-RANGE
@export_range(5.0, 12.0, 0.1) var throw_range: float = 0.0

## Twice TUN-KILL-RANGE. Covers a doorway or an alley mouth, not a plaza.
## Used by: Cinderfall.
## TUN-CINDERFALL-RADIUS
@export_range(4.0, 7.0, 0.1) var radius: float = 0.0

## Long enough to break a lock (TUN-COMPASS-LOCK-FILL-TIME is 1.6 s) and leave; short enough that
## it cannot be used to camp a corner.
## Used by: Cinderfall, Secondface.
## TUN-CINDERFALL-DURATION
@export_range(3.0, 6.0, 0.1) var duration: float = 0.0

## Blocks line of sight for detection, Compass lock, and SCORE-FOCUS accumulation.
## Used by: Cinderfall.
## TUN-CINDERFALL-BLOCKS-LOS
@export var blocks_los: bool = false

## No kill may be initiated inside the radius, by anyone, including the caster. A kill already in
## progress completes. Otherwise it becomes an offensive tool for forcing blind kills.
## Used by: Cinderfall.
## TUN-CINDERFALL-BLOCKS-KILL
@export var blocks_kill: bool = false

## Equals TUN-SUSPICION-GAIN-LOUD-ABILITY.
## Used by: Cinderfall, Lunge, Secondface.
## TUN-CINDERFALL-SUSPICION
@export var suspicion_cost: float = 0.0

## NPCs within this radius Startle. The cloud hides you and simultaneously paints a fleeing-crowd
## arrow at your position for everyone in the district. This is the ability's honest cost.
## Used by: Cinderfall, Lunge.
## TUN-CINDERFALL-STARTLE-RADIUS
@export_range(6.0, 14.0, 0.1) var startle_radius: float = 0.0

## The crack is audible this far. Promoted from prose in 04_abilities.md § Tell; the audio tell
## channel must be a tunable like every other number, because design law 3 is enforced by the
## schema.
## Used by: Cinderfall, Lunge, Secondface, Whisperbolt.
## TUN-CINDERFALL-TELL-AUDIO-RADIUS
@export_range(18.0, 35.0, 0.1) var tell_audio_radius: float = 0.0

## 2.4× TUN-KILL-RANGE. Closes the "they saw me and turned" gap and nothing more.
## Used by: Lunge.
## TUN-LUNGE-DISTANCE
@export_range(4.0, 8.0, 0.1) var distance: float = 0.0

## 0.67 s of travel. Faster than sprint, so it genuinely closes; slow enough that a prepared
## defender can stun it.
## Used by: Lunge.
## TUN-LUNGE-SPEED
@export_range(7.0, 12.0, 0.1) var speed: float = 0.0

## Short, but present, and audible. The tell.
## Used by: Lunge, Whisperbolt.
## TUN-LUNGE-WINDUP
@export_range(0.15, 0.4, 0.01) var windup: float = 0.0

## For the entire wind-up and dash. The dash is loud and telegraphed; it must lose to a prepared
## defender. This is TUN-STUN-VS-LUNGE-WINDOW.
## Used by: Lunge.
## TUN-LUNGE-STUNNABLE
@export var stunnable_during: bool = false

## If the dash ends within TUN-KILL-RANGE and cone of the contract, the kill auto-initiates. It
## is one button, not two, because it is the panic button.
## Used by: Lunge.
## TUN-LUNGE-AUTO-KILL
@export var auto_kill: bool = false

## Missing leaves you standing in the open, Noticed, unable to act.
## Used by: Lunge.
## TUN-LUNGE-WHIFF-STAGGER
@export_range(0.8, 2.0, 0.01) var whiff_stagger: float = 0.0

## Sprinting breaks it. Equals TUN-SPEED-SPRINT. You may run; you may not sprint.
## Used by: Secondface.
## TUN-SECONDFACE-BREAK-SPEED
@export var break_speed: float = 0.0

## Any stun, stagger or kill-attempt against you breaks it.
## Used by: Secondface.
## TUN-SECONDFACE-BREAK-ON-HIT
@export var break_on_hit: bool = false

## Breaks after the kill resolves, so SCORE-MASKED still applies. You get paid for the disguised
## kill, and then everyone sees who you are.
## Used by: Secondface.
## TUN-SECONDFACE-BREAK-ON-KILL
@export var break_on_kill: bool = false

## You adopt the persona of the nearest visible NPC clone, not a free choice. Ties the ability to
## reading the crowd, which is why it exists. Falls back to a random other persona if no clone is
## visible.
## Used by: Secondface.
## TUN-SECONDFACE-PERSONA-SOURCE
@export var persona_source: StringName = &""

## The un-morph is as visible as the morph. Being unmasked in a crowd is an event other players
## can see.
## Used by: Secondface.
## TUN-SECONDFACE-BREAK-TELL-DURATION
@export_range(0.4, 1.0, 0.01) var break_tell_duration: float = 0.0

## Just outside TUN-KILL-RANGE. You cannot use it as a free melee kill.
## Used by: Whisperbolt.
## TUN-WHISPERBOLT-RANGE-MIN
@export_range(2.5, 4.0, 0.01) var range_min: float = 0.0

## Long enough to reach a rooftop camper from the street below; short enough that it is not a
## sniping tool.
## Used by: Whisperbolt.
## TUN-WHISPERBOLT-RANGE-MAX
@export_range(9.0, 16.0, 0.1) var range_max: float = 0.0

## 0.55 s of flight at maximum range — the target has a real, if small, dodge window after
## release.
## Used by: Whisperbolt.
## TUN-WHISPERBOLT-PROJECTILE-SPEED
@export_range(16.0, 30.0, 0.1) var projectile_speed: float = 0.0

## For the full wind-up plus TUN-WHISPERBOLT-EXPOSED-TAIL. This is the tell.
## Used by: Whisperbolt.
## TUN-WHISPERBOLT-FORCES-EXPOSED
@export var forces_exposed: bool = false

## Exposed persists after release, hit or miss. You threw a knife in a market; people noticed.
## Used by: Whisperbolt.
## TUN-WHISPERBOLT-EXPOSED-TAIL
@export_range(1.0, 2.5, 0.01) var exposed_tail: float = 0.0

## Equals TUN-SUSPICION-GAIN-FAILED-KILL. A miss is a failed kill.
## Used by: Whisperbolt.
## TUN-WHISPERBOLT-SUSPICION-ON-MISS
@export var suspicion_on_miss: float = 0.0

## Server-validated at release and at impact against the lag-compensated world.
## Used by: Whisperbolt.
## TUN-WHISPERBOLT-REQUIRES-LOS
@export var requires_los: bool = false
