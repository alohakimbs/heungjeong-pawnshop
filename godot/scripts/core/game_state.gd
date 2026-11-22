class_name GameState
extends RefCounted
## 게임 한 판의 전체 상태와 규칙. 화면과 분리되어 있어 헤드리스 테스트·자동 플레이가 가능하다.
## 웹 프로토타입 v0.2의 로직을 이식했다. 화면은 이 객체의 값을 읽고 메서드를 호출하기만 한다.

const Negotiation := preload("res://scripts/core/negotiation.gd")
const SAVE_VERSION := 1
const SAVE_PATH := "user://save.json"

var D  # GameData: items, shops, staff, traits, specials, text, archetypes, events, lines
var rng := RandomNumberGenerator.new()

var money := 5000
var day := 1
var rep := 0
var xp := 0
var lv := 1
var sp := 0
var skills := {"haggle": 0, "appraise": 0, "psych": 0, "charm": 0}
var shop := 0
var inv: Array = []
var staff: Array = []
var trend: Dictionary = {}
var next_up := ""
var scams: Array = []
var phase := "morning"  # morning(아침) → visit(불청객) → open(영업) → night(마감)
var queue := 0
var cur: Dictionary = {}  # 지금 카운터 앞의 손님(또는 불청객). 없으면 빈 딕셔너리
var neg: Negotiation = null
var today: Dictionary = {}
var nid := 1
var auction_day := 3
var auction_done := false
var event := ""
var news: Dictionary = {}
var won := false
var stats := {"deals": 0, "profit": 0}
var rel: Dictionary = {}  # 단골 관계: {키: {visits, last}}
var receipt: Dictionary = {}
var auction: Dictionary = {}
var upcoming: Array = []  # 대기 줄에 서 있는 다음 손님들의 정체
var history: Array = []  # 날마다의 정산 기록 (통계용)
var collection: Dictionary = {}  # 도감: "종류/이름" → 가져 본 최고 희귀도
var col_done: Array = []  # 완성한 종류(카테고리)
var draft := 0  # 계산기에 찍힌 금액
var plan_buy := 0  # 오늘 남은 사러 올 손님
var plan_sell := 0  # 오늘 남은 팔러(맡기러) 올 손님
var later: Array = []  # 「나중에」로 미룬 손님: [{cur, neg}]
var story_seen: Array = []  # 본 이야기 장면 id
var trip_day := 0  # 마지막으로 나들이한 날
var journal: Array = []  # 견문록: 가 본 곳 id
var trip_offer: Dictionary = {}  # 나들이에서 만난 살 수 있는 물건
var messages: Array = []  # 화면이 토스트로 띄울 메시지 큐


func _init(data, seed_value: int = 0) -> void:
	D = data
	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()


# ---------------------------------------------------------------- 도우미
func pick(a: Array):
	return a[rng.randi_range(0, a.size() - 1)]


func rnd(a: float, b: float) -> float:
	return rng.randf_range(a, b)


static func r10(n: float) -> int:
	return maxi(10, int(round(n / 10.0)) * 10)


static func fmt(n: float) -> String:
	var s := str(int(round(absf(n))))
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if n < 0 else "") + out + "냥"


func toast(m: String) -> void:
	messages.append(m)


## 오늘 장부에 금액을 더한다 (통계용)
func book(key: String, amount: int) -> void:
	today[key] = int(today.get(key, 0)) + amount


func line(key: String, price: int = -1, item: String = "") -> String:
	var v = D.lines.get(key, "")
	var s: String = pick(v) if v is Array else str(v)
	return s.replace("{price}", fmt(price)).replace("{item}", item).replace("{days}", str(cur.get("days", 3)))


func tic() -> String:
	var t: Array = cur.get("tic", [""])
	return pick(t) if t.size() > 0 else ""


func has_staff(k: String) -> bool:
	return staff.has(k)


func shop_info() -> Dictionary:
	return D.shops[shop]


func cap() -> int:
	return int(shop_info()["st"])


func trend_of(cat: String) -> float:
	return float(trend.get(cat, 1.0))


# ---------------------------------------------------------------- 물건
func val(it: Dictionary, genuine := false) -> float:
	var rar: Array = D.items["rarity"]
	var con: Array = D.items["condition"]
	var f := 0.08 if (it["fake"] and not genuine) else 1.0
	return float(it["base"]) * float(rar[int(it["r"])]["m"]) * float(con[int(it["c"])]["m"]) * trend_of(it["cat"]) * f


func est_w() -> float:
	return maxf(0.06, 0.55 - skills["appraise"] * 0.07 - (0.2 if has_staff("expert") else 0.0))


## 추정가 [하한, 상한]. 실제 가치(진품 기준)는 항상 이 범위 안에 있다.
func est(it: Dictionary, wide := false) -> Array:
	var g := val(it, true)
	var w := est_w() * (1.5 if wide else 1.0)
	var u := float(it["u"])
	return [r10(g * (1.0 - w * u)), r10(g * (1.0 + w * (1.0 - u)))]


func appr_fee(it: Dictionary) -> int:
	return r10(maxf(30.0, val(it, true) * 0.05))


func inspect(it: Dictionary) -> void:
	var lvl := 2 if has_staff("expert") else 1
	if int(it.get("chk", 0)) >= lvl:
		return
	it["chk"] = lvl
	var p: float = (0.75 + skills["appraise"] * 0.05) if has_staff("expert") else skills["appraise"] * 0.08
	if it["fake"]:
		it["suspect"] = rng.randf() < p
	else:
		it["suspect"] = has_staff("expert") and rng.randf() < 0.03


func gen_item(fake_p := 0.1, boost := 0) -> Dictionary:
	var cats: Dictionary = D.items["categories"]
	var ck: String = pick(cats.keys())
	var t: Array = pick(cats[ck]["items"])
	var l := shop + boost
	var w := [maxf(1, 62 - l * 6), maxf(1, 26 + l * 2), maxf(1, 9 + l * 3), maxf(1, 3 + l * 1.5)]
	var total := 0.0
	for x in w:
		total += x
	var roll := rng.randf() * total
	var r := 0
	while r < 3 and roll > w[r]:
		roll -= w[r]
		r += 1
	var it := {
		"id": nid, "cat": ck, "name": t[0], "e": t[1],
		"base": int(round(float(t[2]) * rnd(0.8, 1.25) * (1.0 + shop * 0.15))),
		"r": r, "c": pick([0, 1, 1, 2, 2, 2, 3, 3, 4]), "fake": rng.randf() < fake_p, "u": rng.randf(),
		"paid": 0, "known": false, "suspect": false, "chk": 0, "restoring": false,
	}
	nid += 1
	return it


