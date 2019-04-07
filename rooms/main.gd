extends Node2D

onready var mdm = get_node("MDM")

var colour : int = 0

func _ready():
	mdm._init_song("orange")
	yield(get_tree().create_timer(2),"timeout")
	mdm._start_alone("orange","epiano")
	


func _on_MDM_beat(beat):
	print(beat)
	pass

func _on_MDM_bar(bar):
#	print('bar ' + str(bar))
	pass