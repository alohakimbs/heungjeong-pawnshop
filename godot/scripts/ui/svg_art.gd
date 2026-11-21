class_name SvgArt
extends RefCounted
## 손님 캐릭터를 SVG 문자열로 그리고 런타임에 텍스처로 래스터화한다.
## 웹 프로토타입 v0.2의 drawChar()/outfit()을 이식. 좌표계: 머리 중심 (0,0), 카운터 높이 y=222.
## M2에서 일러스트 파츠로 교체할 때까지의 임시 그래픽이다.

const SKINS := ["#f6d3b3", "#eac29a", "#d9a679", "#b97f55", "#8d5a3b"]
const HAIRS := ["#2b1b12", "#5b3a1e", "#a0522d", "#1d1d1d", "#e2b84a"]


static func n(v: float) -> String:
	return str(snappedf(v, 0.1))


## 기본값을 채운 외형 딕셔너리
static func look(o: Dictionary) -> Dictionary:
	var d := {"skin": "#eac29a", "head": "round", "hair": 0, "hc": "#2b1b12", "outfit": "tee", "oc": "#3d6e8f", "oc2": "#ffffff", "bw": 1.0, "eyes": "dot", "brows": "norm", "nose": "button", "fh": 0, "hat": "none", "glasses": 0, "acc": []}
	for k in o:
		d[k] = o[k]
	d["hair"] = int(d["hair"])
	d["fh"] = int(d["fh"])
	d["glasses"] = int(d["glasses"])
	d["bw"] = float(d["bw"])
	return d


## 일반 손님 외형: 유형(arch) + 성향(traits)으로 결정. 같은 seed면 항상 같은 얼굴.
static func customer_look(arch: String, traits: Array, seed_value: int) -> Dictionary:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	var p := func(a: Array): return a[r.randi_range(0, a.size() - 1)]
	var o := {"skin": p.call(SKINS), "hc": p.call(HAIRS), "nose": p.call(["button", "long", "round"])}
	match arch:
		"granny":
			o.merge({"head": "round", "hair": 5, "hc": p.call(["#d9d4cc", "#bfb8ad", "#e8e4dc"]), "outfit": "hanbok", "oc": p.call(["#c8506a", "#5b7fb8", "#7fa65a"]), "oc2": "#f0d24a", "bw": r.randf_range(0.9, 1.05), "acc": ["wrinkles"], "nose": "round"}, true)
		"student":
			o.merge({"head": p.call(["round", "oval"]), "hair": p.call([0, 3, 6, 8, 9]), "outfit": "hoodie", "oc": p.call(["#3d6e8f", "#8a8f99", "#c46a8a", "#5a8f4e", "#2d2d33"]), "bw": r.randf_range(0.85, 1.0), "glasses": 4 if r.randf() < 0.4 else 0}, true)
		"office":
			o.merge({"head": p.call(["oval", "square", "long"]), "hair": p.call([0, 6, 7, 9]), "outfit": "suit", "oc": p.call(["#2f3a4f", "#4a4a52", "#5a4636"]), "oc2": p.call(["#b8473c", "#3d6e8f", "#d08a2c"]), "bw": r.randf_range(0.9, 1.1), "glasses": 4 if r.randf() < 0.3 else 0}, true)
		"ajussi":
			o.merge({"head": p.call(["square", "round"]), "hair": p.call([2, 9, 0]), "outfit": p.call(["track", "cardigan"]), "oc": p.call(["#3a5a8a", "#6b4a7a", "#7a3a3a", "#4a6a4a"]), "oc2": "#e8e0d0", "bw": r.randf_range(1.15, 1.4), "fh": p.call([0, 1, 3])}, true)
		"hipster":
			o.merge({"head": p.call(["long", "oval"]), "hair": p.call([1, 8, 3]), "outfit": p.call(["cardigan", "tee"]), "oc": p.call(["#c9a25a", "#7a8a5a", "#a05a3a"]), "oc2": "#2d2d2d", "bw": r.randf_range(0.85, 1.0), "fh": p.call([0, 2, 2]), "hat": p.call(["beanie", "beret", "none"])}, true)
		"owner":
			o.merge({"head": p.call(["round", "square"]), "hair": p.call([0, 9, 2]), "outfit": "apron", "oc": p.call(["#e8e0d0", "#d0e0e8"]), "oc2": p.call(["#3d6e8f", "#b8473c", "#5a8f4e"]), "bw": r.randf_range(1.0, 1.25), "hat": "headband" if r.randf() < 0.5 else "none"}, true)
		"madam":
			o.merge({"head": "oval", "hair": p.call([6, 1]), "hc": p.call(["#3a2418", "#6a3a5a", "#8a5a2a"]), "outfit": "coat", "oc": p.call(["#d8c3a5", "#a83a4a", "#2a2a2a"]), "oc2": "#5a3a2a", "bw": r.randf_range(0.9, 1.05), "acc": ["pearl", "earring"]}, true)
	var L := look(o)
	var acc: Array = L["acc"].duplicate()
	var t := func(k): return traits.has(k)
	if t.call("rich"):
		acc.append("pearl" if L["outfit"] == "coat" else "chain")
		if L["glasses"] == 0 and r.randf() < 0.5:
			L["glasses"] = 2
	if t.call("naive"):
		L["eyes"] = "big"
		acc.append("blush")
	if t.call("calm"):
		L["eyes"] = "sleepy"
	if t.call("scammer"):
		L["eyes"] = "shifty"
		L["hat"] = "fedora"
		L["fh"] = 1
		if r.randf() < 0.5:
			L["outfit"] = "coat"
			L["oc"] = "#9a8466"
	if t.call("expert"):
		L["glasses"] = 1
	if t.call("hasty"):
		acc.append("sweat")
	if t.call("stingy"):
		acc.append("patch")
	if t.call("collector"):
		acc.append("pins")
	if t.call("desperate"):
		acc.append_array(["bags", "bandaid"])
	if t.call("greedy"):
		acc.append("goldtooth")
	if t.call("proud"):
		L["brows"] = "proud"
	if t.call("chatty"):
		acc.append("chatty")
	L["acc"] = acc
	return L