## 도감에 기록. 종류(카테고리)의 물건을 모두 모으면 보상.
func collect(it: Dictionary) -> void:
	var key := "%s/%s" % [it["cat"], it["name"]]
	var first := not collection.has(key)
	collection[key] = maxi(int(collection.get(key, -1)), int(it["r"]))
	if first:
		toast("도감에 새 물건: %s" % it["name"])
	var cat: String = it["cat"]
	if col_done.has(cat):
		return
	for t in D.items["categories"][cat]["items"]:
		if not collection.has("%s/%s" % [cat, t[0]]):
			return
	col_done.append(cat)
	var bonus := 500 * (shop + 1)
	money += bonus
	rep += 5
	book("prize", bonus)
	toast("도감 완성: %s! 은하 골동 동호회 상금 %s, 평판 +5" % [D.items["categories"][cat]["n"], fmt(bonus)])


func collection_total() -> int:
	var n := 0
	for k in D.items["categories"]:
		n += D.items["categories"][k]["items"].size()
	return n


func find_item(id) -> Dictionary:
	for i in inv:
		if int(i["id"]) == int(id):
			return i
	if not cur.is_empty() and cur.has("item") and int(cur["item"]["id"]) == int(id):
		return cur["item"]
	return {}


func remove_item(id) -> void:
	for n in inv.size():
		if int(inv[n]["id"]) == int(id):
			inv.remove_at(n)
			return


# ---------------------------------------------------------------- 손님
func _conflicts(k: String, tr: Array) -> bool:
	for pair in D.traits["conflicts"]:
		if pair.has(k):
			for q in pair:
				if q != k and tr.has(q):
					return true
	return false


## 손님의 정체(이름·외형·성향·단골 여부)만 만든다. 대기 줄에 미리 세워 두는 데 쓴다.
func _gen_identity() -> Dictionary:
	if not today.has("sp"):
		today["sp"] = []
	var spk := ""
	if rng.randf() < 0.24:
		var ks: Array = D.specials.keys().filter(func(k): return not today["sp"].has(k))
		if ks.size() > 0:
			spk = pick(ks)
			today["sp"].append(spk)
	if spk != "":
		var spd: Dictionary = D.specials[spk]
		return {"name": spd["n"], "role": spd["role"], "tic": spd["tic"], "look": spd["L"], "sk": spk, "tr": spd["tr"].duplicate()}
	var keys: Array = D.traits["traits"].keys()
	var tr: Array = []
	var n := 1 if rng.randf() < 0.55 else 2
	var guard := 0
	while tr.size() < n and guard < 50:
		guard += 1
		var k: String = pick(keys)
		if tr.has(k) or _conflicts(k, tr):
			continue
		tr.append(k)
	# 그림이 아직 없는 종족(needs_art)은 그림 파일이 들어올 때까지 나오지 않는다
	var pool: Array = D.archetypes.filter(func(a): return not a.get("needs_art", false) or ResourceLoader.exists("res://assets/chars/%s_ok.png" % a["id"]))
	var ar: Dictionary = pick(pool)
	return {"name": pick(D.text["surnames"]) + pick(D.text["given_names"]), "role": ar["n"], "tic": ar["tic"], "arch": ar["id"], "look_seed": rng.randi(), "sk": "", "tr": tr}


## 대기 줄(다음 손님들)을 남은 인원만큼, 최대 2명까지 채운다
func _fill_upcoming() -> void:
	while upcoming.size() < mini(2, queue):
		upcoming.append(_gen_identity())


func is_pawned(it: Dictionary) -> bool:
	return it.has("pawn") and not it["pawn"].is_empty()


