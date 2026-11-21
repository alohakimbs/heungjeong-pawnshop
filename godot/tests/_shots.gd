extends SceneTree
## 화면 스크린샷 (xvfb + opengl3 필요). 사용: xvfb-run godot --path . --rendering-driver opengl3 -s res://tests/_shots.gd
var main
var step := 0
func _init():
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
func shot(name):
	var img := root.get_viewport().get_texture().get_image()
	img.save_png("/tmp/shot_%s.png" % name)
	print("saved ", name, " ", img.get_size())
func _process(_d):
	step += 1
	var g = main.g
	match step:
		10: shot("1_paper")
		11: main.close_modal()
		20: shot("2_morning")
		21:
			g.event = ""
			g.flip_open()
			main.render()
		30: shot("3_customer")
		31:
			main._key("C"); main._key("5"); main._key("0"); main._key("0")
			g.propose(500)
			main.render()
		40: shot("4_haggle")
		41:
			g.inv.append(g.gen_item(0.3)); g.inv.append(g.gen_item(0.3))
			main.show_inv()
		50: shot("5_inv")
		51: main.show_staff()
		60: shot("6_staff")
		61: main.show_ledger()
		70: shot("7_ledger")
		71:
			g.auction_day = g.day; g.auction_done = false; g.phase = "morning"; g.cur = {}
			g.money = 20000
			main._open_auction()
		80: shot("8_auction")
		81:
			main.close_modal()
			while g.phase != "night":
				if g.phase == "morning": g.flip_open()
				elif g.phase == "visit": g.open_shop()
				elif g.cur["gone"]: g.next_customer()
				else: g.refuse()
			main.render(); main.show_receipt()
		90: shot("9_receipt")
		91: quit()
	return false
