class_name Sfx
extends Node
## Procedural chiptune audio: every sound effect and both songs are synthesised at
## start-up into AudioStreamWAV buffers, so the project ships with no audio files.

const RATE := 22050
const MASTER := 0.8

const POOL := 12
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _music: AudioStreamPlayer
var _fx: Dictionary = {}
var _songs: Dictionary = {}
var _want_song := ""
var _jobs: Array = []
const BUDGET_USEC := 3000

const SONGS := {
	stage = {step = 0.14, bass = [45, 0, 45, 57, 45, 0, 45, 55, 41, 0, 41, 53, 43, 0, 43, 55],
		lead = [69, 0, 72, 74, 76, 0, 74, 72, 74, 0, 71, 0, 67, 69, 71, 0, 72, 0, 76, 79, 81, 0, 79, 76, 77, 0, 76, 74, 76, 0, 0, 0]},
	boss = {step = 0.11, bass = [45, 45, 46, 45, 45, 45, 48, 46, 45, 45, 46, 45, 52, 51, 50, 48],
		lead = [69, 70, 69, 0, 72, 0, 69, 0, 75, 74, 72, 0, 70, 0, 69, 0]},
}


func _ready() -> void:
	# A pool of plain players (as in tether-rally) rather than one AudioStreamPolyphonic:
	# the polyphonic player was the main suspect for the Android crash a few seconds into a run.
	for i in POOL:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	_music = AudioStreamPlayer.new()
	_music.volume_db = -3.0
	add_child(_music)
	# Songs are not looping streams: the on-device crash report showed the Android build
	# dying right when the stage song first reached its loop point (4.5 s after it started).
	# The player restarts the song itself when it ends.
	_music.finished.connect(_on_music_end)
	_build_fx()
	for name in SONGS:
		var s: Dictionary = SONGS[name]
		var steps: int = maxi(s.bass.size(), s.lead.size())
		var b := PackedFloat32Array()
		b.resize(int(steps * float(s.step) * RATE))
		_jobs.append({name = name, i = 0, steps = steps, buf = b})


## Songs are synthesised a few notes per frame on the main thread (no worker threads:
## they crashed the Android build a few seconds after start-up).
func _process(_delta: float) -> void:
	if _jobs.is_empty():
		set_process(false)
		return
	var t0 := Time.get_ticks_usec()
	while not _jobs.is_empty() and Time.get_ticks_usec() - t0 < BUDGET_USEC:
		var j: Dictionary = _jobs[0]
		var s: Dictionary = SONGS[j.name]
		var bass: Array = s.bass
		var lead: Array = s.lead
		var step: float = s.step
		var i: int = j.i
		var t := i * step
		if bass[i % bass.size()]:
			_tone(j.buf, "square", _midi(bass[i % bass.size()]), 0, step * 0.85, 0.03, t, true)
		if lead[i % lead.size()]:
			_tone(j.buf, "triangle", _midi(lead[i % lead.size()]), 0, step * 1.7, 0.05, t, true)
		j.i = i + 1
		if j.i >= j.steps:
			_songs[j.name] = _wav(j.buf)
			Diag.note("SONG", "%s built" % j.name)
			_jobs.pop_front()
			if _want_song == j.name and not _music.playing:
				music(_want_song)


func _on_music_end() -> void:
	if _want_song != "" and _music.stream == _songs.get(_want_song):
		Diag.once("music restart " + _want_song)
		_music.play()


func songs_ready() -> bool:
	return _jobs.is_empty()


func play(name: String, arg := 0) -> void:
	var key := name + (str(arg) if name == "beam" else "")
	if not _fx.has(key):
		return
	# take a free player, else the one that started longest ago
	var p: AudioStreamPlayer = _pool[_next]
	for i in POOL:
		var q: AudioStreamPlayer = _pool[(_next + i) % POOL]
		if not q.playing:
			p = q
			_next = (_next + i) % POOL
			break
	_next = (_next + 1) % POOL
	p.stream = _fx[key]
	p.play()


func music(name: String) -> void:
	_want_song = name
	var s: AudioStream = _songs.get(name)
	if name == "" or s == null:
		_music.stop()
		return
	Diag.once("music " + name)
	_music.stream = s
	_music.play()