func gen_customer() -> Dictionary:
	var avail := inv.filter(func(i): return not i["restoring"] and not is_pawned(i))
	var ident: Dictionary = upcoming.pop_front() if upcoming.size() > 0 else _gen_identity()
	var tr: Array = ident["tr"]
	var spk: String = ident.get("sk", "")
	var spd: Dictionary = D.specials[spk] if spk != "" else {}
	var sell_only: bool = tr.has("scammer") or tr.has("desperate")
	# 창고가 찰수록 사러 오는 손님이 늘어난다 (빈 창고 35% → 꽉 찬 창고 75%)
	var tot := plan_buy + plan_sell
	var buy_p := float(plan_buy) / tot if tot > 0 else 0.35 + 0.4 * float(inv.size()) / cap()
	var buy: bool = (not sell_only) and avail.size() > 0 and rng.randf() < buy_p
	var c := ident.duplicate(true)
	c["stage"] = "intro"
	c["tr"] = tr
	if buy:
		plan_buy = maxi(0, plan_buy - 1)
	elif plan_sell > 0:
		plan_sell -= 1
	else:
		plan_buy = maxi(0, plan_buy - 1)
	c["buy"] = buy
	var shown := tr.size() if (has_staff("profiler") or skills["psych"] >= 3) else (1 if skills["psych"] >= 1 else 0)
	c["seen"] = tr.slice(0, shown)
	c["gone"] = false
	c["res"] = ""
	c["accused"] = false
	c["mood"] = "ok"
	var intro := ""
	var min_adj := 1.0
	var pat_mul := 1.0
	if spk != "":
		var r: Dictionary = rel.get(spk, {})
		var last: String = r.get("last", "")
		if last != "" and spd["cb"].has(last):
			intro = spd["cb"][last] + " "
			match last:
				"fair":
					pat_mul = 1.25
				"steal", "angry":
					pat_mul = 0.8
					min_adj = 1.1
				"scam":
					pat_mul = 0.6
					min_adj = 1.2
		else:
			intro = spd["hi"] + " "
	cur = c
	neg = Negotiation.new(rng)
	# 전당포 의뢰인: 물건을 맡기고 돈을 빌린다 (사기꾼은 맡기지 않는다)
	var pawn: bool = not buy and not tr.has("scammer") and rng.randf() < 0.18
	if pawn:
		c["pawn"] = true
		c["days"] = rng.randi_range(3, 6)
		var it := gen_item(0.05)
		c["item"] = it
		var per := val(it, true) * (0.6 if tr.has("naive") else 1.0) * rnd(0.85, 1.15)
		neg.setup_seller(per * 0.62, tr, skills["haggle"], skills["charm"], min_adj)
		c["msg"] = intro + line("pawn_open", -1, it["name"]) + tic()
		c["price_msg"] = line("pawn_price", neg.ask)
		draft = r10(neg.ask * 0.6)
	elif not buy:
		var it := gen_item(0.5 if tr.has("scammer") else 0.1)
		c["item"] = it
		var per := val(it, true) * (0.6 if tr.has("naive") else 1.0) * (rnd(0.95, 1.05) if tr.has("expert") else rnd(0.8, 1.2))
		neg.setup_seller(per, tr, skills["haggle"], skills["charm"], min_adj)
		var m := ""
		if tr.has("scammer"):
			m = line("sell_scammer", -1, it["name"])
		elif tr.has("desperate"):
			m = line("sell_desperate", -1, it["name"])
		elif tr.has("greedy"):
			m = line("sell_greedy", -1, it["name"])
		else:
			m = line("sell_open", -1, it["name"])
		c["msg"] = intro + m + tic()
		var pm := line("sell_price", neg.ask)
		if tr.has("chatty"):
			pm += line("sell_chatty", r10(neg.min_price * rnd(1.0, 1.12)))
		c["price_msg"] = pm
		draft = r10(neg.ask * 0.55)
	else:
		var it: Dictionary = pick(avail)
		c["item_id"] = it["id"]
		if it["fake"] and tr.has("expert"):
			c["fake_call"] = true
			c["mood"] = "angry"
			c["msg"] = intro + line("buy_fake_spotted", -1, it["name"])
			neg.setup_buyer(10.0, 0, tr)
		else:
			neg.setup_buyer(val(it, true), int(it["r"]), tr, skills["haggle"], skills["charm"], min_adj)
			var m := ""
			if tr.has("collector") and int(it["r"]) >= 2:
				m = line("buy_collector", -1, it["name"])
			elif tr.has("stingy"):
				m = line("buy_stingy", -1, it["name"])
			else:
				m = line("buy_open", -1, it["name"])
			c["msg"] = intro + m + tic()
			var pm := line("buy_price", neg.offer)
			if tr.has("chatty"):
				pm += line("buy_chatty", r10(neg.max_price * rnd(0.88, 1.0)))
			c["price_msg"] = pm
			draft = r10(neg.offer * 1.6)
	neg.max_patience = round(neg.max_patience * pat_mul)
	neg.patience = neg.max_patience
	return c


func cur_item() -> Dictionary:
	if cur.is_empty() or cur.get("visitor", false):
		return {}
	if cur["buy"]:
		for i in inv:
			if int(i["id"]) == int(cur["item_id"]):
				return i
		return {}
	return cur["item"]


func is_haggling() -> bool:
	return phase == "open" and not cur.is_empty() and not cur.get("visitor", false) and not cur["gone"]


func mood() -> String:
	if cur.is_empty():
		return "ok"
	if cur["gone"] or cur.get("visitor", false) or neg == null:
		return cur.get("mood", "ok")
	var m := neg.patience_ratio()
	return "ok" if m > 0.66 else ("meh" if m > 0.33 else "angry")


func their_price() -> int:
	return neg.their_price() if neg != null else 0


# ---------------------------------------------------------------- 흥정 행동
func propose(x: int, final := false) -> void:
	if not is_haggling():
		return
	if x <= 0:
		toast("계산기에 금액을 먼저 찍으세요")
		return
	if not cur["buy"] and inv.size() >= cap():
		toast("창고가 가득 찼어요")
		return
	cur["stage"] = "haggle"
	var r := neg.propose(x, final)
	var b := "buy" if cur["buy"] else "sell"
	match r:
		Negotiation.Result.DEAL:
			if cur["buy"]:
				_deal_buy(neg.deal_price)
			else:
				_deal_sell(neg.deal_price)
		Negotiation.Result.LEAVE_ANGRY:
			_leave(line("gave_up") if neg.line == "gave_up" else line(neg.line + "_" + b), true)
		_:
			match neg.line:
				"repeat":
					cur["msg"] = line("repeat_" + b)
				"counter":
					cur["msg"] = line("counter_" + b, neg.their_price())
				"low":
					cur["msg"] = line("low_" + b) + line("low_" + b + "_tail", neg.their_price())
			if rng.randf() < 0.35:
				cur["msg"] += tic()


## 원작 흐름: 인사(intro) → 물건 살펴보기(look) → 흥정(haggle)
func look_item() -> void:
	if not is_haggling() or cur.get("stage", "haggle") != "intro":
		return
	cur["stage"] = "look"
	cur["msg"] = line("ask_look_pawn" if cur.get("pawn", false) else ("ask_look_buy" if cur["buy"] else "ask_look_sell"))


func start_haggle() -> void:
	if not is_haggling() or cur.get("stage", "haggle") == "haggle":
		return
	cur["stage"] = "haggle"
	cur["msg"] = cur.get("price_msg", "")


## 스킬·직원·평판 조건부 특수 선택지 (손님 한 명당 각각 한 번). [id, 표시 문구]
func special_options() -> Array:
	var out: Array = []
	if not is_haggling() or cur.get("stage", "") != "haggle":
		return out
	var used: Array = cur.get("used", [])
	if skills["charm"] >= 2 and not used.has("persuade"):
		out.append(["persuade", "[화술 %d] 조금만 더 맞춰 주세요, 단골 될게요." % skills["charm"]])
	if skills["psych"] >= 2 and not used.has("read"):
		out.append(["read", "[심리 %d] (표정을 읽는다)" % skills["psych"]])
	if rep >= 30 and not used.has("fame"):
		out.append(["fame", "[평판 %d] 우리 가게 소문 들으셨죠?" % rep])
	var it := cur_item()
	if has_staff("expert") and not it.is_empty() and not it["known"] and not used.has("expert"):
		out.append(["expert", "[감정사] 영감님, 이것 좀 봐 주세요."])
	return out


