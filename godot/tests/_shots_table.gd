extends SceneTree
## 탁자·손그림 손님 확인용 스크린샷 (개발용)
var main
var step := 0
func _init():
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
func shot(name):
	root.get_viewport().get_texture().get_image().save_png("/tmp/tshot_%s.png" % name)
func _process(_d):
	step += 1
	var g = main.g
	match step:
		3: shot("title")
		5:
			g.story_seen.append("letter")
			g.stats["tut"] = ["morning", "intro", "look", "haggle"]
			main._close_title()
			g.event = ""
			main._act(func(): g.flip_open())
			var n := 0
			while (g.cur.get("visitor", false) or g.cur.get("arch", "") != "fox") and n < 300:
				n += 1
				g.cur = {}
				g.queue += 1
				g.next_customer()
			main._act(func(): pass)
		20: shot("offer")
		21:
			main._choices()[0][1].call()
			main.render()
		30: shot("haggle")
		31:
			g.stats["tut"] = []
			main._tutorial()
		40: shot("tut")
		41:
			main.close_modal()
			g.phase = "morning"; g.cur = {}; g.trip_day = 0
			main.render()
		45: shot("morning")
		46:
			main._map_sel = ""
			main.show_map()
		52: shot("map")
		53:
			g.money = 8000
			main._map_sel = "workshop"
			main._map_x = -1.0
			main.show_map()
		60: shot("map_result")
		61: quit()
	return false
