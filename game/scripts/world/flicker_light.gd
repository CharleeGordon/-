extends Light3D
## Subtle (or not so subtle) light flicker. Also handles "flicker bursts" requested by the game.

@export var strength := 0.15
@export var speed := 6.0

var _base := 1.0
var _t := 0.0
var _burst := 0.0


func _ready() -> void:
	_base = light_energy
	_t = randf() * 100.0
	add_to_group("flicker_lights")


func burst(duration: float = 1.5) -> void:
	_burst = duration


func _process(delta: float) -> void:
	_t += delta * speed
	var n := sin(_t) * 0.5 + sin(_t * 2.7 + 1.3) * 0.3 + sin(_t * 7.1) * 0.2
	var e := _base * (1.0 - strength * (0.5 + 0.5 * n))
	if _burst > 0.0:
		_burst -= delta
		if randf() < 0.3:
			e *= randf_range(0.0, 0.4)
	light_energy = e
