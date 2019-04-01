extends Node2D

onready var mdm = get_node("MDM")
onready var point = get_node("point")

var colour : int = 0

func _ready():
	mdm._init_song(0)
	mdm._start_alone(0,0)
	
