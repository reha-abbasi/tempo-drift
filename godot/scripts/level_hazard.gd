@tool
extends Node3D
class_name LevelHazard
## A vehicle or roadblock in a level scene, placed where it meets the car: its lane and height are where it sits,
## its timing is how far down the street it is (traffic drives on, so in play it comes from further back).
## The look is its child, the city's own vehicle for this kind.

## what it is: oldcar, dbus, biplane, taxi, truck, bus, hovercab, drone or barrier
@export var kind := "oldcar"
## a roadblock to hop over, or to fly under
@export var over := false
@export var under := false
