extends Node
## Effetti sonori semplici (sintetizzati).

var _players: Array = []
var _streams := {}
var volume_db := -6.0
var enabled := true

func _ready() -> void:
	for n in ["coin", "gavel", "dice", "drum", "card", "bell"]:
		_streams[n] = load("res://assets/sfx/%s.wav" % n)
	for i in 6:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)

func play(name: String, vol := 0.0, pitch := 1.0) -> void:
	if not enabled or not _streams.has(name):
		return
	for p in _players:
		if not p.playing:
			p.stream = _streams[name]
			p.volume_db = volume_db + vol
			p.pitch_scale = pitch
			p.play()
			return
