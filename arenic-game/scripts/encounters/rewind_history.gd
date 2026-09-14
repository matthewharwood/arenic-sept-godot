class_name ArenicRewindHistory
extends RefCounted
## Transient sampled presentation, never an input/event replay or save format.
const SAMPLE_TICKS: int = 3 # 20 Hz on the authoritative 60 Hz clock.
const MAX_SAMPLES: int = 2401
const MAX_TRACKS: int = 329 + ArenicCombatPresentation.TRANSIENT_TRACKS + ArenicCombatPresentation.CASTER_LIMIT * ArenicCombatPresentation.CAST_EFFECT_SLOTS # Actors plus per-source transient and reserved cast slots.
const STRIDE: int = 15

class Frame:
	extends RefCounted
	var tick: int
	var serial: int
	var tracks: PackedInt32Array = []
	var generations: PackedInt64Array = []
	var textures: Array[Texture2D] = []
	var positions: PackedVector3Array = []
	# Euler rotation, scale, pixel size, offset, modulate RGBA, priority, flips.
	var attributes: PackedFloat32Array = []

var _frames: Array[Frame] = []
var _start: int = 0
var count: int = 0
var poses: int = 0

func _init() -> void:
	_frames.resize(MAX_SAMPLES)

func first() -> Frame:
	return at(0)

func last() -> Frame:
	return at(count - 1)

func at(index: int) -> Frame:
	return _frames[(_start + index) % MAX_SAMPLES] if index >= 0 and index < count else null

func append(frame: Frame) -> void:
	if count == MAX_SAMPLES:
		pop_first()
	_frames[(_start + count) % MAX_SAMPLES] = frame
	count += 1
	poses += frame.tracks.size()

func pop_first() -> void:
	if count == 0:
		return
	poses -= _frames[_start].tracks.size()
	_frames[_start] = null
	_start = (_start + 1) % MAX_SAMPLES
	count -= 1

func clear() -> void:
	while count > 0:
		pop_first()
	_start = 0

## Find the frame at or immediately before the requested sampled time.
func floor_index(tick: float) -> int:
	var lower: int = 0
	var upper: int = count - 1
	while lower <= upper:
		var middle: int = (lower + upper) >> 1
		if float(at(middle).tick) <= tick:
			lower = middle + 1
		else:
			upper = middle - 1
	return maxi(0, upper)
