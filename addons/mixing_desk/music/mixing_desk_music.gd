extends Node

var tempo
var bars
var beats_in_bar
var transition_beats
var loop
var can_shuffle = true

export(int) var play_mode = 1

onready var songs = get_children()

const default_vol = -10

var players = []
var time = 0.0
var beat = 1.0
var bar = 1.0
var beats_in_sec = 0.0
var can_beat = true
var can_bar = true
var playing = false
var current_song_num = 0
var current_song
var beat_tran = false
var bar_tran = false
var old_song
var new_song = 0
var repeats = 0

signal beat
signal bar
signal end
signal shuffle
signal song_changed

func _ready():
	var shuff = Timer.new()
	shuff.name = 'shuffle_timer'
	add_child(shuff)
	shuff.connect("timeout", self, "_shuffle_songs")
	for track in songs:
		for i in track.get_children():
			if i.name == 'core':
				for o in i.get_children():
					var tween = Tween.new()
					tween.name = 'Tween'
					o.add_child(tween)
				
#loads a song and gets ready to play
func _init_song(track):
	var song = songs[track]
	var root = song.get_node("core")
	current_song_num = track
	current_song = songs[track].get_node("core")
	var inum = 0
	repeats= 0
	for i in root.get_children():
		var bus = AudioServer.get_bus_count()
		AudioServer.add_bus(bus)
		AudioServer.set_bus_name(bus,"layer" + str(inum))
		AudioServer.set_bus_send(bus, "Music")
		if song.fading_out:
			i.get_child(0).stop(i)
			song.fading_out = false
			i.set_volume_db(default_vol)
		i.set_bus("layer" + str(inum))
		players.append(i)
		inum += 1
	root.get_child(0).connect("finished", self, "_song_finished")
	tempo = song.tempo
	bars = song.bars
	loop = song.loop
	beats_in_bar = song.beats_in_bar
	beats_in_sec = 60000.0/tempo
	transition_beats = (beats_in_sec*song.transition_beats)/1000

#unloads a song
func _clear_song(track):
	players.clear()
	print('clearing song "' + str(songs[track].name) + '"')
	var song = songs[track].get_node("core")
	var inum = 0
	for i in song.get_children():
		var bus = AudioServer.get_bus_index("layer" + str(inum))
		AudioServer.remove_bus(bus)
	song.get_child(0).disconnect("finished", self, "_song_finished")
		
#updates place in song and detects beats/bars
func _process(delta):
	if playing:
		time = current_song.get_child(0).get_playback_position()
		beat = ((time/beats_in_sec) * 1000.0) + 1.0
		bar = beat/beats_in_bar + 0.75
		if fmod(beat, 1.0) < 0.1:
			if fmod(bar, 1.0) < 0.24:
				bar = floor(bar)
				_bar()
			_beat()
			beat = floor(beat)

#start a song with only one track playing
func _start_alone(track, layer):
	current_song_num = track
	current_song = songs[track].get_node("core")
	for i in current_song.get_children():
		i.set_volume_db(-60.0)
	current_song.get_child(layer).set_volume_db(default_vol)
	_play(track)

func _iplay(track):
	var trk = track.duplicate()
	track.add_child(trk)
	trk.play()
	yield(trk, "finished")
	trk.queue_free()

#play a song
func _play(track):
	time = 0
	if !playing:
		playing = true
	for i in songs[track].get_children():
		if i.name == 'core':
			print('playing song "' + str(songs[track].name) + '"')
			for o in i.get_children():
				o.play()
		if 'ran' in i.name:
			randomize()
			var rantrk = floor(rand_range(0, i.get_child_count() + songs[track].random_padding))
			if rantrk <= i.get_child_count() - 1:
				i.get_child(rantrk).play(0.0)
		if 'seq' in i.name:
			var seqtrk = repeats
			if repeats == i.get_child_count():
				seqtrk = 0
				repeats = 0
			i.get_child(seqtrk).play()
	if bar_tran:
		bar_tran = false
	else:
		_bar()
	if beat_tran:
		beat_tran = false
	else:
		_beat()

#mute all layers above specified layer, and fade in all below
func _mute_above_layer(track, layer):
	if songs[track].get_node("core").get_child_count() < 2:
		return
	for i in range(0, layer + 1):
		_fade_in(track, i)
		print('fading in song ' + str(track) + ', track ' + str(i))
	for i in range(layer + 1, songs[track].get_node("core").get_child_count()):
		_fade_out(track, i)