## 캐릭터 SVG 본문(좌표계: 머리 중심 0,0)
static func draw_char(L: Dictionary, mood: String, legs := false) -> String:
	var sk: String = L["skin"]
	var hc: String = L["hc"]
	var acc: Array = L["acc"]
	var HS := {"round": [46, 50], "oval": [42, 56], "square": [47, 51], "long": [40, 59]}
	var hs: Array = HS.get(L["head"], [46, 50])
	var rx: float = hs[0]
	var ry: float = hs[1]
	var w: float = 64.0 * L["bw"]
	var T := ry + 12.0
	var B := 222.0
	var s := ""
	var hair: int = L["hair"]
	# 뒷머리
	if hair == 1:
		s += '<path d="M%s -8 Q%s %s 0 %s Q%s %s %s -8 L%s %s Q0 %s %s %s Z" fill="%s"/>' % [n(-rx - 6), n(-rx - 8), n(-ry - 12), n(-ry - 12), n(rx + 8), n(-ry - 12), n(rx + 6), n(rx + 12), n(ry + 48), n(ry + 60), n(-rx - 12), n(ry + 48), hc]
	if hair == 6:
		s += '<path d="M%s 0 Q%s %s 0 %s Q%s %s %s 0 L%s %s Q%s %s %s %s L%s %s Q%s %s %s %s Z" fill="%s"/>' % [n(-rx - 9), n(-rx - 11), n(-ry - 10), n(-ry - 10), n(rx + 11), n(-ry - 10), n(rx + 9), n(rx + 9), n(ry * 0.65), n(rx), n(ry * 0.8), n(rx - 6), n(ry * 0.6), n(-rx + 6), n(ry * 0.6), n(-rx), n(ry * 0.8), n(-rx - 9), n(ry * 0.65), hc]
	if hair == 8:
		s += '<path d="M%s %s Q%s %s %s %s Q%s %s %s %s Z" fill="%s"/>' % [n(rx - 8), n(-ry * 0.6), n(rx + 34), n(-ry * 0.5), n(rx + 24), n(ry * 0.5), n(rx + 14), n(-ry * 0.05), n(rx - 6), n(-ry * 0.25), hc]
	# 몸통
	s += '<path d="M%s %s L%s %s Q%s %s %s %s L%s %s Q%s %s %s %s L%s %s Z" fill="%s"/>' % [n(-w), n(B), n(-w), n(T + 38), n(-w), n(T + 2), n(-w * 0.42), n(T - 4), n(w * 0.42), n(T - 4), n(w), n(T + 2), n(w), n(T + 38), n(w), n(B), L["oc"]]
	s += _outfit(L, w, T, B)
	s += '<path d="M%s %s L%s %s Q%s %s %s %s L%s %s L%s %s Z" fill="#000" opacity=".1"/>' % [n(w * 0.25), n(T - 4), n(w * 0.42), n(T - 4), n(w), n(T + 2), n(w), n(T + 38), n(w), n(B), n(w * 0.35), n(B)]
	s += '<path d="M%s %s Q%s %s %s %s M%s %s Q%s %s %s %s" stroke="#000" stroke-opacity=".2" stroke-width="3" fill="none"/>' % [n(-w + 18), n(T + 40), n(-w + 14), n(B - 40), n(-w + 24), n(B - 16), n(w - 18), n(T + 40), n(w - 14), n(B - 40), n(w - 24), n(B - 16)]
	if acc.has("pearl"):
		for i in 9:
			var a := PI * (0.15 + i * 0.0875)
			s += '<circle cx="%s" cy="%s" r="4" fill="#f8f4ec" stroke="#cfc6b6"/>' % [n(cos(a) * 24), n(T - 2 + sin(a) * 22)]
	if acc.has("chain"):
		s += '<path d="M-22 %s Q0 %s 22 %s" fill="none" stroke="#f2c230" stroke-width="5" stroke-dasharray="4 3"/>' % [n(T), n(T + 34), n(T)]
	if acc.has("pins"):
		s += '<circle cx="%s" cy="%s" r="7" fill="#ffd34d" stroke="#8a6a12" stroke-width="2"/><circle cx="%s" cy="%s" r="6" fill="#e05a5a" stroke="#7a1a1a" stroke-width="2"/>' % [n(-w * 0.5), n(T + 46), n(-w * 0.5 + 14), n(T + 62)]
	if acc.has("patch"):
		s += '<rect x="%s" y="%s" width="22" height="20" fill="#d8c39a" stroke="#6b5636" stroke-width="2" stroke-dasharray="3 2"/>' % [n(w * 0.35), n(T + 70)]
	if acc.has("flower"):
		for a in [0, 72, 144, 216, 288]:
			s += '<circle cx="%s" cy="%s" r="6" fill="#fff0f5"/>' % [n(w * 0.3 + cos(deg_to_rad(a)) * 7), n(T + 52 + sin(deg_to_rad(a)) * 7)]
		s += '<circle cx="%s" cy="%s" r="5" fill="#f2c230"/>' % [n(w * 0.3), n(T + 52)]
	# 목
	s += '<path d="M-14 %s L-14 %s Q0 %s 14 %s L14 %s Z" fill="%s"/><path d="M-14 %s L14 %s L14 %s Q0 %s -14 %s Z" fill="#000" opacity=".15"/>' % [n(ry - 16), n(T + 2), n(T + 10), n(T + 2), n(ry - 16), sk, n(ry - 16), n(ry - 16), n(ry - 4), n(ry + 4), n(ry - 4)]
	if L["outfit"] == "turtle":
		s += '<rect x="-20" y="%s" width="40" height="%s" rx="9" fill="%s"/>' % [n(ry - 8), n(T - ry + 12), L["oc"]]
	if L["outfit"] == "hoodie":
		s += '<path d="M-14 %s L-12 %s M14 %s L12 %s" stroke="#f4efe6" stroke-width="3" stroke-linecap="round"/>' % [n(T + 4), n(T + 44), n(T + 4), n(T + 44)]
	# 다리 (대기 줄에 선 전신 모습)
	if legs:
		var pc: String = "#3a3a48" if L["outfit"] != "track" else L["oc"]
		s = '<rect x="%s" y="%s" width="%s" height="112" rx="8" fill="%s"/><rect x="4" y="%s" width="%s" height="112" rx="8" fill="%s"/><ellipse cx="%s" cy="%s" rx="22" ry="10" fill="#2a1e18"/><ellipse cx="%s" cy="%s" rx="22" ry="10" fill="#2a1e18"/>' % [n(-w * 0.62), n(B - 14), n(w * 0.62 - 4), pc, n(B - 14), n(w * 0.62 - 4), pc, n(-w * 0.32 - 4), n(B + 100), n(w * 0.32 + 4), n(B + 100)] + s
	# 손
	for d in ([] if legs else [-1, 1]):
		var hx: float = d * (w - 22)
		s += '<ellipse cx="%s" cy="%s" rx="16" ry="10" fill="%s" stroke="#000" stroke-opacity=".22" stroke-width="2"/>' % [n(hx), n(B - 6), sk]
	# 귀·머리
	s += '<circle cx="%s" cy="4" r="10" fill="%s"/><circle cx="%s" cy="4" r="10" fill="%s"/>' % [n(-rx), sk, n(rx), sk]
	if acc.has("earring"):
		s += '<circle cx="%s" cy="16" r="4" fill="#f2c230"/><circle cx="%s" cy="16" r="4" fill="#f2c230"/>' % [n(-rx), n(rx)]
	if L["head"] == "square":
		s += '<rect x="%s" y="%s" width="%s" height="%s" rx="%s" fill="%s"/>' % [n(-rx), n(-ry), n(rx * 2), n(ry * 2), n(rx * 0.62), sk]
	else:
		s += '<ellipse rx="%s" ry="%s" fill="%s"/>' % [n(rx), n(ry), sk]
	s += '<path d="M%s %s Q%s 0 %s %s" stroke="#000" stroke-opacity=".08" stroke-width="12" fill="none"/><ellipse cx="-12" cy="%s" rx="%s" ry="%s" fill="#fff" opacity=".2"/>' % [n(rx * 0.5), n(-ry * 0.75), n(rx * 1.05), n(rx * 0.45), n(ry * 0.88), n(-ry * 0.55), n(rx * 0.42), n(ry * 0.18)]
	if mood == "angry":
		s += '<ellipse cy="6" rx="%s" ry="%s" fill="#e0402a" opacity=".32"/>' % [n(rx - 4), n(ry - 6)]
	if acc.has("blush"):
		s += '<ellipse cx="-27" cy="18" rx="9" ry="5" fill="#f07a7a" opacity=".5"/><ellipse cx="27" cy="18" rx="9" ry="5" fill="#f07a7a" opacity=".5"/>'
	if acc.has("wrinkles"):
		s += '<path d="M-18 -30 Q0 -34 18 -30 M-14 -24 Q0 -27 14 -24 M-30 20 Q-26 30 -20 34 M30 20 Q26 30 20 34" stroke="#000" stroke-opacity=".18" stroke-width="2" fill="none"/>'
	if acc.has("scar"):
		s += '<path d="M22 -12 L34 14" stroke="#9a5a4a" stroke-width="3"/><path d="M24 -4 L31 -7 M27 3 L34 0 M30 10 L37 7" stroke="#9a5a4a" stroke-width="2"/>'
	if acc.has("bandaid"):
		s += '<g transform="translate(-24,-30) rotate(-25)"><rect x="-12" y="-4" width="24" height="9" rx="4" fill="#f0c9a0" stroke="#c49a70"/></g>'
	var fh: int = L["fh"]
	if fh == 2:
		s += '<path d="M%s 6 Q%s %s 0 %s Q%s %s %s 6 Q%s 30 0 34 Q%s 30 %s 6 Z" fill="%s"/>' % [n(-rx + 3), n(-rx + 6), n(ry + 12), n(ry + 16), n(rx - 6), n(ry + 12), n(rx - 3), n(rx * 0.55), n(-rx * 0.55), n(-rx + 3), hc]
	if fh == 3:
		s += '<ellipse cy="34" rx="%s" ry="%s" fill="%s" opacity=".18"/>' % [n(rx * 0.7), n(ry * 0.38), hc]
	# 눈
	var happy := mood == "happy"
	var shock := mood == "shock"
	var g: int = L["glasses"]
	var eyes: String = L["eyes"]
	if g != 2:
		if happy and eyes != "big":
			s += '<path d="M-25 2 Q-17 -7 -9 2 M9 2 Q17 -7 25 2" stroke="#222" stroke-width="3.5" fill="none" stroke-linecap="round"/>'
		elif eyes == "big" or shock:
			for x in [-17, 17]:
				s += '<circle cx="%d" cy="0" r="10" fill="#fff" stroke="#000" stroke-opacity=".2"/><circle cx="%d" cy="1" r="6" fill="#222"/><circle cx="%d" cy="-2" r="2.2" fill="#fff"/>' % [x, x, x - 2]
		elif eyes == "sleepy":
			s += '<path d="M-25 1 Q-17 -4 -9 1 M9 1 Q17 -4 25 1" stroke="#222" stroke-width="3.5" fill="none" stroke-linecap="round"/>'
		elif eyes == "shifty":
			for x in [-17, 17]:
				s += '<ellipse cx="%d" cy="0" rx="8" ry="5" fill="#fff"/><circle cx="%d" cy="0" r="3.6" fill="#222"/>' % [x, x - 4]
		else:
			s += '<ellipse cx="-17" cy="0" rx="4.6" ry="6" fill="#222"/><ellipse cx="17" cy="0" rx="4.6" ry="6" fill="#222"/><circle cx="-15.5" cy="-2" r="1.6" fill="#fff"/><circle cx="18.5" cy="-2" r="1.6" fill="#fff"/>'
	if acc.has("bags"):
		s += '<path d="M-25 10 Q-17 14 -9 10 M9 10 Q17 14 25 10" stroke="#7a5a4a" stroke-width="2" fill="none"/>'
	# 눈썹
	var bc := "#7a6a50" if hc in ["#c9c1b5", "#e2b84a", "#d9d4cc", "#e8e4dc", "#bfb8ad"] else hc
	var br := "M-27 -16 Q-18 -22 -9 -17 M27 -16 Q18 -22 9 -17"
	if mood == "angry":
		br = "M-28 -22 L-8 -13 M28 -22 L8 -13"
	elif mood == "meh":
		br = "M-27 -17 L-9 -16 M27 -17 L9 -16"
	elif shock:
		br = "M-27 -24 Q-18 -30 -9 -24 M27 -24 Q18 -30 9 -24"
	elif L["brows"] == "proud":
		br = "M-27 -17 Q-18 -21 -9 -17 M9 -23 Q18 -29 27 -25"
	if g != 2:
		s += '<path d="%s" stroke="%s" stroke-width="5" fill="none" stroke-linecap="round"/>' % [br, bc]
	# 코
	match L["nose"]:
		"long":
			s += '<path d="M2 -2 Q-6 18 5 21" stroke="#000" stroke-opacity=".3" stroke-width="3" fill="none" stroke-linecap="round"/>'
		"round":
			s += '<circle cx="0" cy="14" r="8" fill="%s" stroke="#000" stroke-opacity=".2" stroke-width="2"/>' % sk
		_:
			s += '<ellipse cx="0" cy="14" rx="6" ry="4.5" fill="#000" opacity=".14"/>'
	# 입
	var chat := acc.has("chatty")
	if happy:
		s += '<path d="M-16 25 Q0 47 16 25 Z" fill="#6a2018"/><path d="M-9 36 Q0 43 9 36" fill="#e07a6a"/><path d="M-14 26 L14 26" stroke="#fff" stroke-width="3"/>'
	elif shock:
		s += '<ellipse cy="34" rx="7" ry="9" fill="#5a1a12"/>'
	elif mood == "angry":
		s += '<path d="M-15 38 Q0 24 15 38" stroke="#5a2a22" stroke-width="4.5" fill="none" stroke-linecap="round"/>'
	elif mood == "meh":
		s += '<path d="M-11 33 L11 32" stroke="#5a2a22" stroke-width="4.5" stroke-linecap="round"/>'
	elif chat:
		s += '<path d="M-13 27 Q0 42 13 27 Z" fill="#6a2018"/>'
	else:
		s += '<path d="M-13 29 Q0 39 13 29" stroke="#5a2a22" stroke-width="4.5" fill="none" stroke-linecap="round"/>'
	if acc.has("goldtooth") and (happy or chat):
		s += '<rect x="3" y="26" width="6" height="6" fill="#f2c230"/>'
	if fh == 1:
		s += '<path d="M-18 23 Q-9 15 0 21 Q9 15 18 23 Q9 27 0 24 Q-9 27 -18 23 Z" fill="%s"/>' % hc
	if fh == 4:
		s += '<path d="M0 21 Q-12 14 -22 21 Q-30 22 -27 13 M0 21 Q12 14 22 21 Q30 22 27 13" stroke="%s" stroke-width="5" fill="none" stroke-linecap="round"/>' % hc
	# 안경
	if g == 1:
		s += '<circle cx="-17" cy="0" r="13" fill="#bfe3ff" fill-opacity=".18" stroke="#2a2a2a" stroke-width="3"/><circle cx="17" cy="0" r="13" fill="#bfe3ff" fill-opacity=".18" stroke="#2a2a2a" stroke-width="3"/><path d="M-4 -1 L4 -1 M-30 -2 L%s -4 M30 -2 L%s -4" stroke="#2a2a2a" stroke-width="3"/>' % [n(-rx), n(rx)]
	elif g == 4:
		s += '<rect x="-31" y="-10" width="27" height="19" rx="4" fill="#bfe3ff" fill-opacity=".15" stroke="#2a2a2a" stroke-width="3.5"/><rect x="4" y="-10" width="27" height="19" rx="4" fill="#bfe3ff" fill-opacity=".15" stroke="#2a2a2a" stroke-width="3.5"/><path d="M-4 -2 L4 -2 M-31 -4 L%s -6 M31 -4 L%s -6" stroke="#2a2a2a" stroke-width="3"/>' % [n(-rx), n(rx)]
	elif g == 2:
		s += '<path d="M-34 -10 L-3 -10 L-6 8 Q-18 14 -30 8 Z M34 -10 L3 -10 L6 8 Q18 14 30 8 Z" fill="#141414"/><path d="M-3 -6 L3 -6 M-34 -8 L%s -8 M34 -8 L%s -8" stroke="#141414" stroke-width="3"/><path d="M-28 -6 L-20 -6" stroke="#fff" stroke-opacity=".5" stroke-width="3"/>' % [n(-rx), n(rx)]
		if mood == "angry":
			s += '<path d="M-30 -16 L-8 -11 M30 -16 L8 -11" stroke="#141414" stroke-width="5" stroke-linecap="round"/>'
	elif g == 3:
		s += '<circle cx="17" cy="0" r="12" fill="#bfe3ff" fill-opacity=".2" stroke="#c9a227" stroke-width="3"/><path d="M28 6 Q34 40 22 70" stroke="#c9a227" stroke-width="1.5" fill="none"/>'
	# 앞머리
	s += _front_hair(hair, rx, ry, hc)
	# 모자
	var hat2: String = L["oc2"] if L["oc2"] != "#ffffff" and L["oc2"] != "#fff" else "#7a1a2a"
	match L["hat"]:
		"beret":
			s += '<ellipse cx="-8" cy="%s" rx="%s" ry="17" fill="#7a1a2a"/><circle cx="-8" cy="%s" r="4" fill="#7a1a2a"/>' % [n(-ry + 2), n(rx + 12), n(-ry - 15)]
		"top":
			s += '<rect x="-34" y="%s" width="68" height="62" rx="4" fill="#161616"/><rect x="%s" y="%s" width="%s" height="11" rx="5" fill="#161616"/><rect x="-34" y="%s" width="68" height="10" fill="#8a1a2a"/>' % [n(-ry - 64), n(-rx - 14), n(-ry - 6), n(rx * 2 + 28), n(-ry - 22)]
		"cap":
			s += '<path d="M%s %s Q%s %s 0 %s Q%s %s %s %s Z" fill="#c4402a"/><path d="M%s %s L%s %s Q%s %s %s %s Z" fill="#8a2a1a"/>' % [n(-rx - 2), n(-ry * 0.32), n(-rx), n(-ry - 8), n(-ry - 8), n(rx), n(-ry - 8), n(rx + 2), n(-ry * 0.32), n(rx * 0.1), n(-ry * 0.34), n(rx + 36), n(-ry * 0.28), n(rx + 30), n(-ry * 0.14), n(rx * 0.1), n(-ry * 0.2)]
		"fedora":
			s += '<path d="M%s %s Q0 %s %s %s Q%s %s %s %s L%s %s Q0 %s %s %s L%s %s Q%s %s %s %s Z" fill="#2a2a2a"/>' % [n(-rx - 22), n(-ry * 0.42), n(-ry * 0.18), n(rx + 22), n(-ry * 0.42), n(rx + 8), n(-ry * 0.6), n(rx - 4), n(-ry * 0.6), n(rx - 10), n(-ry - 22), n(-ry - 36), n(-rx + 10), n(-ry - 22), n(-rx + 4), n(-ry * 0.6), n(-rx - 8), n(-ry * 0.6), n(-rx - 22), n(-ry * 0.42)]
			s += '<path d="M%s %s L%s %s L%s %s L%s %s Z" fill="#8a2a2a"/>' % [n(-rx + 5), n(-ry * 0.64), n(rx - 5), n(-ry * 0.64), n(rx - 6), n(-ry * 0.8), n(-rx + 6), n(-ry * 0.8)]
		"beanie":
			s += '<path d="M%s %s Q%s %s 0 %s Q%s %s %s %s Z" fill="%s"/><rect x="%s" y="%s" width="%s" height="14" rx="6" fill="%s"/><circle cy="%s" r="8" fill="%s"/>' % [n(-rx - 3), n(-ry * 0.3), n(-rx - 2), n(-ry - 18), n(-ry - 18), n(rx + 2), n(-ry - 18), n(rx + 3), n(-ry * 0.3), hat2, n(-rx - 5), n(-ry * 0.44), n(rx * 2 + 10), hat2, n(-ry - 20), hat2]
		"headband":
			s += '<rect x="%s" y="%s" width="%s" height="11" rx="4" fill="#d9483a"/>' % [n(-rx - 1), n(-ry * 0.64), n(rx * 2 + 2)]
	if acc.has("sweat") or mood == "angry":
		s += '<path d="M%s -30 Q%s -16 %s -9 Q%s -16 %s -30 Z" fill="#7cc7f0" stroke="#3a8ab0" stroke-width="1.5"/>' % [n(rx - 4), n(rx + 3), n(rx - 4), n(rx - 11), n(rx - 4)]
	return s


