class_name Sfx
extends Node
## 효과음: 외부 음원 파일 없이 코드로 합성한다 (라이선스 걱정 없음).
## 동전(거래), 종(최종 제안), 탁(제안), 딸랑(손님 입장), 부저(화남), 팡파레(레벨 업)

const RATE := 22050
var players: Array = []
var bank := {}
var muted := false


func _ready() -> void:
	for i in 4:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)
	bank["coin"] = _tones([[1318.5, 0.07], [1975.5, 0.18]], 0.35)
	bank["bell"] = _bell(1046.5, 0.9)
	bank["tap"] = _noise(0.07, 0.5)
	bank["door"] = _tones([[880.0, 0.12], [659.3, 0.22]], 0.3)
	bank["buzz"] = _square(110.0, 0.28, 0.18)
	bank["fanfare"] = _tones([[523.3, 0.1], [659.3, 0.1], [784.0, 0.1], [1046.5, 0.3]], 0.3)


func play(name: String) -> void:
	if muted or not bank.has(name):
		return
	for p in players:
		if not p.playing:
			p.stream = bank[name]
			p.play()
			return
	players[0].stream = bank[name]
	players[0].play()


func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w


func _tones(notes: Array, vol: float) -> AudioStreamWAV:
	var out := PackedFloat32Array()
	for nt in notes:
		var f: float = nt[0]
		var n := int(RATE * float(nt[1]))
		for i in n:
			var env := minf(1.0, i / 200.0) * (1.0 - float(i) / n)
			out.append(sin(TAU * f * i / RATE) * env * vol)
	return _wav(out)


func _bell(f: float, dur: float) -> AudioStreamWAV:
	var out := PackedFloat32Array()
	var n := int(RATE * dur)
	for i in n:
		var tt := float(i) / RATE
		var env := exp(-tt * 5.0)
		out.append((sin(TAU * f * tt) + 0.5 * sin(TAU * f * 2.76 * tt) + 0.25 * sin(TAU * f * 5.4 * tt)) * env * 0.25)
	return _wav(out)


func _noise(dur: float, vol: float) -> AudioStreamWAV:
	var out := PackedFloat32Array()
	var n := int(RATE * dur)
	var r := RandomNumberGenerator.new()
	r.seed = 7
	var last := 0.0
	for i in n:
		last = last * 0.7 + r.randf_range(-1, 1) * 0.3
		out.append(last * (1.0 - float(i) / n) * vol * 2.0)
	return _wav(out)


func _square(f: float, dur: float, vol: float) -> AudioStreamWAV:
	var out := PackedFloat32Array()
	var n := int(RATE * dur)
	for i in n:
		out.append((1.0 if fmod(f * i / RATE, 1.0) < 0.5 else -1.0) * vol * (1.0 - float(i) / n))
	return _wav(out)
