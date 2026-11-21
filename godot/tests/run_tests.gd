extends SceneTree
## 헤드리스 테스트 러너.
## 실행: godot --headless --path godot -s res://tests/run_tests.gd
## 실패가 하나라도 있으면 종료 코드 1 (CI에서 빌드를 막는다).

const Negotiation := preload("res://scripts/core/negotiation.gd")
const GameDataScript := preload("res://scripts/core/game_data.gd")
const GameState := preload("res://scripts/core/game_state.gd")
const Bots := preload("res://tests/bots.gd")

var data

var passed := 0
var failed := 0


func _init() -> void:
	data = GameDataScript.new()
	for scr in [GameState, Bots, Negotiation]:
		if not scr.can_instantiate():
			print("✗ 스크립트 컴파일 실패: ", scr.resource_path)
			quit(1)
			return
	test_data_files()
	test_offer_at_ask_deals()
	test_seller_never_below_min()
	test_buyer_never_above_max()
	test_lowball_eventually_leaves()
	test_proud_leaves_on_insult()
	test_final_offer()
	test_repeat_offer_costs_patience()
	test_day_cycle()
	test_estimate_contains_value()
	test_save_roundtrip()
	test_regular_remembers()
	test_sim_random()
	test_sim_smart()
	data.free()
	print("\n결과: %d 통과, %d 실패" % [passed, failed])
	quit(1 if failed > 0 else 0)


func check(cond: bool, name: String) -> void:
	if cond:
		passed += 1
		print("  ✓ ", name)
	else:
		failed += 1
		print("  ✗ 실패: ", name)


func make(seed_value: int) -> Negotiation:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return Negotiation.new(rng)


func test_data_files() -> void:
	print("[데이터]")
	var gd = GameDataScript.new()
	var cats: Dictionary = gd.items.get("categories", {})
	var n_items := 0
	for k in cats:
		n_items += cats[k]["items"].size()
	check(cats.size() == 8, "카테고리 8개")
	check(n_items >= 40, "물건 40종 이상 (%d)" % n_items)
	check(gd.shops.size() == 5, "가게 5단계")
	check(gd.specials.size() == 8, "단골 8명")
	check(gd.traits.get("traits", {}).size() == 12, "성향 12종")
	gd.free()


func test_offer_at_ask_deals() -> void:
	print("[요구가 이상 제시 → 즉시 거래]")
	var n := make(1)
	n.setup_seller(1000, [])
	check(n.propose(n.ask) == Negotiation.Result.DEAL, "판매 손님: 요구가 그대로 제시하면 거래")
	var b := make(2)
	b.setup_buyer(1000, 0, [])
	check(b.propose(b.offer) == Negotiation.Result.DEAL, "구매 손님: 제시가 그대로 부르면 거래")


func test_seller_never_below_min() -> void:
	print("[속성: 판매 손님은 마지노선 아래로 절대 안 판다]")
	var ok := true
	var deals := 0
	var all_traits := ["greedy", "naive", "hasty", "calm", "expert", "proud", "desperate", "scammer", "chatty"]
	for s in 3000:
		var n := make(s)
		var tr := [all_traits[s % all_traits.size()]] if s % 3 else []
		n.setup_seller(200 + (s % 50) * 137, tr, s % 6, s % 6)
		var floor_price := n.min_price
		var x := int(n.ask * n.rng.randf_range(0.2, 0.7))
		for i in 30:
			var r := n.propose(x, n.rng.randf() < 0.05)
			if r == Negotiation.Result.DEAL:
				deals += 1
				if n.deal_price < floor_price:
					ok = false
				break
			if r == Negotiation.Result.LEAVE_ANGRY:
				break
			check_ask_floor(n, floor_price)
			x = int(x + (n.ask - x) * n.rng.randf_range(0.1, 0.6)) + 10
	check(ok, "3000회 흥정 중 마지노선 이하 거래 0건")
	check(deals > 300, "거래도 충분히 성사됨 (%d건)" % deals)