static func _front_hair(hair: int, rx: float, ry: float, hc: String) -> String:
	match hair:
		0:
			return '<path d="M%s -4 Q%s %s 0 %s Q%s %s %s -4 Q%s %s 0 %s Q%s %s %s -4 Z" fill="%s"/>' % [n(-rx - 1), n(-rx - 3), n(-ry - 9), n(-ry - 9), n(rx + 3), n(-ry - 9), n(rx + 1), n(rx * 0.8), n(-ry * 0.56), n(-ry * 0.62), n(-rx * 0.8), n(-ry * 0.56), n(-rx - 1), hc]
		1:
			return '<path d="M%s 6 Q%s %s 0 %s Q%s %s %s 6 Q%s %s %s %s Q%s %s %s 6 Z" fill="%s"/>' % [n(-rx - 3), n(-rx - 5), n(-ry - 11), n(-ry - 11), n(rx + 5), n(-ry - 11), n(rx + 3), n(rx * 0.7), n(-ry * 0.72), n(rx * 0.05), n(-ry * 0.5), n(-rx * 0.55), n(-ry * 0.42), n(-rx - 3), hc]
		2:
			return '<path d="M%s 8 Q%s -18 %s -28 L%s 8 Z M%s 8 Q%s -18 %s -28 L%s 8 Z" fill="%s"/><ellipse cx="-10" cy="%s" rx="12" ry="5" fill="#fff" opacity=".35"/>' % [n(-rx - 2), n(-rx - 4), n(-rx + 8), n(-rx + 7), n(rx + 2), n(rx + 4), n(rx - 8), n(rx - 7), hc, n(-ry * 0.7)]
		3:
			var s := ""
			for i in 9:
				var a := PI * (1.02 + i * 0.12)
				s += '<circle cx="%s" cy="%s" r="15" fill="%s"/>' % [n(cos(a) * rx), n(sin(a) * ry * 0.95 - 4), hc]
			return s
		4:
			return '<path d="M%s -2 L%s %s L%s %s L%s %s L0 %s L%s %s L%s %s L%s %s L%s -2 Q0 %s %s -2 Z" fill="%s"/>' % [n(-rx), n(-rx + 4), n(-ry - 4), n(-rx * 0.5), n(-ry * 0.8), n(-rx * 0.3), n(-ry - 15), n(-ry * 0.75), n(rx * 0.3), n(-ry - 17), n(rx * 0.5), n(-ry * 0.8), n(rx - 4), n(-ry - 4), n(rx), n(-ry * 0.6), n(-rx), hc]
		5:
			return '<circle cx="0" cy="%s" r="19" fill="%s"/><path d="M-14 %s L14 %s" stroke="#a0522d" stroke-width="3"/><path d="M%s -2 Q%s %s 0 %s Q%s %s %s -2 Q%s %s 0 %s Q%s %s %s -2 Z" fill="%s"/>' % [n(-ry - 14), hc, n(-ry - 24), n(-ry - 4), n(-rx - 1), n(-rx - 2), n(-ry - 6), n(-ry - 6), n(rx + 2), n(-ry - 6), n(rx + 1), n(rx * 0.7), n(-ry * 0.6), n(-ry * 0.74), n(-rx * 0.7), n(-ry * 0.6), n(-rx - 1), hc]
		6:
			return '<path d="M%s %s Q%s %s 0 %s Q%s %s %s %s L%s -12 Q0 %s %s -12 Z" fill="%s"/>' % [n(-rx - 7), n(ry * 0.25), n(-rx - 9), n(-ry - 9), n(-ry - 9), n(rx + 9), n(-ry - 9), n(rx + 7), n(ry * 0.25), n(rx - 3), n(-ry * 0.46), n(-rx + 3), hc]
		7:
			return '<path d="M%s -2 Q%s %s %s %s Q%s %s %s %s Q%s -10 %s -2 Q%s %s 0 %s Q%s %s %s -2 Z" fill="%s"/>' % [n(-rx), n(-rx - 4), n(-ry - 4), n(-rx * 0.2), n(-ry - 24), n(rx * 0.7), n(-ry - 32), n(rx + 5), n(-ry - 6), n(rx + 2), n(rx), n(rx * 0.6), n(-ry * 0.6), n(-ry * 0.62), n(-rx * 0.6), n(-ry * 0.6), n(-rx), hc]
		8:
			return '<path d="M%s -4 Q%s %s 0 %s Q%s %s %s -4 Q%s %s %s %s Q%s %s %s -4 Z" fill="%s"/><circle cx="%s" cy="%s" r="5" fill="#e05a8a"/>' % [n(-rx - 1), n(-rx - 3), n(-ry - 9), n(-ry - 9), n(rx + 3), n(-ry - 9), n(rx + 1), n(rx * 0.75), n(-ry * 0.5), n(rx * 0.1), n(-ry * 0.62), n(-rx * 0.8), n(-ry * 0.5), n(-rx - 1), hc, n(rx - 2), n(-ry * 0.45)]
		9:
			return '<path d="M%s -8 Q%s %s 0 %s Q%s %s %s -8 Q%s %s 0 %s Q%s %s %s -8 Z" fill="%s" opacity=".6"/>' % [n(-rx), n(-rx - 1), n(-ry - 4), n(-ry - 4), n(rx + 1), n(-ry - 4), n(rx), n(rx * 0.8), n(-ry * 0.66), n(-ry * 0.72), n(-rx * 0.8), n(-ry * 0.66), n(-rx), hc]
	return ""


