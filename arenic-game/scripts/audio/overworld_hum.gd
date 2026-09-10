class_name ArenicOverworldHum
extends RefCounted
## Generate a small, exactly periodic PCM loop once. No per-frame synthesis or
## recorded asset: the same AudioStreamWAV works in native and Web stream mixers.
const MIX_RATE: int = 11025
const LOOP_SECONDS: float = 8.0
static var _cached: AudioStreamWAV

static func stream() -> AudioStreamWAV:
	if _cached != null:
		return _cached
	var frames: int = int(MIX_RATE * LOOP_SECONDS)
	var pcm := PackedByteArray()
	pcm.resize(frames * 2)
	for frame in frames:
		var t: float = float(frame) / MIX_RATE
		var breath: float = 0.78 + 0.12 * sin(TAU * t / LOOP_SECONDS)
		var tone: float = sin(TAU * 110.0 * t) * 0.50
		tone += sin(TAU * 165.0 * t + 0.35 * sin(TAU * t / LOOP_SECONDS)) * 0.20
		tone += sin(TAU * 220.125 * t) * 0.09
		pcm.encode_s16(frame * 2, int(tone * breath * 32767.0))
	_cached = AudioStreamWAV.new()
	_cached.format = AudioStreamWAV.FORMAT_16_BITS
	_cached.mix_rate = MIX_RATE
	_cached.stereo = false
	_cached.data = pcm
	_cached.loop_mode = AudioStreamWAV.LOOP_FORWARD
	_cached.loop_begin = 0
	_cached.loop_end = frames
	return _cached
