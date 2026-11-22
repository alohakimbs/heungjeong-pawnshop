extends SceneTree
## 수묵 원본에서 스토어 규격 생성. 이전 명령과 호환하는 개발용 진입점.
## python3 + Pillow 필요. 직접 실행: python3 tools/prepare_store_art.py
func _init() -> void:
	var output: Array = []
	var script := ProjectSettings.globalize_path("res://../tools/prepare_store_art.py")
	var code := OS.execute("python3", [script], output, true)
	for line in output:
		print(line)
	quit(code)