func use_special(id: String) -> void:
	if not is_haggling():
		return
	var used: Array = cur.get("used", [])
	if used.has(id):
		return
	used.append(id)
	cur["used"] = used
	match id:
		"persuade":
			var p: float = 0.6 + 0.1 * skills["charm"]
			if rng.randf() < p:
				if cur["buy"]:
					neg.offer = mini(neg.max_price, r10(neg.offer + (neg.max_price - neg.offer) * 0.35))
					cur["msg"] = "하하, 말씀 잘하시네. 그럼 %s까지 낼게요." % fmt(neg.offer)
				else:
					neg.ask = maxi(neg.min_price, r10(neg.ask - (neg.ask - neg.min_price) * 0.35))
					cur["msg"] = "단골이라... 좋아요, %s까지 해 드리죠." % fmt(neg.ask)
				neg.patience -= 5
			else:
				neg.patience -= 15
				cur["msg"] = "말로 넘어갈 생각 마세요."
		"read":
			var floor_v: int = neg.max_price if cur["buy"] else neg.min_price
			var lo := r10(floor_v * rnd(0.88, 0.97))
			var hi := r10(floor_v * rnd(1.03, 1.12))
			cur["read"] = [lo, hi]
			cur["msg"] = "(눈빛을 보니 %s 사이에서 결정할 것 같다)" % ("%s~%s" % [fmt(lo), fmt(hi)])
		"fame":
			neg.patience = minf(neg.max_patience, neg.patience + 30)
			cur["msg"] = "아, 그 유명한 가게! 천천히 이야기해 봐요."
		"expert":
			var it := cur_item()
			it["known"] = true
			cur["msg"] = "(감정사가 돋보기를 들이댄다) %s" % ("...가짜군." if it["fake"] else "진품이야. 견적은 %s 정도." % fmt(val(it, false)))
	if neg.patience <= 0:
		_leave(line("gave_up"), true)


func accept() -> void:
	if not is_haggling():
		return
	if cur["buy"]:
		_deal_buy(neg.offer)
	else:
		_deal_sell(neg.ask)


# ---------------------------------------------------------------- 운경 나들이
## 아침마다 한 번, 부상열차를 타고 운경 한 곳에 다녀온다. 결과 문장을 돌려준다(빈 문자열이면 못 감).
func can_trip() -> bool:
	return phase == "morning" and trip_day != day


func trip(id: String) -> String:
	if not can_trip() or not D.trips.has(id):
		return ""
	var t: Dictionary = D.trips[id]
	var fare := int(t["fare"])
	if money < fare:
		toast("운임이 모자라요")
		return ""
	money -= fare
	book("fees", fare)
	trip_day = day
	trip_offer = {}
	var first := not journal.has(id)
	if first:
		journal.append(id)
		xp += 10
	var out := ""
	match id:
		"market":
			var it := gen_item(0.3)
			trip_offer = {"item": it, "price": r10(val(it, true) * rnd(0.45, 0.75))}
			out = "좌판 할아범이 「%s」을(를) 떨이로 내놓았다. 진짜인지는 장담 못 한다나." % it["name"]
		"ring":
			var it2 := gen_item(0.05, 2)
			trip_offer = {"item": it2, "price": r10(val(it2, true) * rnd(0.85, 1.05))}
			out = "막 닿은 상선에서 낯선 「%s」이(가) 나왔다. 귀하지만 값도 만만치 않다." % it2["name"]
		"workshop":
			var worst: Dictionary = {}
			for i in inv:
				if not is_pawned(i) and int(i["c"]) < 4 and (worst.is_empty() or int(i["c"]) < int(worst["c"])):
					worst = i
			if worst.is_empty():
				out = "장인이 창고를 둘러보더니 「고칠 게 없구먼」 하고 웃었다."
			else:
				var cost := r10(val(worst, true) * 0.06)
				if money >= cost:
					money -= cost
					book("fees", cost)
					worst["c"] = int(worst["c"]) + 1
					out = "장인이 「%s」의 옥 부품을 갈아 끼웠다. 상태가 「%s」(으)로 좋아졌다. 수리비 %s." % [worst["name"], D.items["condition"][int(worst["c"])]["n"], fmt(cost)]
				else:
					out = "고칠 물건은 있는데 수리비가 모자랐다."
		"dock":
			var cn: String = D.items["categories"][next_up]["n"] if D.items["categories"].has(next_up) else "?"
			out = "뱃사람들 말로는 내일 「%s」 쪽 물건이 귀해진단다. 미리 챙겨 두면 좋겠다." % cn
		"terrace":
			rep += 2
			out = "회랑 정원에서 단골들과 차를 마셨다. 소문이 좋게 퍼져 평판이 조금 올랐다."
	if first:
		out += "\n\n[견문록에 새로 적음] " + String(t["lore"])
	return out


## 나들이에서 만난 물건 사기
func trip_buy() -> bool:
	if trip_offer.is_empty():
		return false
	var price := int(trip_offer["price"])
	if money < price or inv.size() >= cap():
		toast("돈이나 창고 자리가 모자라요")
		return false
	var it: Dictionary = trip_offer["item"]
	money -= price
	it["paid"] = price
	inv.append(it)
	collect(it)
	book("bought", price)
	trip_offer = {}
	return true


# ---------------------------------------------------------------- 이야기
## 조건을 채운 다음 이야기 장면(아침에만). 없으면 "".
func story_due() -> String:
	if phase != "morning":
		return ""
	for b in D.story:
		if story_seen.has(b["id"]):
			continue
		var w: Dictionary = b["when"]
		if day >= int(w.get("day", 0)) and shop >= int(w.get("shop", 0)):
			return b["id"]
	return ""


func story_beat(id: String) -> Dictionary:
	for b in D.story:
		if b["id"] == id:
			return b
	return {}


## 장면을 봤다고 기록하고 보상을 준다. opt: 고른 선택지 번호(없으면 -1). 선택지의 결과 문장을 돌려준다.
func story_done(id: String, opt := -1) -> String:
	var b := story_beat(id)
	if b.is_empty() or story_seen.has(id):
		return ""
	story_seen.append(id)
	var rw: Dictionary = b.get("reward", {})
	var out := ""
	if opt >= 0 and b.has("opts"):
		rw = b["opts"][opt][2]
		out = b["opts"][opt][1]
		stats["story_" + id] = opt
	money += int(rw.get("money", 0))
	rep += int(rw.get("rep", 0))
	if b.get("ending", false):
		stats["ending"] = opt
	return out


