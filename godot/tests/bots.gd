extends RefCounted
## 자동 플레이 봇. 30일 시뮬레이션으로 규칙 위반·밸런스를 점검한다.
##   random: 아무 버튼이나 누르는 플레이어 (불변식 검사용)
##   smart:  추정가를 보고 싸게 사서 비싸게 파는 플레이어 (수익성 검사용)
##   growth: smart 흥정 + 의심품 정밀 감정·살림/장비 구매 (별도 진단 정책)

var g  # GameState
var rng := RandomNumberGenerator.new()
var style := "random"
var errors: Array = []
var max_days := 30


func _init(state, p_style: String, seed_value: int) -> void:
	g = state
	style = p_style
	rng.seed = seed_value


func check_invariants(where: String) -> void:
	if g.inv.size() > g.cap():
		errors.append("%s: 창고 초과 %d/%d" % [where, g.inv.size(), g.cap()])
	for it in g.inv:
		if int(it["r"]) < 0 or int(it["r"]) > 3 or int(it["c"]) < 0 or int(it["c"]) > 4:
			errors.append("%s: 물건 등급/상태 범위 오류" % where)
	if not g.phase in ["morning", "visit", "open", "night"]:
		errors.append("%s: 알 수 없는 단계 %s" % [where, g.phase])
	if g.phase == "open" and g.cur.is_empty():
		errors.append("%s: 영업 중인데 손님 없음" % where)


## 하루를 끝까지 진행한다. 파산하면 false.
func play_day() -> bool:
	var guard := 0
	# 평판에 따라 손님이 늘어도 정상 영업을 무한 루프로 오인하지 않는다.
	var step_limit := day_step_limit()
	while g.phase != "night" and guard < step_limit:
		guard += 1
		step()
		check_invariants("%d일차" % g.day)
	if g.phase != "night":
		errors.append("%d일차: 진단 행동 한도 %d회 초과 phase=%s cur=%s stage=%s gone=%s queue=%d" % [g.day, step_limit, g.phase, g.cur.get("name", "-"), g.cur.get("stage", "-"), g.cur.get("gone", "-"), g.queue])
		return false
	_evening()
	return g.next_day()


func day_step_limit() -> int:
	return 2000 + maxi(g.queue, int(g.rep / 25)) * 40


func step() -> void:
	match g.phase:
		"morning":
			if style == "growth":
				_prepare_growth()
			if g.is_auction_today() and (style == "random" and rng.randf() < 0.5 or style != "random" and g.money > 3000):
				_play_auction()
			g.flip_open()
		"visit":
			if g.cur["gone"]:
				g.open_shop()
			else:
				g.visit_pick(rng.randi_range(0, g.cur["opts"].size() - 1) if style == "random" else (1 if g.cur["vk"] == "insurance" and g.has_staff("guard") else 0))
		"open":
			if g.cur["gone"]:
				g.next_customer()
			elif style == "random":
				_random_haggle()
			else:
				_smart_haggle()


func _play_auction() -> void:
	if not g.start_auction():
		return
	var guard := 0
	while not g.auction.is_empty() and guard < 200:
		guard += 1
		if g.auction["over"]:
			g.auction_next()
			continue
		var it: Dictionary = g.lot()
		var lo: int = g.est(it, not g.has_staff("expert"))[0]
		if style == "random":
			if rng.randf() < 0.6:
				g.auction_bid()
			else:
				g.auction_pass()
		elif g.next_bid_price() < lo * 0.7 and not it["suspect"] and g.money > g.next_bid_price() + 1500:
			g.auction_bid()
		else:
			g.auction_pass()


func _random_haggle() -> void:
	var r := rng.randf()
	var their: int = g.their_price()
	if r < 0.08:
		g.accept()
	elif r < 0.14:
		g.refuse()
	elif r < 0.2:
		g.propose(int(their * rng.randf_range(0.3, 1.5)), true)
	elif r < 0.25:
		g.accuse()
	elif r < 0.28:
		var it: Dictionary = g.cur_item()
		if not it.is_empty():
			g.appraise(it["id"])
	else:
		g.propose(int(their * rng.randf_range(0.2, 1.8)))
	if g.is_haggling() and g.neg.rounds > 25:
		g.refuse()


