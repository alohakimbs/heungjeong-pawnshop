extends Node
## 정적 게임 데이터(JSON) 로더. 오토로드 이름: GameData
## 데이터는 res://data/*.json 에 있고, 웹 프로토타입(web/index.html)에서 추출한 것이다.

var items: Dictionary = {}
var shops: Array = []
var staff: Dictionary = {}
var traits: Dictionary = {}
var specials: Dictionary = {}
var text: Dictionary = {}
var archetypes: Array = []
var events: Dictionary = {}
var lines: Dictionary = {}
var tips: Array = []
var trips: Dictionary = {}
var belong: Dictionary = {}


func _init() -> void:
	reload()


func reload() -> void:
	items = load_json("res://data/items.json")
	shops = load_json("res://data/shops.json")
	staff = load_json("res://data/staff.json")
	traits = load_json("res://data/traits.json")
	specials = load_json("res://data/specials.json")
	text = load_json("res://data/text.json")
	archetypes = load_json("res://data/archetypes.json")
	events = load_json("res://data/events.json")
	lines = load_json("res://data/lines.json")
	tips = load_json("res://data/tips.json")
	trips = load_json("res://data/trips.json")
	belong = load_json("res://data/belongings.json")


static func load_json(path: String) -> Variant:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("데이터 파일을 열 수 없음: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed == null:
		push_error("JSON 파싱 실패: %s" % path)
		return {}
	return parsed