var _floor_ok := true
func check_ask_floor(n: Negotiation, floor_price: int) -> void:
	if n.ask < floor_price and _floor_ok:
		_floor_ok = false
		check(false, "요구가가 마지노선 아래로 내려감")


func test_buyer_never_above_max() -> void:
	print("[속성: 구매 손님은 최대 지불액 위로 절대 안 산다]")
	var ok := true
	var deals := 0
	for s in 3000:
		var n := make(10000 + s)
		var tr := [["rich", "stingy", "collector", "naive", "expert", "proud", "hasty", "calm"][s % 8]]
		n.setup_buyer(150 + (s % 40) * 211, s % 4, tr, s % 6, s % 6)
		var ceiling := n.max_price
		var y := int(n.offer * n.rng.randf_range(1.4, 3.0))
		for i in 30:
			var r := n.propose(y, n.rng.randf() < 0.05)
			if r == Negotiation.Result.DEAL:
				deals += 1
				if n.deal_price > ceiling:
					ok = false
				break
			if r == Negotiation.Result.LEAVE_ANGRY:
				break
			if n.offer > ceiling:
				ok = false
			y = maxi(n.offer, int(y - (y - n.offer) * n.rng.randf_range(0.1, 0.6)) - 10)
	check(ok, "3000회 흥정 중 최대 지불액 초과 거래 0건")
	check(deals > 300, "거래도 충분히 성사됨 (%d건)" % deals)


func test_lowball_eventually_leaves() -> void:
	print("[헐값만 부르면 결국 떠난다]")
	var n := make(7)
	n.setup_seller(2000, ["calm"])
	var r := Negotiation.Result.CONTINUE
	var x := 100
	var steps := 0
	while r == Negotiation.Result.CONTINUE and steps < 50:
		r = n.propose(x)
		x += 10
		steps += 1
	check(r == Negotiation.Result.LEAVE_ANGRY, "느긋한 손님도 결국 화내고 떠남 (%d번째)" % steps)
	var h := make(8)
	h.setup_seller(2000, ["hasty"])
	var hs := 0
	r = Negotiation.Result.CONTINUE
	x = 100
	while r == Negotiation.Result.CONTINUE and hs < 50:
		r = h.propose(x)
		x += 10
		hs += 1
	check(hs < steps, "성급한 손님이 더 빨리 떠남 (%d < %d)" % [hs, steps])


func test_proud_leaves_on_insult() -> void:
	print("[자존심 손님]")
	var n := make(3)
	n.setup_seller(1000, ["proud"])
	check(n.propose(int(n.min_price * 0.3)) == Negotiation.Result.LEAVE_ANGRY and n.line == "insulted", "마지노선 45% 미만 제시 → 즉시 퇴장")


func test_final_offer() -> void:
	print("[최종 제안]")
	var n := make(4)
	n.setup_seller(1000, [])
	check(n.propose(n.min_price, true) == Negotiation.Result.DEAL, "마지노선 이상 최종 제안 → 거래")
	var m := make(5)
	m.setup_seller(1000, [])
	check(m.propose(m.min_price - 10, true) == Negotiation.Result.LEAVE_ANGRY, "마지노선 미만 최종 제안 → 퇴장")


func test_repeat_offer_costs_patience() -> void:
	print("[같은 가격 반복]")
	var n := make(6)
	n.setup_seller(5000, ["calm"])
	var x := int(n.min_price * 0.5)
	n.propose(x)
	var before := n.patience
	n.propose(x)
	check(n.line == "repeat" and n.patience <= before - 15, "같은 가격 반복 시 인내심 15 이상 감소")


func new_game(seed_value: int):
	var g = GameState.new(data, seed_value)
	g.start_day()
	return g