func _smart_haggle() -> void:
	var it: Dictionary = g.cur_item()
	if style == "growth":
		if g.has_staff("expert") and not it["known"]:
			if g.cur.get("stage", "") != "haggle":
				g.start_haggle()
			g.use_special("expert")
			return
		if it["known"] and it["fake"]:
			g.refuse()
			return
	var e: Array = g.est(it)
	var lo: int = e[0]
	var hi: int = e[1]
	var mid := (lo + hi) / 2.0
	if not g.cur["buy"]:
		if g.inv.size() >= g.cap():
			g.refuse()
			return
		if it["suspect"] and not g.cur["accused"]:
			g.accuse()
			return
		var target: float = mid * 0.8 if not (it["known"] and it["fake"]) else g.val(it, false) * 0.9
		if g.cur.get("pawn", false):
			target = mid * 0.55
		if style == "growth":
			var reserve := maxi(3000, (int(g.shop_info()["rent"]) + g.wages()) * 7)
			# 준비금 아래에서도 싼 물건을 사고팔 수 있게 현금 35%까지는 운용한다.
			target = minf(target, maxf(0.0, maxf(g.money * 0.35, g.money - reserve)))
		if g.neg.ask <= target:
			if g.money >= g.neg.ask:
				g.accept()
			else:
				g.refuse()
			return
		var x := int(target * (0.8 + 0.05 * g.neg.rounds))
		if g.neg.rounds > 6 or x > target or g.money < x:
			g.refuse()
			return
		g.propose(maxi(10, x))
	else:
		var floor_price := maxf(float(it["paid"]) * 1.1, lo * 0.9)
		if g.neg.offer >= hi * 0.95 or (g.neg.rounds > 5 and g.neg.offer >= floor_price):
			g.accept()
			return
		if g.neg.rounds > 7:
			g.refuse()
			return
		var y := int(hi * (1.1 - 0.06 * g.neg.rounds))
		g.propose(maxi(int(floor_price), y))


func _evening() -> void:
	if style == "random":
		if rng.randf() < 0.3 and g.sp > 0:
			g.skill_up(["haggle", "appraise", "psych", "charm"][rng.randi_range(0, 3)])
		if rng.randf() < 0.2:
			g.hire(["expert", "restorer", "profiler", "analyst", "clerk", "guard"][rng.randi_range(0, 5)])
		if rng.randf() < 0.1 and g.inv.size() > 0:
			g.dump(g.inv[0]["id"])
		if rng.randf() < 0.2:
			g.expand()
		if rng.randf() < 0.2:
			g.move_shop()
		if rng.randf() < 0.05:
			g.buy_belong(["alley", "cart", "market", "canal"][rng.randi_range(0, 3)])
		if rng.randf() < 0.05 and not g.owned.is_empty():
			g.sell_belong(g.owned[0])
		return
	while g.sp > 0:
		var order := ["appraise", "haggle", "charm", "psych"]
		var done := false
		for k in order:
			if g.skill_up(k):
				done = true
				break
		if not done:
			break
	if g.money < 2500:
		for k in ["clerk", "restorer", "expert"]:
			if g.has_staff(k):
				g.fire(k)
				break
	if g.money > 6000 and not g.has_staff("expert"):
		g.hire("expert")
	if g.money > 12000 and not g.has_staff("restorer"):
		g.hire("restorer")
	if g.money > 20000 and not g.has_staff("clerk"):
		g.hire("clerk")
	for it in g.inv.duplicate():
		if it["known"] and it["fake"]:
			g.dump(it["id"])
		elif g.has_staff("restorer") and int(it["c"]) < 3 and g.money > g.restore_cost(it) + 2000:
			g.restore(it["id"])
	if g.inv.size() >= g.cap() and g.inv.size() > 0:
		g.dump(g.inv[0]["id"])
	while not g.next_up_step().is_empty() and g.money > int(g.next_up_step()["cost"]) + 3000:
		g.expand()
	if g.shop + 1 < g.D.shops.size() and g.money > int(g.D.shops[g.shop + 1]["cost"]) + 4000:
		g.move_shop()


## 게임 규칙이 아닌 진단용 구매 정책. 7일 고정비와 최소 운전자금 3천 냥을 남긴다.
## 살림 한 번의 순지출은 남는 현금의 30%까지. 실제 사용자 선호를 뜻하지 않는다.
func _prepare_growth() -> void:
	var reserve := maxi(3000, (int(g.shop_info()["rent"]) + g.wages()) * 7)
	for it in g.inv.duplicate():
		g.inspect(it)
		if it["suspect"] and not it["known"] and g.money > g.appr_fee(it) + reserve:
			g.appraise(it["id"])
		if it["known"] and it["fake"] and not g.is_pawned(it):
			g.dump(it["id"])
	for k in ["lens", "censer", "shelf"]:
		var cost: int = g.equip_cost(k)
		if cost > 0 and g.money > reserve + cost * 3:
			g.equip_up(k)
	# 각 분류에서 한 단계씩, 순서대로 장만한다. 집은 옛 집 환급액을 뺀 순지출로 비교.
	for cat in ["home", "ride", "ship"]:
		var level: int = g.home_lv() if cat == "home" else g.best_lv(cat)
		for b in g.D.belong[cat]:
			if int(b["lv"]) != level + 1:
				continue
			var cost: int = int(b["cost"]) - (g.resale(g.home) if cat == "home" else 0)
			if cost <= int(maxi(0, g.money - reserve) * 0.3):
				g.buy_belong(b["id"])
			break


## 순자산 = 현금 + 재고(가치의 절반) + 가게 이전에 투자한 금액
func net_worth() -> float:
	var w := float(g.money)
	for i in range(0, g.shop + 1):
		w += float(g.D.shops[i]["cost"])
		var ups: Array = g.D.shops[i].get("ups", [])
		for j in (ups.size() if i < g.shop else mini(g.shop_up, ups.size())):
			w += float(ups[j]["cost"])
	for it in g.inv:
		w += g.val(it, false) * 0.5
	return w
