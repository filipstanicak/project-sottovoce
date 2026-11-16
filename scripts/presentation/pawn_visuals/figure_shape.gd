## **THE PROPORTIONS OF ONE KIND OF FIGURE.** ART_BIBLE §1.1, US-0109. CLIENT ONLY.
##
## Four personas, five filler archetypes and the undressed figure, each as a
## handful of numbers a skeleton is built from. **A shape belongs to a persona,
## never to a body**: every Lucerna in the district is built from the one row
## below, which is what makes a clone identical to a player rather than similar
## (ART_BIBLE §2, GDD-03 §6.3 rule 6).
##
## The four personas keep the silhouette claims of §1.1: the Vetraio broad at the
## shoulder, the Cantatrice widest at the floor, the Lucerna tall and narrow under
## a pole, the Pesatore even and round. The fillers are shapes no player can be
## (§1.3) — a child, above all, so the eye checks size before it checks shape.
class_name FigureShape
extends RefCounted

## The height the proportions below were drawn at.
const REFERENCE_HEIGHT := 1.75
## Half the shoulder width of an unremarkable adult, before `shoulders`.
const SHOULDER_HALF := 0.19
const FOOT_HEIGHT := 0.07

## `[height, shoulders, girth, stoop]` for each of the five fillers.
const FILLERS := {
	&"ARCH-CHILD": [1.22, 0.9, 1.0, 0.0],
	&"ARCH-FISHWIFE": [1.62, 0.95, 1.1, 0.0],
	&"ARCH-MENDICANT": [1.66, 0.9, 0.9, 0.3],
	&"ARCH-PORTER": [1.82, 1.15, 1.1, 0.12],
	&"ARCH-WATERCARRIER": [1.7, 1.0, 0.95, 0.0],
}
## How deep each persona's trunk is. **Height and width are not here**: they are
## `PersonaData.stand_height` and `width_scale`, authored once in
## `data/personas/*.tres`, and a second copy is a number that drifts.
const GIRTH := {
	&"PERSONA-VETRAIO": 1.1,
	&"PERSONA-CANTATRICE": 0.9,
	&"PERSONA-LUCERNA": 0.85,
	&"PERSONA-PESATORE": 1.3,
}
const PERSONA_DATA := "res://data/personas/%s.tres"

static var _authored: Dictionary = {}

var id: StringName = &""
var height := 1.8
## Shoulder width, as a share of an unremarkable adult's.
var shoulders := 1.0
## How deep the trunk is, front to back.
var girth := 1.0
## How far the figure is bent at the waist, always.
var stoop := 0.0


## The shape `id` is built in; the undressed figure, `height` tall, for any other.
static func of(id: StringName, height: float) -> FigureShape:
	var shape := FigureShape.new()
	shape.height = height
	var data := persona_data(id)
	if data != null:
		shape.id = id
		shape.height = data.stand_height
		shape.shoulders = data.width_scale
		shape.girth = GIRTH[id]
	elif FILLERS.has(id):
		var row: Array = FILLERS[id]
		shape.id = id
		shape.height = row[0]
		shape.shoulders = row[1]
		shape.girth = row[2]
		shape.stoop = row[3]
	return shape


## What `data/personas/` says of persona `id`, or null for anything else.
static func persona_data(id: StringName) -> PersonaData:
	if not GIRTH.has(id):
		return null
	if not _authored.has(id):
		var slug := String(id).trim_prefix("PERSONA-").to_lower()
		_authored[id] = load(PERSONA_DATA % slug) as PersonaData
	return _authored[id]


## An arm that carries something and so does not swing: `side` 0 left, 1 right.
func holds(side: int) -> bool:
	if side == 1:
		return id == Ids.PERSONA_LUCERNA
	return id == Ids.PERSONA_PESATORE or id == Ids.ARCH_FISHWIFE


## Everything that is a length of limb scales with this.
func scale() -> float:
	return height / REFERENCE_HEIGHT


func hip_y() -> float:
	return height * 0.5


func knee_y() -> float:
	return height * 0.27


func shoulder_y() -> float:
	return height * 0.8


func head_radius() -> float:
	return 0.11 * clampf(scale(), 0.8, 1.05)


## The centre of the head: its crown is the figure's height.
func head_y() -> float:
	return height - head_radius() * 1.1


func shoulder_half() -> float:
	return SHOULDER_HALF * shoulders * clampf(scale(), 0.6, 1.05)


func hip_half() -> float:
	return 0.085 * minf(shoulders, 1.15) * clampf(scale(), 0.6, 1.05)


## How deep the trunk is, front to back, at its middle.
func depth() -> float:
	return 0.115 * girth * clampf(scale(), 0.6, 1.05)


func upper_arm() -> float:
	return height * 0.17


func forearm() -> float:
	return height * 0.15


func thigh() -> float:
	return hip_y() - knee_y()


func shin() -> float:
	return knee_y() - FOOT_HEIGHT
