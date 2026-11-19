extends Node

# =====================================================
# AUDIO MANAGER — Full Procedural Audio System
# Backward-compatible: existing play() calls unchanged.
# Registered as Autoload "AudioManager".
# =====================================================

# ── Sound name constants ───────────────────────────────
const SND_LAND     = "land"
const SND_PERFECT  = "perfect"
const SND_COMBO    = "combo"
const SND_RECORD   = "record"
const SND_GAMEOVER = "gameover"
const SND_COIN     = "coin"
const SND_BUTTON   = "button"
const SND_PURCHASE = "purchase"
const SND_EQUIP    = "equip"
const SND_REWARD   = "reward"
const SND_PAUSE    = "pause"
const SND_ERROR    = "error"

const _SAMPLE_RATE = 22050
const _POOL_SIZE   = 6

var _sfx_streams: Dictionary = {}
var _sfx_pool: Array       = []   # Array of AudioStreamPlayer
var _pool_idx: int         = 0
var _music_player: AudioStreamPlayer = null
var _music_started: bool   = false


func _ready() -> void:
	_setup_buses()
	_setup_sfx_pool()
	_pre_generate_sfx()
	_setup_music()
	# Wire game events for automatic audio feedback
	GameEvents.platform_landed.connect(_on_platform_landed)
	GameEvents.coins_earned.connect(_on_coins_earned)
	GameEvents.run_started.connect(_on_run_started)
	GameEvents.run_completed.connect(_on_run_completed)


# =====================================================
# BUS SETUP
# =====================================================

func _setup_buses() -> void:
	# Idempotent — checks before adding
	if AudioServer.get_bus_index("Music") < 0:
		AudioServer.add_bus()
		var idx = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(idx, "Music")
		AudioServer.set_bus_send(idx, "Master")
		AudioServer.set_bus_volume_db(idx, linear_to_db(0.70))
	if AudioServer.get_bus_index("SFX") < 0:
		AudioServer.add_bus()
		var idx = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(idx, "SFX")
		AudioServer.set_bus_send(idx, "Master")
		AudioServer.set_bus_volume_db(idx, 0.0)


# =====================================================
# SFX POOL
# =====================================================

func _setup_sfx_pool() -> void:
	for i in _POOL_SIZE:
		var p = AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_sfx_pool.append(p)


func _play_sfx_stream(stream: AudioStreamWAV) -> void:
	if stream == null: return
	var p: AudioStreamPlayer = _sfx_pool[_pool_idx]
	_pool_idx = (_pool_idx + 1) % _POOL_SIZE
	p.stream = stream
	p.play()


# =====================================================
# PUBLIC API
# =====================================================

func play(sound_name: String) -> void:
	if _sfx_streams.has(sound_name):
		_play_sfx_stream(_sfx_streams[sound_name])


func play_music() -> void:
	if _music_player and _music_player.stream:
		if not _music_player.playing:
			_music_player.play()
		_music_started = true


func stop_music() -> void:
	if _music_player:
		_music_player.stop()


func fade_music(duration: float = 0.4) -> void:
	if not _music_player: return
	var tween = create_tween()
	tween.tween_property(_music_player, "volume_db", -80.0, duration)
	await tween.finished
	_music_player.stop()
	_music_player.volume_db = 0.0


func set_music_volume(vol_linear: float) -> void:
	var idx = AudioServer.get_bus_index("Music")
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(vol_linear))


func set_sfx_volume(vol_linear: float) -> void:
	var idx = AudioServer.get_bus_index("SFX")
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(vol_linear))


func vibrate_light() -> void:
	if SettingsManager.vibration_enabled and OS.has_feature("mobile"):
		Input.vibrate_handheld(40)


func vibrate_medium() -> void:
	if SettingsManager.vibration_enabled and OS.has_feature("mobile"):
		Input.vibrate_handheld(80)


func vibrate_strong() -> void:
	if SettingsManager.vibration_enabled and OS.has_feature("mobile"):
		Input.vibrate_handheld(150)


# =====================================================
# GAME EVENT HANDLERS
# =====================================================

func _on_platform_landed(is_perfect: bool) -> void:
	if is_perfect:
		play(SND_PERFECT)
		vibrate_light()
	else:
		play(SND_LAND)