## 오늘 남은 손님 수 (지금 손님 제외): [사러 올, 팔러 올]
func remaining() -> Array:
	var b := plan_buy
	var s2 := plan_sell
	for l in later:
		if l["cur"].get("buy", false):
			b += 1
		else:
			s2 += 1
	return [b, s2]


## 「나중에」: 손님을 줄 맨 뒤로 보낸다(손님당 한 번). 마감 전에 다시 온다.
func defer() -> void:
	if not is_haggling() or cur.get("deferred", false) or cur.get("stage", "") != "intro":
		return
	cur["deferred"] = true
	later.append({"cur": cur.duplicate(true), "neg": neg.to_dict()})
	cur["gone"] = true
	cur["mood"] = "ok"
	cur["msg"] = line("later")
	cur["res"] = "나중에 다시 옴"


func refuse() -> void:
	if not is_haggling():
		return
	_leave(line("refuse_buy" if cur["buy"] else "refuse_sell"), false)


func accuse() -> void:
	if not is_haggling() or cur["buy"] or cur["accused"]:
		return
	var it: Dictionary = cur["item"]
	cur["accused"] = true
	if it["fake"]:
		var f := val(it, false)
		neg.ask = r10(f * rnd(1.6, 2.6))
		neg.min_price = r10(f * 0.8)
		neg.last = -1
		neg.patience -= 10
		cur["msg"] = line("accuse_fake_scammer" if cur["tr"].has("scammer") else "accuse_fake", neg.ask)
		it["known"] = true
		draft = neg.min_price
	else:
		neg.patience -= 40 * (1.4 if cur["tr"].has("expert") else 1.0)
		cur["msg"] = line("accuse_wrong")
		if neg.patience <= 0:
			_leave(line("accuse_wrong_leave"), true)


func gain_xp(n: float) -> void:
	var g := int(round(n))
	xp += g
	today["xp"] = int(today.get("xp", 0)) + g
	while xp >= lv * 120:
		xp -= lv * 120
		lv += 1
		sp += 1
		toast("레벨 업! Lv.%d · 스킬 포인트 +1" % lv)


func _rel_note(outcome: String) -> void:
	var k: String = cur.get("sk", "")
	if k == "":
		return
	var r: Dictionary = rel.get(k, {"visits": 0})
	r["visits"] = int(r["visits"]) + 1
	r["last"] = outcome
	rel[k] = r


func _deal_sell(x: int) -> void:
	var it: Dictionary = cur["item"]
	if money < x:
		toast("금고에 돈이 부족해요")
		return
	if inv.size() >= cap():
		toast("창고가 가득 찼어요")
		return
	money -= x
	it["paid"] = x
	inv.append(it)
	collect(it)
	if cur.get("pawn", false):
		var days: int = cur["days"]
		it["pawn"] = {"due": day + days, "repay": pawn_repay(x, days), "owner": cur["name"]}
		today["lent"] = int(today.get("lent", 0)) + x
		stats["lent"] = int(stats.get("lent", 0)) + x
		today["deals"] += 1
		stats["deals"] += 1
		rep += 1
		_rel_note("fair")
		gain_xp(8 + neg.rounds * 2)
		_finish("happy", line("deal_pawn") + tic(), "%s 대출 · %d일차까지 %s 상환 예정" % [fmt(x), day + days, fmt(it["pawn"]["repay"])])
		return
	today["bought"] += x
	today["deals"] += 1
	stats["deals"] += 1
	rep += 1
	_rel_note("steal" if x < val(it, true) * 0.75 else "fair")
	gain_xp(8 + neg.rounds * 2 + clampf((val(it, false) - x) / 40.0, 0, 40))
	_finish("happy", line("deal_sell") + tic(), "%s에 매입" % fmt(x))


## 상환액 = 대출금 × (1 + 10% + 하루 3%)
static func pawn_repay(loan: int, days: int) -> int:
	return r10(loan * (1.1 + 0.03 * days))


func _deal_buy(x: int) -> void:
	var it := cur_item()
	if it.is_empty():
		return
	money += x
	remove_item(it["id"])
	today["sold"] += x
	today["deals"] += 1
	stats["deals"] += 1
	stats["profit"] += x - int(it["paid"])
	rep += 1
	if it["fake"]:
		# 알고 판 가품(감정으로 확인했거나 의심 표시가 있던 것)만 벌금 대상. 모르고 판 것은 환불로 끝난다.
		scams.append({"day": day, "price": x, "name": it["name"], "knew": bool(it["known"] or it["suspect"])})
	_rel_note("scam" if it["fake"] else ("steal" if x > val(it, true) * 1.25 else "fair"))
	gain_xp(8 + neg.rounds * 2 + clampf((x - int(it["paid"])) / 40.0, 0, 40))
	var d := x - int(it["paid"])
	_finish("happy", line("deal_buy") + tic(), "%s에 판매 (%s %s)" % [fmt(x), "이익" if d >= 0 else "손해", fmt(absi(d))])


func _leave(msg: String, angry: bool) -> void:
	if angry:
		rep = maxi(0, rep - 2)
		_rel_note("angry")
	_finish("angry" if angry else "meh", msg, "화내며 떠남 · 평판 -2" if angry else "손님이 돌아감")


func _finish(md: String, msg: String, res: String) -> void:
	cur["gone"] = true
	cur["mood"] = md
	cur["msg"] = msg
	cur["res"] = res


# ---------------------------------------------------------------- 창고·직원·성장
func appraise(id) -> bool:
	var it := find_item(id)
	if it.is_empty() or it["known"]:
		return false
	var fee := appr_fee(it)
	if money < fee:
		toast("감정비가 부족해요")
		return false
	money -= fee
	book("fees", fee)
	it["known"] = true
	toast("정밀 감정 완료 (%s)" % fmt(fee))
	return true


func restore_cost(it: Dictionary) -> int:
	return r10(val(it, true) * 0.12)


