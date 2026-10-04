extends AudioStreamPlayer3D
## Looping positional ambience (clock ticking, dripping, radio...). Starts at a random offset.

func _ready() -> void:
	if stream is AudioStreamWAV:
		var wav: AudioStreamWAV = stream.duplicate()
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(wav.get_length() * wav.mix_rate)
		stream = wav
	elif stream is AudioStreamOggVorbis:
		var ogg: AudioStreamOggVorbis = stream.duplicate()
		ogg.loop = true
		stream = ogg
	play(randf() * maxf(stream.get_length() - 0.1, 0.0))