func _on_coins_earned(_amount: int) -> void:
	play(SND_COIN)


func _on_run_started() -> void:
	if _music_player and _music_player.stream:
		_music_player.play(0.0)


func _on_run_completed() -> void:
	pass  # Game over sound is called from game.gd directly


# =====================================================
# SFX GENERATION — Procedural PCM
# =====================================================

func _pre_generate_sfx() -> void:
	_sfx_streams[SND_BUTTON]   = _gen_button()
	_sfx_streams[SND_LAND]     = _gen_land()
	_sfx_streams[SND_PERFECT]  = _gen_perfect()
	_sfx_streams[SND_COMBO]    = _gen_combo()
	_sfx_streams[SND_GAMEOVER] = _gen_gameover()
	_sfx_streams[SND_COIN]     = _gen_coin()
	_sfx_streams[SND_PURCHASE] = _gen_purchase()
	_sfx_streams[SND_EQUIP]    = _gen_equip()
	_sfx_streams[SND_REWARD]   = _gen_reward()
	_sfx_streams[SND_PAUSE]    = _gen_pause()
	_sfx_streams[SND_ERROR]    = _gen_error()
	_sfx_streams[SND_RECORD]   = _gen_reward()  # Alias


# Helper: build AudioStreamWAV from float samples
func _make_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var wav = AudioStreamWAV.new()
	wav.format  = AudioStreamWAV.FORMAT_16_BITS
	wav.stereo  = false
	wav.mix_rate = _SAMPLE_RATE
	var bytes = PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		var v = int(clampf(samples[i], -1.0, 1.0) * 32767.0)
		bytes[i * 2]     = v & 0xFF
		bytes[i * 2 + 1] = (v >> 8) & 0xFF
	wav.data = bytes
	return wav


# Helper: sine oscillator with envelope
func _sine_env(freq: float, dur: float, attack: float = 0.005,
		decay: float = 0.0, sustain: float = 1.0,
		release: float = 0.0, amplitude: float = 0.8) -> PackedFloat32Array:
	var n = int(dur * _SAMPLE_RATE)
	var a_s = int(attack * _SAMPLE_RATE)
	var d_s = int(decay * _SAMPLE_RATE)
	var r_s = int(release * _SAMPLE_RATE)
	var s_s = max(0, n - a_s - d_s - r_s)
	var out = PackedFloat32Array()
	out.resize(n)
	var phase = 0.0
	var phase_inc = freq / float(_SAMPLE_RATE)
	for i in n:
		var env: float
		if i < a_s:
			env = float(i) / float(max(a_s, 1))
		elif i < a_s + d_s:
			env = 1.0 - (1.0 - sustain) * float(i - a_s) / float(max(d_s, 1))
		elif i < a_s + d_s + s_s:
			env = sustain
		else:
			env = sustain * (1.0 - float(i - a_s - d_s - s_s) / float(max(r_s, 1)))
		out[i] = amplitude * env * sin(TAU * phase)
		phase = fmod(phase + phase_inc, 1.0)
	return out


# Helper: mix two float arrays (in-place into first)
func _mix(a: PackedFloat32Array, b: PackedFloat32Array, b_gain: float = 1.0) -> void:
	var n = min(a.size(), b.size())
	for i in n:
		a[i] += b[i] * b_gain


# Helper: write b into a at offset
func _write_at(a: PackedFloat32Array, b: PackedFloat32Array, offset: int) -> void:
	var n = min(b.size(), a.size() - offset)
	for i in n:
		a[offset + i] += b[i]


# Helper: normalize to target peak
func _normalize(a: PackedFloat32Array, target: float = 0.85) -> void:
	var peak = 0.0
	for v in a:
		if abs(v) > peak: peak = abs(v)
	if peak < 0.001: return
	var scale = target / peak
	for i in a.size():
		a[i] *= scale


# ── Individual SFX ──────────────────────────────────────

func _gen_button() -> AudioStreamWAV:
	# Short clean high click 2200 Hz, 50ms
	var s = _sine_env(2200.0, 0.05, 0.002, 0.0, 1.0, 0.048, 0.5)
	_normalize(s, 0.7)
	return _make_wav(s)


