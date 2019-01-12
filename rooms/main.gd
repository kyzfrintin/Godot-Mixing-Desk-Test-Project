extends Node2D

onready var mdm = get_node("MDM")
onready var point = get_node("point")

var colour : int = 0

func _ready():
	mdm._init_song(0)
	mdm._start_alone(0,0)
	mdm._bind_to_param(0,-10)
	
func _process(delta):
	var dis = $player.position.distance_to(point.position)
	dis /= 1000
	if dis < 1:
		mdm._feed_param(0,(dis*-1) + 1)
	