func restore(id) -> bool:
	var it := find_item(id)
	if it.is_empty() or not has_staff("restorer") or int(it["c"]) >= 4 or it["restoring"] or is_pawned(it):
		return false
	var c := restore_cost(it)
	if money < c:
		toast("돈이 부족해요")
		return false
	money -= c
	book("fees", c)
	it["restoring"] = true
	toast("내일 아침까지 수리됩니다")
	return true


func dump(id) -> bool:
	var it := find_item(id)
	if it.is_empty() or it["restoring"]:
		return false
	if is_pawned(it):
		toast("맡아 둔 물건은 기한 전엔 처분할 수 없어요")
		return false
	if is_haggling() and cur["buy"] and int(cur["item_id"]) == int(id):
		toast("손님이 보고 있는 물건이에요")
		return false
	var p := r10(val(it, false) * 0.5)
	money += p
	book("sold", p)
	stats["profit"] += p - int(it["paid"])
	remove_item(id)
	toast("도매상: \"%s? %s 드리죠.\"" % [it["name"], fmt(p)])
	return true


func staff_slots() -> int:
	return 1 + shop


func hire(k: String) -> bool:
	if has_staff(k) or staff.size() >= staff_slots() or not D.staff.has(k):
		return false
	staff.append(k)
	toast("%s: %s" % [D.staff[k]["pn"], D.staff[k]["q"]])
	return true


func fire(k: String) -> bool:
	if not has_staff(k):
		return false
	staff.erase(k)
	return true


func skill_up(k: String) -> bool:
	if sp <= 0 or not skills.has(k) or skills[k] >= 5:
		return false
	sp -= 1
	skills[k] += 1
	return true


func can_move() -> bool:
	return shop + 1 < D.shops.size() and money >= int(D.shops[shop + 1]["cost"])


func move_shop() -> bool:
	if not can_move():
		return false
	money -= int(D.shops[shop + 1]["cost"])
	shop += 1
	if shop == D.shops.size() - 1:
		won = true
	toast("%s(으)로 이전!" % shop_info()["n"])
	return true


# ---------------------------------------------------------------- 하루 흐름
func start_day() -> void:
	today = {"bought": 0, "sold": 0, "deals": 0, "xp": 0, "bonus": 0, "start": money, "sp": []}
	var keys: Array = D.items["categories"].keys()
	var t := {}
	for k in keys:
		t[k] = 1.0 + (trend_of(k) - 1.0) * 0.4
	var up: String = next_up if next_up != "" else pick(keys)
	var dn: String = pick(keys)
	while dn == up:
		dn = pick(keys)
	t[up] *= rnd(1.25, 1.5)
	t[dn] *= rnd(0.65, 0.8)
	trend = t
	next_up = pick(keys)
	var small: Array = D.text["small_news"]
	var a: int = rng.randi_range(0, small.size() - 1)
	var b: int = (a + rng.randi_range(1, small.size() - 1)) % small.size()
	news = {"head": pick(D.text["headlines"]), "sub": [small[a], small[b]], "up": up, "dn": dn, "tip": (day - 1) % maxi(1, D.tips.size())}
	if day > auction_day:
		auction_day = day + rng.randi_range(2, 4)
	auction_done = false
	var ev: Array = []
	for k in D.events:
		if money > int(D.events[k].get("min_money", -999999)):
			ev.append(k)
	event = pick(ev) if (day > 1 and rng.randf() < 0.35 and ev.size() > 0) else ""
	phase = "morning"
	cur = {}
	neg = null
	receipt = {}
	upcoming = []


func is_auction_today() -> bool:
	return day == auction_day and not auction_done and phase == "morning"


## 아침에 팻말을 뒤집는다. 불청객 이벤트가 있으면 먼저 등장한다.
func flip_open() -> void:
	if phase != "morning":
		return
	if event != "":
		var e: Dictionary = D.events[event]
		var look = D.specials[e["look_special"]]["L"] if e.has("look_special") else e.get("look", {})
		cur = {"visitor": true, "vk": event, "name": e["n"], "role": "불청객", "look": look, "msg": e["d"], "opts": e["opts"], "tr": [], "seen": [], "gone": false, "mood": "ok", "sk": "", "art": String(e.get("art", ""))}
		neg = null
		event = ""
		phase = "visit"
		return
	open_shop()


## 불청객 선택 결과. 결과는 events.json의 res[선택][갈래]에 데이터로 적는다.
## 갈래 조건: staff(직원 있음), inv_full(창고 가득), p(확률). 조건이 맞는 첫 갈래를 쓴다.
## 효과: money, money_pct, book, rep, bonus, xp, item, buy_item(값 비율), fake_p, fix_item.
func visit_pick(i: int) -> void:
	if phase != "visit" or cur.is_empty() or cur["gone"]:
		return
	var e: Dictionary = D.events.get(cur["vk"], {})
	var res: Array = e.get("res", [])
	var branches: Array = res[i] if i < res.size() else []
	var md := "ok"
	var txt := ""
	for b in branches:
		if b.has("staff") and not has_staff(b["staff"]):
			continue
		if b.get("inv_full", false) and inv.size() < cap():
			continue
		if b.has("p") and rng.randf() >= float(b["p"]):
			continue
		var r := _visit_apply(b)
		if r.is_empty():
			continue
		md = r["md"]
		txt = r["t"]
		break
	cur["mood"] = md
	cur["msg"] = txt if txt != "" else "..."
	cur["gone"] = true