func _gen_land() -> AudioStreamWAV:
	# Soft thump: frequency sweep 120→40 Hz, 100ms
	var n = int(0.12 * _SAMPLE_RATE)
	var out = PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t = float(i) / float(_SAMPLE_RATE)
		var freq = 120.0 * pow(40.0 / 120.0, t / 0.12)
		var env  = exp(-20.0 * t)
		out[i]   = 0.7 * env * sin(TAU * freq * t)
	_normalize(out, 0.8)
	return _make_wav(out)


func _gen_perfect() -> AudioStreamWAV:
	# Three ascending notes: E5(659), G5(784), B5(988), 80ms each, overlapping
	var total = int(0.35 * _SAMPLE_RATE)
	var out   = PackedFloat32Array(); out.resize(total)
	var notes = [659.0, 784.0, 988.0]
	var spacing = int(0.09 * _SAMPLE_RATE)
	for ni in 3:
		var b = _sine_env(notes[ni], 0.18, 0.01, 0.02, 0.7, 0.14, 0.6)
		_write_at(out, b, ni * spacing)
	_normalize(out, 0.85)
	return _make_wav(out)


func _gen_combo() -> AudioStreamWAV:
	# Rising two-note: A4(440) → E5(659), 80ms each
	var total = int(0.25 * _SAMPLE_RATE)
	var out   = PackedFloat32Array(); out.resize(total)
	var a = _sine_env(440.0, 0.12, 0.005, 0.0, 0.8, 0.11, 0.6)
	var b = _sine_env(659.0, 0.14, 0.005, 0.0, 0.8, 0.13, 0.6)
	_write_at(out, a, 0)
	_write_at(out, b, int(0.10 * _SAMPLE_RATE))
	_normalize(out, 0.85)
	return _make_wav(out)


func _gen_gameover() -> AudioStreamWAV:
	# Descending sweep: A4→E4→A3, each note 0.12s, total 0.5s
	var total = int(0.55 * _SAMPLE_RATE)
	var out   = PackedFloat32Array(); out.resize(total)
	var notes = [440.0, 329.6, 220.0]
	for ni in 3:
		var b = _sine_env(notes[ni], 0.20, 0.01, 0.0, 0.7, 0.18, 0.55)
		_write_at(out, b, ni * int(0.16 * _SAMPLE_RATE))
	_normalize(out, 0.80)
	return _make_wav(out)


func _gen_coin() -> AudioStreamWAV:
	# Two-note metallic: C5(523) → G5(784), 80ms each
	var total = int(0.22 * _SAMPLE_RATE)
	var out   = PackedFloat32Array(); out.resize(total)
	var a = _sine_env(523.0, 0.10, 0.003, 0.0, 0.8, 0.09, 0.65)
	var b = _sine_env(784.0, 0.12, 0.003, 0.0, 0.8, 0.11, 0.65)
	_write_at(out, a, 0)
	_write_at(out, b, int(0.09 * _SAMPLE_RATE))
	_normalize(out, 0.80)
	return _make_wav(out)


func _gen_purchase() -> AudioStreamWAV:
	# Positive 3-note confirm: C5, E5, G5 — staccato
	var total = int(0.30 * _SAMPLE_RATE)
	var out   = PackedFloat32Array(); out.resize(total)
	var notes = [523.0, 659.0, 784.0]
	for ni in 3:
		var b = _sine_env(notes[ni], 0.10, 0.005, 0.0, 0.75, 0.09, 0.6)
		_write_at(out, b, ni * int(0.085 * _SAMPLE_RATE))
	_normalize(out, 0.85)
	return _make_wav(out)


func _gen_equip() -> AudioStreamWAV:
	# Bright two-note: G5→B5, 90ms each
	var total = int(0.22 * _SAMPLE_RATE)
	var out   = PackedFloat32Array(); out.resize(total)
	var a = _sine_env(784.0, 0.10, 0.003, 0.0, 0.8, 0.09, 0.65)
	var b = _sine_env(988.0, 0.12, 0.003, 0.0, 0.8, 0.11, 0.65)
	_write_at(out, a, 0)
	_write_at(out, b, int(0.09 * _SAMPLE_RATE))
	_normalize(out, 0.82)
	return _make_wav(out)