#mute all layers below specified layer, and fade in all below
#use _mute_below_layer(0) to fade all tracks in
func _mute_below_layer(track, layer):
	for i in range(layer, songs[track].get_node("core").get_child_count()):
        _fade_in(track, i)
	if layer > 0:
		for i in range(0, layer - 1):
    	    _fade_out(track, i)
		if layer == 1:
			_fade_out(track, 0)
			
#mute all layers aside from specified layer
func _solo(track, layer):
	for i in range(layer + 1, songs[track].get_node("core").get_child_count()):
        _fade_out(track, i)
	if layer > 0:
		for i in range(0, layer - 1):
    	    _fade_out(track, i)
		if layer == 1:
			_fade_out(track, 0)

#mute only the specified layer
func _mute(track, layer):
	songs[track].get_node("core").get_child(layer).set_volume_db(-60.0)

#unmute only the specified layer
func _unmute(track, layer):
	songs[track].get_node("core").get_child(layer).set_volume_db(default_vol)

#slowly bring in the specified layer
func _fade_in(track, layer):
	var target = songs[track].get_node("core").get_child(layer)
	var tween = target.get_node("Tween")
	var in_from = target.get_volume_db()
	tween.interpolate_property(target, 'volume_db', in_from, default_vol, transition_beats, Tween.TRANS_QUAD, Tween.EASE_OUT)
	tween.start()

#slowly take out the specified layer
func _fade_out(track, layer):
	var target = songs[track].get_node("core").get_child(layer)
	var tween = target.get_node("Tween")
	var in_from = target.get_volume_db()
	tween.interpolate_property(target, 'volume_db', in_from, -60.0, transition_beats, Tween.TRANS_SINE, Tween.EASE_OUT)
	tween.start()

#change to the specified song at the next bar
func _queue_bar_transition(song):
	old_song = current_song_num
	songs[old_song].fading_out = true
	new_song = song
	bar_tran = true
	
	
	
#change to the specified song at the next beat
func _queue_beat_transition(song):
	old_song = current_song_num
	songs[old_song].fading_out = true
	new_song = song
	beat_tran = true
	
func _change_song(song):
	_clear_song(old_song)
	_init_song(song)
	for i in songs[old_song].get_children():
		if i.name == 'core':
			if transition_beats >= 1:
				for o in i.get_child_count():
					_fade_out(old_song, o)
			else:
				_mute(old_song, i)
				yield(get_tree(), "idle_frame")
				songs[old_song].get_node("core").get_child(0).get_child(0).emit_signal('tween_completed')
				songs[old_song].fading_out = false
		if 'ran' in i.name:
			for o in i.get_children():
				o.stop()
		if 'seq' in i.name:
			for o in i.get_children():
				o.stop()
	_play(song)


#stops playing
func _stop(track):
	if playing:
		playing = false
		for i in songs[track].get_children():
			for o in i.get_children():
				o.stop()
	_clear_song(current_song_num)

#called every bar
func _bar():
	if can_bar:
		can_bar = false
		emit_signal("bar")
		
		if bar_tran:
			if current_song_num != new_song:
				_change_song(new_song)
				emit_signal("song_changed")
				yield(songs[old_song].get_node("core").get_child(0).get_child(0), 'tween_completed')
			#print('clearing song "' + str(songs[old_song].name) + '"')
			
		
		#at end of song
		if bar >= bars + 1:
			if play_mode == 1 and loop:
				#print('Restarting music...')
				_play(current_song_num)
				repeats += 1
				bar = 0
			emit_signal("end")
		yield(get_tree().create_timer(0.5), "timeout")
		can_bar = true
	
#called every beat
func _beat():
	if can_beat:
		if beat_tran:
			if current_song_num != new_song:
				_change_song(new_song)
				emit_signal("song_changed")
				yield(songs[old_song].get_node("core").get_child(0).get_child(0), 'tween_completed')
		can_beat = false
		emit_signal("beat")
		yield(get_tree(), "idle_frame")
		can_beat = true
	
#choose new song randomly
func _shuffle_songs():
	if playing:
		_stop(current_song)
	_clear_song(current_song_num)
	randomize()
	var song = randi() % (songs.size() - 1)
	_init_song(song)
	_play(song)
	emit_signal("shuffle")
	can_shuffle = true

func _song_finished():
	if play_mode == 2 and can_shuffle:
		$shuffle_timer.start(rand_range(0,2))
		can_shuffle = false