## 갈래 하나의 효과를 적용한다. 적용할 수 없으면(돈·고칠 물건 부족) 빈 사전.
func _visit_apply(b: Dictionary) -> Dictionary:
	var f := 0
	var item_name := ""
	var cond := ""
	if b.get("fix_item", false):
		var cands := inv.filter(func(x): return int(x["c"]) < 4 and not x["restoring"] and not is_pawned(x))
		if cands.is_empty() or money < -int(b.get("money", 0)):
			return {}
		var it: Dictionary = pick(cands)
		it["c"] = int(it["c"]) + 1
		item_name = it["name"]
		cond = D.items["condition"][int(it["c"])]["n"]
	if b.has("buy_item"):
		var it := gen_item(float(b.get("fake_p", 0.0)))
		f = r10(val(it, true) * float(b["buy_item"]))
		if money < f:
			return {"md": "meh", "t": "돈이 모자라시구려. 다음에 오지요."}
		money -= f
		book("bought", f)
		it["paid"] = f
		inv.append(it)
		collect(it)
		item_name = it["name"]
	if b.get("item", false):
		var it := gen_item(0.0)
		inv.append(it)
		collect(it)
		item_name = it["name"]
	if b.has("money"):
		f = absi(int(b["money"]))
		money += int(b["money"])
		book(b.get("book", "penalty" if int(b["money"]) < 0 else "prize"), f)
	if b.has("money_pct"):
		f = r10(money * absf(float(b["money_pct"])))
		money -= f
		book(b.get("book", "penalty"), f)
	if b.has("rep"):
		rep = maxi(0, rep + int(b["rep"]))
	if b.has("bonus"):
		today["bonus"] = int(today.get("bonus", 0)) + int(b["bonus"])
	if b.has("xp"):
		gain_xp(float(b["xp"]))
	var t: String = b.get("t", "")
	t = t.replace("{f}", fmt(f)).replace("{item}", item_name).replace("{cond}", cond)
	t = t.replace("{next}", D.items["categories"][next_up]["n"] if D.items["categories"].has(next_up) else "?")
	return {"md": b.get("md", "ok"), "t": t}


func open_shop() -> void:
	phase = "open"
	queue = maxi(2, int(shop_info()["cust"]) + (2 if has_staff("clerk") else 0) + rep / 25 + int(today.get("bonus", 0)))
	plan_buy = int(round(queue * rnd(0.35, 0.5)))
	plan_sell = queue - plan_buy
	later = []
	next_customer()


func next_customer() -> void:
	if phase != "open":
		return
	if queue <= 0:
		if later.size() > 0:
			var l: Dictionary = later.pop_front()
			cur = l["cur"]
			neg = Negotiation.new(rng)
			neg.from_dict(l["neg"])
			cur["msg"] = line("back_buy" if cur["buy"] else "back_sell") + " " + String(cur.get("price_msg", ""))
			cur["stage"] = "intro"
			return
		close_shop()
		return
	queue -= 1
	cur = gen_customer()
	_fill_upcoming()
	if cur.get("fake_call", false):
		rep = maxi(0, rep - 3)
		cur["gone"] = true
		cur["res"] = "가품을 들킴 · 평판 -3"


func wages() -> int:
	var w := 0
	for k in staff:
		w += int(D.staff[k]["w"])
	return w


func close_shop() -> void:
	phase = "night"
	cur = {}
	neg = null
	var sh := shop_info()
	var wg := wages()
	money -= int(sh["rent"]) + wg
	var notes: Array = []
	for it in inv:
		if it["restoring"]:
			it["restoring"] = false
			var up := 2 if rng.randf() < 0.2 else 1
			it["c"] = mini(4, int(it["c"]) + up)
			notes.append("수리 완료: %s → %s" % [it["name"], D.items["condition"][int(it["c"])]["n"]])
	# 맡긴 물건: 기한 안에 주인이 찾아가거나(상환), 기한이 지나면 내 것이 된다
	for it in inv.duplicate():
		if not is_pawned(it):
			continue
		var pw: Dictionary = it["pawn"]
		var left := int(pw["due"]) - day
		if left >= 0 and rng.randf() < (0.55 if left == 0 else 0.22):
			money += int(pw["repay"])
			today["repaid"] = int(today.get("repaid", 0)) + int(pw["repay"])
			stats["profit"] += int(pw["repay"]) - int(it["paid"])
			remove_item(it["id"])
			notes.append("%s님이 맡긴 %s을(를) 찾아감: 상환 %s" % [pw["owner"], it["name"], fmt(pw["repay"])])
		elif left < 0:
			it["pawn"] = {}
			collect(it)
			notes.append("%s님이 기한까지 오지 않아 %s은(는) 이제 내 것!" % [pw["owner"], it["name"]])
	var stealable := inv.filter(func(i): return not is_pawned(i))
	if not has_staff("guard") and stealable.size() > 0 and rng.randf() < 0.12:
		var it: Dictionary = pick(stealable)
		remove_item(it["id"])
		notes.append("밤도둑이 %s을(를) 훔쳐 감!" % it["name"])
	var keep: Array = []
	for sc in scams:
		if rng.randf() < 0.3:
			if sc.get("knew", true):
				var f := r10(sc["price"] * 1.5)
				money -= f
				book("penalty", f)
				rep = maxi(0, rep - 8)
				notes.append("가품 판매 신고(%s): 벌금 %s, 평판 -8" % [sc["name"], fmt(f)])
			else:
				var refund := r10(int(sc["price"]) * 0.5)
				money -= refund
				book("penalty", refund)
				rep = maxi(0, rep - 3)
				notes.append("손님이 가품이라며 항의(%s): 절반 환불 %s로 합의, 평판 -3" % [sc["name"], fmt(refund)])
		elif day - int(sc["day"]) < 5:
			keep.append(sc)
	scams = keep
	# 빚이 생기면 파산 전에 도매상이 재고를 가져가 메운다 (싼 물건부터, 가치의 절반)
	if money < 0 and inv.size() > 0:
		var order := inv.filter(func(i): return not is_pawned(i))
		order.sort_custom(func(a, b): return val(a, false) < val(b, false))
		var taken: Array = []
		for it in order:
			if money >= 0:
				break
			var p := r10(val(it, false) * 0.5)
			money += p
			book("sold", p)
			stats["profit"] += p - int(it["paid"])
			remove_item(it["id"])
			taken.append(it["name"])
		if not taken.is_empty():
			notes.append("빚 독촉: 도매상이 %s을(를) 헐값에 가져감" % ", ".join(taken))
	receipt = {"day": day, "deals": today["deals"], "bought": today["bought"], "sold": today["sold"], "rent": int(sh["rent"]), "shop": sh["n"], "wages": wg, "lent": int(today.get("lent", 0)), "repaid": int(today.get("repaid", 0)), "d": money - int(today["start"]), "xp": today.get("xp", 0), "notes": notes}
	var h := {"day": day, "rent": int(sh["rent"]), "wages": wg}
	for k in ["bought", "sold", "lent", "repaid", "fees", "penalty", "prize", "deals"]:
		h[k] = int(today.get(k, 0))
	h["cash"] = money - int(today["start"])
	history.append(h)
	if history.size() > 400:
		history.pop_front()


