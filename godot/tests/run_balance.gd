extends SceneTree
## 장기 성장 진단. 금액은 냥, shop은 0부터 시작한다.
## godot --headless --path godot -s res://tests/run_balance.gd -- --days=120 --seeds=32 --output=/tmp/balance.json
## 기존 smart 봇을 그대로 사용한다. 실제 사람의 재미나 살림 구매 행동을 재현하지 않는다.
const Data := preload("res://scripts/core/game_data.gd")
const State := preload("res://scripts/core/game_state.gd")
const Bots := preload("res://tests/bots.gd")

func _init() -> void:
	var days := 120
	var seeds := 32
	var output := "/tmp/heungjeong_balance.json"
	var policy := "smart"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--days="):
			days = int(arg.get_slice("=", 1))
		elif arg.begins_with("--seeds="):
			seeds = int(arg.get_slice("=", 1))
		elif arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
		elif arg.begins_with("--policy="):
			policy = arg.trim_prefix("--policy=")
	if days < 1 or seeds < 1 or not policy in ["smart", "growth"]:
		push_error("days/seeds는 양수, policy는 smart 또는 growth여야 합니다")
		quit(1)
		return
	var data = Data.new()
	var report := {"days": days, "seeds": seeds, "policy": policy, "runs": []}
	var error_count := 0
	for s in seeds:
		var g = State.new(data, 300 + s)
		g.start_day()
		var bot = Bots.new(g, policy, 400 + s)
		var run := {"seed": 300 + s, "milestones": [], "checkpoints": [], "bankrupt": false}
		var prev_shop := 0
		for d in days:
			var alive: bool = bot.play_day()
			if g.shop != prev_shop:
				run["milestones"].append({"day": d + 1, "shop": g.shop})
				prev_shop = g.shop
			if (d + 1) % 30 == 0 or not alive or d == days - 1:
				run["checkpoints"].append({"day": d + 1, "cash": g.money, "worth": int(bot.net_worth()), "shop": g.shop, "shop_up": g.shop_up, "rep": g.rep, "deals": g.stats["deals"], "home": g.home, "ride": g.best_lv("ride"), "ship": g.best_lv("ship"), "equipment": g.equip.duplicate(), "owned": g.owned.duplicate()})
			if not alive:
				run["bankrupt"] = g.is_bankrupt()
				run["stop_reason"] = "bankrupt" if g.is_bankrupt() else "diagnostic_limit"
				break
		run["errors"] = bot.errors
		error_count += bot.errors.size()
		report["runs"].append(run)
		if (s + 1) % 8 == 0:
			print("진단 완료: %d/%d 시드" % [s + 1, seeds])
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file == null:
		push_error("진단 결과를 저장할 수 없습니다: " + output)
		data.free()
		quit(1)
		return
	file.store_string(JSON.stringify(report, "  ") + "\n")
	file.close()
	print("장기 진단: %d명 × %d일, 규칙 위반 %d건 → %s" % [seeds, days, error_count, output])
	data.free()
	quit(1 if error_count > 0 else 0)