func _gen_reward() -> AudioStreamWAV:
	# Rising 4-note arpeggio: C4, E4, G4, C5 — celebratory
	var total = int(0.45 * _SAMPLE_RATE)
	var out   = PackedFloat32Array(); out.resize(total)
	var notes = [261.6, 329.6, 392.0, 523.0]
	for ni in 4:
		var b = _sine_env(notes[ni], 0.16, 0.005, 0.0, 0.75, 0.14, 0.6)
		_write_at(out, b, ni * int(0.09 * _SAMPLE_RATE))
	_normalize(out, 0.85)
	return _make_wav(out)


func _gen_pause() -> AudioStreamWAV:
	# Soft descend: A4→E4, gentle 80ms
	var total = int(0.18 * _SAMPLE_RATE)
	var out   = PackedFloat32Array(); out.resize(total)
	var a = _sine_env(440.0, 0.09, 0.005, 0.0, 0.6, 0.08, 0.45)
	var b = _sine_env(329.6, 0.10, 0.005, 0.0, 0.6, 0.09, 0.45)
	_write_at(out, a, 0)
	_write_at(out, b, int(0.07 * _SAMPLE_RATE))
	_normalize(out, 0.65)
	return _make_wav(out)


func _gen_error() -> AudioStreamWAV:
	# Short descend buzz: A4→E3, 200ms
	var total = int(0.22 * _SAMPLE_RATE)
	var out   = PackedFloat32Array(); out.resize(total)
	var a = _sine_env(440.0, 0.10, 0.003, 0.0, 0.7, 0.09, 0.55)
	var b = _sine_env(164.8, 0.13, 0.003, 0.0, 0.7, 0.12, 0.55)
	_write_at(out, a, 0)
	_write_at(out, b, int(0.08 * _SAMPLE_RATE))
	_normalize(out, 0.75)
	return _make_wav(out)


# =====================================================
# MUSIC GENERATION — Synthwave Loop
# 120 BPM, 4 bars, A minor, ~8 seconds
# =====================================================

func _setup_music() -> void:
	var stream = load("res://MUSICFORBACKGROUD.mp3")
	if stream is AudioStream:
		stream.loop = true
	_music_player = AudioStreamPlayer.new()
	_music_player.bus    = "Music"
	_music_player.stream = stream
	_music_player.volume_db = 0.0
	add_child(_music_player)
	# Removed call_deferred("play_music") so splash screen doesn't get interrupted.


func _generate_music_loop() -> AudioStreamWAV:
	var sr      = _SAMPLE_RATE
	var bpm     = 85
	var bars    = 4
	var spb     = int(sr * 60.0 / bpm)  # samples per beat
	var total   = bars * 4 * spb        # 4 beats * 4 bars

	var mix = PackedFloat32Array()
	mix.resize(total)
	mix.fill(0.0)

	# Softer Ambient Layers
	_add_kick(mix, sr, spb, bars)
	_add_bass(mix, sr, spb, bars)
	_add_pad(mix, sr, total)

	# Master normalize
	_normalize(mix, 0.75)

	# Build looping WAV
	var bytes = PackedByteArray()
	bytes.resize(total * 2)
	for i in total:
		var v = int(clampf(mix[i], -1.0, 1.0) * 32767.0)
		bytes[i * 2]     = v & 0xFF
		bytes[i * 2 + 1] = (v >> 8) & 0xFF

	var wav = AudioStreamWAV.new()
	wav.format      = AudioStreamWAV.FORMAT_16_BITS
	wav.stereo      = false
	wav.mix_rate    = sr
	wav.loop_mode   = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin  = 0
	wav.loop_end    = total
	wav.data        = bytes
	return wav


# ── Kick drum ──────────────────────────────────────────
# Pattern: beats 1 & 3 of every bar
func _add_kick(mix: PackedFloat32Array, sr: int, spb: int, bars: int) -> void:
	var dur_s = int(0.15 * sr)
	for bar in bars:
		for beat_in_bar in [0, 2]:
			var start = (bar * 4 + beat_in_bar) * spb
			for i in dur_s:
				if start + i >= mix.size(): break
				var t   = float(i) / float(sr)
				var freq = 60.0 * exp(-15.0 * t)
				var env  = exp(-12.0 * t)
				mix[start + i] += 0.4 * env * sin(TAU * freq * t)