## 파산선: 차고 -3,000냥, 가게 단계마다 2,000냥씩 더 버틴다
func bankrupt_line() -> int:
	return -3000 - 2000 * shop


func is_bankrupt() -> bool:
	return money < bankrupt_line()


## 다음 날 아침으로. 파산이면 false.
func next_day() -> bool:
	if phase != "night":
		return true
	if is_bankrupt():
		return false
	_finalize_history()
	day += 1
	start_day()
	return true


# ---------------------------------------------------------------- 경매
func auction_fee() -> int:
	return 100 * (shop + 1)


func start_auction() -> bool:
	if not is_auction_today():
		return false
	if money < auction_fee():
		toast("참가비가 부족해요")
		return false
	money -= auction_fee()
	book("fees", auction_fee())
	auction_done = true
	auction = {"lots": [gen_item(0.12, 2), gen_item(0.12, 2), gen_item(0.12, 2)], "i": 0}
	_start_lot()
	return true


func lot() -> Dictionary:
	return auction["lots"][auction["i"]] if not auction.is_empty() else {}


func _start_lot() -> void:
	var it := lot()
	inspect(it)
	var g := val(it, true)
	auction["price"] = r10(g * 0.25)
	auction["step"] = r10(maxf(10.0, g * 0.06))
	auction["leader"] = ""
	auction["over"] = false
	auction["res"] = ""
	var bids: Array = []
	for b in D.text["auction_npcs"]:
		bids.append({"n": b["n"], "max": g * rnd(0.45, 1.05)})
	auction["bid"] = bids
	auction["log"] = ["경매사: 시작가 %s!" % fmt(auction["price"])]


func next_bid_price() -> int:
	return int(auction["price"]) + (int(auction["step"]) if auction["leader"] != "" else 0)


func auction_bid() -> void:
	if auction.is_empty() or auction["over"]:
		return
	var np := next_bid_price()
	if money < np:
		toast("돈이 부족해요")
		return
	if inv.size() >= cap():
		toast("창고가 가득 찼어요")
		return
	auction["price"] = np
	auction["leader"] = "me"
	auction["log"].push_front("나: %s" % fmt(np))
	var cands := (auction["bid"] as Array).filter(func(b): return b["max"] >= np + int(auction["step"]))
	if cands.size() > 0 and rng.randf() < 0.9:
		var b: Dictionary = pick(cands)
		auction["price"] = np + int(auction["step"])
		auction["leader"] = b["n"]
		auction["log"].push_front("%s: %s!" % [b["n"], fmt(auction["price"])])
	else:
		_end_lot()


func auction_pass() -> void:
	if auction.is_empty() or auction["over"] or auction["leader"] == "me":
		return
	_end_lot()


func _end_lot() -> void:
	var it := lot()
	auction["over"] = true
	var price: int = int(auction["price"])
	if auction["leader"] == "me":
		money -= price
		it["paid"] = price
		inv.append(it)
		collect(it)
		book("bought", price)
		gain_xp(15)
		auction["res"] = "낙찰! %s을(를) %s에 손에 넣었습니다." % [it["name"], fmt(price)]
	elif auction["leader"] != "":
		auction["res"] = "%s에게 %s에 낙찰." % [auction["leader"], fmt(price)]
	else:
		var best = null
		for b in auction["bid"]:
			if b["max"] >= price and (best == null or b["max"] > best["max"]):
				best = b
		auction["res"] = ("%s에게 %s에 낙찰." % [best["n"], fmt(price)]) if best != null else "아무도 입찰하지 않아 유찰."


## 다음 물건으로. 마지막이었으면 경매를 끝내고 false.
func auction_next() -> bool:
	auction["i"] += 1
	if auction["i"] >= auction["lots"].size():
		auction = {}
		return false
	_start_lot()
	return true


# ---------------------------------------------------------------- 저장
const FIELDS := ["money", "day", "rep", "xp", "lv", "sp", "skills", "shop", "inv", "staff", "trend", "next_up", "scams", "phase", "queue", "cur", "today", "nid", "auction_day", "auction_done", "event", "news", "won", "stats", "rel", "receipt", "draft", "upcoming", "history", "collection", "col_done", "plan_buy", "plan_sell", "later", "story_seen", "trip_day", "journal", "trip_offer"]
const INT_FIELDS := ["money", "day", "rep", "xp", "lv", "sp", "shop", "queue", "nid", "auction_day", "draft", "plan_buy", "plan_sell", "trip_day"]


func to_dict() -> Dictionary:
	var d := {"v": SAVE_VERSION}
	for k in FIELDS:
		d[k] = get(k)
	d["neg"] = neg.to_dict() if neg != null else null
	return d


func from_dict(d: Dictionary) -> void:
	for k in FIELDS:
		if d.has(k):
			set(k, int(d[k]) if k in INT_FIELDS else d[k])
	for k in skills:
		skills[k] = int(skills[k])
	if d.get("neg") != null:
		neg = Negotiation.new(rng)
		neg.from_dict(d["neg"])
	else:
		neg = null
	auction = {}


func save_game(path := SAVE_PATH) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(to_dict()))
	return true


func load_game(path := SAVE_PATH) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var f := FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	if not parsed is Dictionary or int(parsed.get("v", 0)) != SAVE_VERSION:
		return false
	from_dict(parsed)
	return true



## 마감 뒤(밤)에 생긴 거래(도매 처분 등)까지 그날 기록에 반영
func _finalize_history() -> void:
	if history.is_empty() or int(history[-1]["day"]) != day:
		return
	var h: Dictionary = history[-1]
	for k in ["bought", "sold", "lent", "repaid", "fees", "penalty", "prize", "deals"]:
		h[k] = int(today.get(k, 0))
	h["cash"] = money - int(today["start"])


## 통계: 최근 n일 합계 (n=0이면 전체)
func stats_sum(n: int = 0) -> Dictionary:
	var out := {}
	var rows: Array = history if n == 0 else history.slice(maxi(0, history.size() - n))
	for h in rows:
		for k in h:
			if k != "day":
				out[k] = int(out.get(k, 0)) + int(h[k])
	out["days"] = rows.size()
	return out
