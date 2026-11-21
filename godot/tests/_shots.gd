extends SceneTree
## 화면 스크린샷 (xvfb + opengl3). 사용: xvfb-run -a -s "-screen 0 2340x1080x24" godot --path . --rendering-driver opengl3 --resolution 1170x540 -s res://tests/_shots.gd
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
		8:
			g.auction_day = g.day
			main.render()
		10: shot("1_morning")
		11:
			g.event = ""
			main._act(func(): g.flip_open())
		20: shot("2_intro")
		21:
			main._choices()[0][1].call()
			main.render()
		30: shot("3_inspect")
		31:
			main.close_modal()
			main._choices()[0][1].call()
			main.render()
		40: shot("4_haggle")
		41:
			g.draft = int(g.their_price() * 0.5)
			g.propose(g.draft)
			main.render()
		50: shot("5_counter")
		51:
			for i in 3: g.inv.append(g.gen_item(0.3))
			main.show_inv()
		60: shot("6_inv")
		61:
			main.close_modal()
			g.phase = "morning"; g.cur = {}; g.auction_day = g.day; g.auction_done = false; g.money = 20000
			main._open_auction()
		70: shot("7_auction")
		71: quit()
	return false