static func _outfit(L: Dictionary, w: float, T: float, B: float) -> String:
	var o: String = L["oc2"]
	match L["outfit"]:
		"suit":
			return '<path d="M%s %s L0 %s L%s %s Z" fill="#f4f1ea"/><path d="M%s %s L%s %s L%s %s Z M%s %s L%s %s L%s %s Z" fill="#000" opacity=".25"/><path d="M-6 %s L6 %s L4 %s L9 %s L0 %s L-9 %s L-4 %s Z" fill="%s"/>' % [n(-w * 0.32), n(T - 4), n(T + 74), n(w * 0.32), n(T - 4), n(-w * 0.42), n(T - 4), n(-w * 0.05), n(T + 74), n(-w * 0.3), n(T + 14), n(w * 0.42), n(T - 4), n(w * 0.05), n(T + 74), n(w * 0.3), n(T + 14), n(T), n(T), n(T + 10), n(T + 52), n(T + 64), n(T + 52), n(T + 10), o]
		"hoodie":
			return '<path d="M%s %s Q0 %s %s %s Q0 %s %s %s Z" fill="#000" opacity=".2"/><rect x="%s" y="%s" width="%s" height="42" rx="12" fill="#000" opacity=".1"/>' % [n(-w * 0.6), n(T + 8), n(T - 32), n(w * 0.6), n(T + 8), n(T + 28), n(-w * 0.6), n(T + 8), n(-w * 0.48), n(B - 62), n(w * 0.96)]
		"apron":
			return '<path d="M%s %s L%s %s L%s %s L%s %s Z" fill="%s"/><path d="M%s %s L%s %s M%s %s L%s %s" stroke="%s" stroke-width="7"/>' % [n(-w * 0.52), n(T + 28), n(w * 0.52), n(T + 28), n(w * 0.58), n(B), n(-w * 0.58), n(B), o, n(-w * 0.4), n(T + 28), n(-w * 0.2), n(T - 3), n(w * 0.4), n(T + 28), n(w * 0.2), n(T - 3), o]
		"coat":
			var s := '<path d="M%s %s L-6 %s L%s %s Z M%s %s L6 %s L%s %s Z" fill="#000" opacity=".22"/><path d="M0 %s L0 %s" stroke="#000" stroke-opacity=".25" stroke-width="2"/><rect x="%s" y="%s" width="%s" height="12" fill="%s"/>' % [n(-w * 0.44), n(T - 6), n(T + 38), n(-w * 0.55), n(T + 34), n(w * 0.44), n(T - 6), n(T + 38), n(w * 0.55), n(T + 34), n(T + 30), n(B), n(-w), n(T + 108), n(w * 2), o]
			for i in 3:
				s += '<circle cx="-12" cy="%s" r="4" fill="#000" opacity=".35"/><circle cx="12" cy="%s" r="4" fill="#000" opacity=".35"/>' % [n(T + 56 + i * 26), n(T + 56 + i * 26)]
			return s
		"cardigan":
			var s := '<path d="M%s %s L%s %s L%s %s L%s %s Z" fill="%s"/>' % [n(-w * 0.24), n(T - 4), n(w * 0.24), n(T - 4), n(w * 0.22), n(B), n(-w * 0.22), n(B), o]
			for i in 4:
				s += '<circle cx="%s" cy="%s" r="4" fill="#f4efe6"/>' % [n(-w * 0.24 - 6), n(T + 30 + i * 32)]
			return s
		"hanbok":
			return '<path d="M%s %s L%s %s" stroke="#f6f1e6" stroke-width="10"/><path d="M%s %s Q%s %s %s %s M%s %s Q%s %s %s %s" stroke="%s" stroke-width="9" fill="none" stroke-linecap="round"/>' % [n(-w * 0.35), n(T - 4), n(w * 0.12), n(T + 56), n(w * 0.12), n(T + 54), n(w * 0.3), n(T + 70), n(w * 0.18), n(T + 130), n(w * 0.12), n(T + 54), n(w * 0.05), n(T + 80), n(w * 0.08), n(T + 118), o]
		"track":
			return '<path d="M0 %s L0 %s" stroke="#fff" stroke-width="3"/><path d="M%s %s L%s %s M%s %s L%s %s" stroke="#fff" stroke-width="6"/>' % [n(T), n(B), n(-w + 8), n(T + 28), n(-w + 10), n(B - 30), n(w - 8), n(T + 28), n(w - 10), n(B - 30)]
		"tee":
			return '<circle cx="0" cy="%s" r="20" fill="%s" opacity=".85"/>' % [n(T + 62), o]
	return ""


## SVG 문자열 → 텍스처. viewbox: [x, y, w, h], scale: 픽셀 배율
static func rasterize(body: String, viewbox: Array, scale: float) -> ImageTexture:
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="%s %s %s %s">%s</svg>' % [int(viewbox[2]), int(viewbox[3]), n(viewbox[0]), n(viewbox[1]), n(viewbox[2]), n(viewbox[3]), body]
	var img := Image.new()
	var err := img.load_svg_from_string(svg, scale)
	if err != OK:
		push_error("SVG 래스터화 실패: %d" % err)
		img = Image.create(4, 4, false, Image.FORMAT_RGBA8)
	return ImageTexture.create_from_image(img)


## 캐릭터 전신 텍스처 (머리 중심 기준 viewBox -110,-130 220,355)
const CHAR_VB := [-110, -130, 220, 355]


const STAND_VB := [-110, -130, 220, 470]


static func char_texture(L: Dictionary, mood: String, scale: float) -> ImageTexture:
	return rasterize(draw_char(L, mood), CHAR_VB, scale)