func set_muted(m: bool) -> void:
	AudioServer.set_bus_mute(0, m)


func set_paused(p: bool) -> void:
	_music.stream_paused = p


# ---------- synthesis ----------

static func _osc(type: String, ph: float) -> float:
	var f := ph - floorf(ph)
	match type:
		"square":
			return 1.0 if f < 0.5 else -1.0
		"triangle":
			return 4.0 * absf(f - 0.5) - 1.0
		"sawtooth":
			return 2.0 * f - 1.0
	return sin(f * TAU)


## Adds an oscillator with an exponential pitch sweep and decay into `buf`.
static func _tone(buf: PackedFloat32Array, type: String, f0: float, f1: float, dur: float, vol: float, when := 0.0, wrap := false) -> void:
	var start := int(when * RATE)
	var n := int(dur * RATE)
	var ph := 0.0
	var size := buf.size()
	for i in n:
		var t := float(i) / n
		var f := f0 * pow(f1 / f0, t) if f1 > 0.0 else f0
		ph += f / RATE
		var idx := start + i
		if wrap:
			idx %= size
		elif idx >= size:
			break
		buf[idx] += _osc(type, ph) * vol * pow(0.0001 / vol, t)


static func _noise(buf: PackedFloat32Array, dur: float, vol: float, freq: float) -> void:
	var n := mini(int(dur * RATE), buf.size())
	var y := 0.0
	for i in n:
		var t := float(i) / n
		var cut := freq * pow(80.0 / freq, t)
		var a := 1.0 - exp(-TAU * cut / RATE)
		y += (randf() * 2.0 - 1.0 - y) * a
		buf[i] += y * vol * 1.6 * pow(0.0001 / vol, t)


## Never set a loop mode here (see _ready).
static func _wav(buf: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	for i in buf.size():
		data.encode_s16(i * 2, int(clampf(buf[i] * MASTER, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w


static func _buf(dur: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(dur * RATE) + 64)
	return b


func _build_fx() -> void:
	var b: PackedFloat32Array
	b = _buf(0.08); _tone(b, "square", 1300, 380, 0.07, 0.04); _fx.shot = _wav(b)
	b = _buf(0.04); _tone(b, "square", 1800, 900, 0.035, 0.018); _fx.rapid = _wav(b)
	for l in [1, 2, 3]:
		b = _buf(0.6); _tone(b, "sawtooth", 1000, 80, 0.25 + 0.1 * l, 0.07); _noise(b, 0.2, 0.06, 4000); _fx["beam" + str(l)] = _wav(b)
	b = _buf(0.5); _noise(b, 0.5, 0.22, 900); _fx.boom = _wav(b)
	b = _buf(0.18); _noise(b, 0.18, 0.12, 2000); _fx.small = _wav(b)
	b = _buf(0.04); _tone(b, "square", 320, 160, 0.03, 0.025); _fx.hit = _wav(b)
	b = _buf(0.05); _tone(b, "triangle", 2600, 1900, 0.04, 0.03); _fx.tink = _wav(b)
	b = _buf(0.2)
	for i in 3:
		_tone(b, "square", [660, 880, 1320][i], 0, 0.07, 0.045, i * 0.06)
	_fx.pick = _wav(b)
	b = _buf(0.9); _noise(b, 0.9, 0.28, 700); _tone(b, "square", 600, 50, 0.8, 0.06); _fx.die = _wav(b)
	b = _buf(0.06); _tone(b, "square", 1760, 0, 0.05, 0.03); _fx.ready = _wav(b)
	b = _buf(1.15)
	for i in 4:
		_tone(b, "square", 880, 440, 0.2, 0.045, i * 0.3)
	_fx.alarm = _wav(b)
	b = _buf(0.1); _tone(b, "triangle", 500, 1100, 0.09, 0.05); _fx.pod = _wav(b)
	b = _buf(0.08); _tone(b, "triangle", 1100, 700, 0.07, 0.05); _fx.dock = _wav(b)
	b = _buf(0.36)
	for i in 4:
		_tone(b, "square", [523, 659, 784, 1047][i], 0, 0.09, 0.045, i * 0.08)
	_fx.oneup = _wav(b)


static func _midi(m: int) -> float:
	return 440.0 * pow(2.0, (m - 69) / 12.0)