func test_day_cycle() -> void:
	print("[하루 흐름]")
	var g = new_game(11)
	check(g.phase == "morning" and not g.news.is_empty(), "아침: 신문 생성")
	g.event = ""
	g.flip_open()
	check(g.phase == "open" and not g.cur.is_empty(), "문 열면 첫 손님 등장")
	var first_queue: int = g.queue
	g.refuse()
	check(g.cur["gone"], "거절하면 손님이 떠남")
	g.next_customer()
	check(g.queue == first_queue - 1, "다음 손님 호출 시 대기열 감소")
	while g.phase == "open":
		if not g.cur["gone"]:
			g.refuse()
		g.next_customer()
	check(g.phase == "night" and not g.receipt.is_empty(), "손님이 다 가면 마감 영수증")
	var before: int = g.money
	check(g.receipt["d"] == -int(g.shop_info()["rent"]), "거래 없는 날 현금 변화 = -임대료")
	check(g.next_day() and g.day == 2 and g.phase == "morning", "다음 날 아침으로")


func test_estimate_contains_value() -> void:
	print("[감정: 실제 가치는 항상 추정 범위 안]")
	var g = new_game(12)
	var ok := true
	for i in 2000:
		var it: Dictionary = g.gen_item(0.2)
		var e: Array = g.est(it)
		var v: float = g.val(it, true)
		if v < e[0] - 10 or v > e[1] + 10:
			ok = false
	check(ok, "2000개 물건 모두 추정 범위 안 (반올림 오차 $10 허용)")


func test_save_roundtrip() -> void:
	print("[저장/불러오기]")
	var g = new_game(13)
	g.event = ""
	g.flip_open()
	g.propose(int(g.their_price() * 0.5))
	var a := JSON.stringify(g.to_dict())
	var h = GameState.new(data, 99)
	h.from_dict(JSON.parse_string(a))
	var b := JSON.stringify(h.to_dict())
	check(JSON.parse_string(a) == JSON.parse_string(b), "저장 → 불러오기 → 저장 결과 동일")
	check(h.is_haggling() == g.is_haggling() and h.their_price() == g.their_price(), "흥정 중 상태도 복원")
	var path := "user://test_save.json"
	check(g.save_game(path) and h.load_game(path) and h.money == g.money, "파일 저장/불러오기")


func test_regular_remembers() -> void:
	print("[단골이 지난 거래를 기억]")
	var g = new_game(14)
	g.rel["pierre"] = {"visits": 1, "last": "angry"}
	var seen := false
	for i in 400:
		g.today["sp"] = []
		var c: Dictionary = g.gen_customer()
		if c.get("sk", "") == "pierre":
			seen = String(c["msg"]).begins_with(String(data.specials["pierre"]["cb"]["angry"]))
			break
	check(seen, "화내고 떠났던 단골이 그 일을 언급하며 재방문")


func test_sim_random() -> void:
	print("[자동 플레이: 무작위 봇 5명 × 30일]")
	var errs: Array = []
	var days := 0
	for s in 5:
		var g = new_game(100 + s)
		var bot = Bots.new(g, "random", 200 + s)
		for d in 30:
			days += 1
			if not bot.play_day():
				break
		errs.append_array(bot.errors)
	check(errs.is_empty(), "규칙 위반 0건 (%d일 진행)%s" % [days, "" if errs.is_empty() else " — " + str(errs.slice(0, 3))])


func test_sim_smart() -> void:
	print("[자동 플레이: 숙련 봇 8명 × 30일 — 밸런스]")
	var worths: Array = []
	var bankrupt := 0
	var errs: Array = []
	var shops: Array = []
	for s in 8:
		var g = new_game(300 + s)
		var bot = Bots.new(g, "smart", 400 + s)
		var alive := true
		for d in 30:
			if not bot.play_day():
				alive = false
				break
		if not alive:
			bankrupt += 1
		worths.append(int(bot.net_worth()))
		shops.append(g.shop)
		errs.append_array(bot.errors)
	worths.sort()
	print("    30일 후 순자산(현금+재고 절반): ", worths, " · 가게 단계: ", shops)
	check(errs.is_empty(), "규칙 위반 0건")
	check(bankrupt == 0, "숙련 플레이는 파산하지 않음 (파산 %d)" % bankrupt)
	check(worths[worths.size() / 2] > 5000, "숙련 플레이 중앙값 순자산이 시작 자금($5,000)보다 큼")