# ── Hi-hat ────────────────────────────────────────────
# Pattern: every 8th note (every half beat)
func _add_hihat(mix: PackedFloat32Array, sr: int, spb: int, bars: int) -> void:
	var dur_s = int(0.04 * sr)
	var half  = spb / 2
	var total_eighths = bars * 8
	for e in total_eighths:
		var start = e * half
		for i in dur_s:
			if start + i >= mix.size(): break
			var t   = float(i) / float(sr)
			var env = exp(-60.0 * t)
			# White noise via pseudorandom from phase
			var noise = sin(13.7 * float(start + i) + 0.3) * sin(97.3 * float(start + i) + 1.1)
			mix[start + i] += 0.22 * env * noise


# ── Bass ──────────────────────────────────────────────
# Pattern: one note per beat, A minor root movement
# Notes (Hz): A2=110, E2=82.4, G2=98, C3=130.8, D3=146.8
func _add_bass(mix: PackedFloat32Array, sr: int, spb: int, _bars: int) -> void:
	# 16 beats = 4 bars, one note per beat
	var pattern = [110.0, 110.0, 82.4,  98.0,
				   110.0, 110.0, 130.8, 98.0,
				   110.0, 110.0, 82.4,  98.0,
				   110.0, 130.8, 82.4,  110.0]
	var dur_s = int(0.48 * sr)  # ~0.48s per beat at 120 BPM (slightly shorter than full beat)
	for bi in pattern.size():
		var freq  = pattern[bi]
		var start = bi * spb
		var phase = 0.0
		var phase_inc = freq / float(sr)
		for i in dur_s:
			if start + i >= mix.size(): break
			var t   = float(i) / float(dur_s)
			# Sine wave for softer bass
			var saw = sin(TAU * phase)
			# Smooth envelope: attack 5ms, sustain, release 15%
			var env: float
			if t < 0.1:
				env = t / 0.1
			elif t > 0.8:
				env = (1.0 - t) / 0.2
			else:
				env = 1.0
			mix[start + i] += 0.25 * env * saw
			phase = fmod(phase + phase_inc, 1.0)


# ── Atmospheric pad ────────────────────────────────────
# Am chord: A3(220), C4(261.6), E4(329.6) — detuned for width
func _add_pad(mix: PackedFloat32Array, sr: int, total: int) -> void:
	var chord = [220.0, 261.6, 329.6]
	var detune = [0.0, 0.3, -0.2]    # slight detuning in Hz
	for ci in chord.size():
		var freq = chord[ci] + detune[ci]
		var phase = 0.0
		var phase_inc = freq / float(sr)
		for i in total:
			var t   = float(i) / float(total)
			# Slow attack, then sustain
			var env = min(t / 0.3, 1.0) * 0.18
			mix[i] += env * sin(TAU * phase)
			phase = fmod(phase + phase_inc, 1.0)


# ── Synth arpeggio ─────────────────────────────────────
# 16th notes (4 per beat): Am pentatonic ascending/descending
# Notes: A3=220, C4=261.6, E4=329.6, G4=392, A4=440
func _add_arpeggio(mix: PackedFloat32Array, sr: int, spb: int, bars: int) -> void:
	var notes = [220.0, 261.6, 329.6, 392.0, 440.0, 392.0, 329.6, 261.6]
	var sixteenth = spb / 4
	var total_sixteenths = bars * 16
	var dur_s = int(0.11 * sr)
	for si in total_sixteenths:
		var freq  = notes[si % notes.size()]
		var start = si * sixteenth
		var phase = 0.0
		var phase_inc = freq / float(sr)
		for i in dur_s:
			if start + i >= mix.size(): break
			var t   = float(i) / float(dur_s)
			var env: float
			if t < 0.05:   env = t / 0.05
			elif t > 0.7:  env = (1.0 - t) / 0.3
			else:           env = 1.0
			mix[start + i] += 0.28 * env * sin(TAU * phase)
			phase = fmod(phase + phase_inc, 1.0)
