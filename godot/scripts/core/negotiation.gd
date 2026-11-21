class_name Negotiation
extends RefCounted
## 손님 한 명과의 흥정 규칙. 화면과 분리된 순수 로직이라 헤드리스 테스트가 가능하다.
## 웹 프로토타입 v0.2의 propose()와 같은 규칙을 따른다.
##   판매 손님(buy=false): 손님이 물건을 팔러 옴. ask(요구가)는 min_price(마지노선) 아래로 내려가지 않는다.
##   구매 손님(buy=true): 손님이 물건을 사러 옴. offer(제시가)는 max_price(최대 지불액) 위로 올라가지 않는다.

enum Result { CONTINUE, DEAL, LEAVE_ANGRY }

var buy := false
var traits: Array = []
var ask := 0
var min_price := 0
var offer := 0
var max_price := 0
var patience := 100.0
var max_patience := 100.0
var rounds := 0
var last := -1
var deal_price := 0
var line := ""  # 손님의 마지막 반응 종류: deal, counter, low, repeat, insulted, final_no, gave_up
var rng: RandomNumberGenerator


func _init(p_rng: RandomNumberGenerator = null) -> void:
	rng = p_rng if p_rng != null else RandomNumberGenerator.new()


static func r10(n: float) -> int:
	return maxi(10, int(round(n / 10.0)) * 10)


func has_trait(t: String) -> bool:
	return traits.has(t)


func _rnd(a: float, b: float) -> float:
	return rng.randf_range(a, b)


## 판매 손님 준비. perceived: 손님이 생각하는 물건 가치.
func setup_seller(perceived: float, p_traits: Array, haggle_skill: int = 0, charm_skill: int = 0, min_adj: float = 1.0) -> void:
	buy = false
	traits = p_traits.duplicate()
	var mr := 0.72 - haggle_skill * 0.025
	if has_trait("desperate"):
		mr -= 0.22
	if has_trait("greedy"):
		mr += 0.13
	if has_trait("scammer"):
		mr -= 0.15
	min_price = r10(perceived * mr * min_adj)
	ask = r10(maxf(min_price * 1.1, perceived * (1.3 if has_trait("greedy") else 1.08) * _rnd(1.05, 1.35)))
	_setup_patience(charm_skill)


## 구매 손님 준비. perceived: 물건의 실제(진품 기준) 가치.
func setup_buyer(perceived: float, rarity: int, p_traits: Array, haggle_skill: int = 0, charm_skill: int = 0, min_adj: float = 1.0) -> void:
	buy = true
	traits = p_traits.duplicate()
	var mx := perceived
	mx *= 1.35 if has_trait("rich") else 1.0
	mx *= 0.8 if has_trait("stingy") else 1.0
	mx *= 1.35 if (has_trait("collector") and rarity >= 2) else 1.0
	mx *= 1.25 if has_trait("naive") else 1.0
	mx *= _rnd(0.95, 1.15) * (1.0 + haggle_skill * 0.02) / min_adj
	max_price = r10(mx)
	offer = r10(mx * _rnd(0.5, 0.75))
	_setup_patience(charm_skill)


func _setup_patience(charm_skill: int) -> void:
	var p := 100.0
	p *= 0.6 if has_trait("hasty") else 1.0
	p *= 1.5 if has_trait("calm") else 1.0
	max_patience = round(p + charm_skill * 8)
	patience = max_patience


func _hurt(amt: float) -> void:
	patience -= amt * (1.4 if has_trait("expert") else 1.0)


func _deal(x: int) -> Result:
	deal_price = x
	line = "deal"
	return Result.DEAL


func _leave(kind: String) -> Result:
	patience = maxf(patience, 0.0)
	line = kind
	return Result.LEAVE_ANGRY


## 플레이어가 가격 x를 제시한다. final=true면 최종 제안(한 번에 결판).
func propose(x: int, final := false) -> Result:
	if x <= 0:
		return Result.CONTINUE
	rounds += 1
	if not buy:
		if x >= ask:
			return _deal(x)
		if has_trait("proud") and x < min_price * 0.45:
			return _leave("insulted")
		if final:
			return _deal(x) if x >= min_price else _leave("final_no")
		if last != -1 and x <= last:
			_hurt(15)
			line = "repeat"
		elif x >= min_price:
			var gap := float(ask - x) / ask
			if gap < 0.04 or rng.randf() < 0.12 + float(x - min_price) / maxf(1.0, ask - min_price) * 0.3:
				return _deal(x)
			ask = maxi(x + 10, r10(ask - (ask - x) * _rnd(0.3, 0.55)))
			_hurt(6 + gap * 35)
			line = "counter"
		else:
			var ratio := float(x) / min_price
			ask = maxi(min_price, r10(ask - (ask - min_price) * _rnd(0.05, 0.2)))
			_hurt(12 + (1.0 - ratio) * 70)
			line = "low"
	else:
		if x <= offer:
			return _deal(x)
		if final:
			return _deal(x) if x <= max_price else _leave("final_no")
		if last != -1 and x >= last:
			_hurt(15)
			line = "repeat"
		elif x <= max_price:
			var gap := float(x - offer) / x
			if gap < 0.04 or rng.randf() < 0.12 + float(max_price - x) / maxf(1.0, max_price - offer) * 0.3:
				return _deal(x)
			offer = mini(x - 10, r10(offer + (x - offer) * _rnd(0.3, 0.55)))
			_hurt(6 + gap * 35)
			line = "counter"
		else:
			var ratio := float(max_price) / x
			if has_trait("proud") and ratio < 0.45:
				return _leave("insulted")
			offer = mini(max_price, r10(offer + (max_price - offer) * _rnd(0.05, 0.2)))
			_hurt(12 + (1.0 - ratio) * 70)
			line = "low"
	last = x
	if patience <= 0:
		return _leave("gave_up")
	return Result.CONTINUE


## 손님이 지금 부르는 가격(판매 손님은 요구가, 구매 손님은 제시가)
func their_price() -> int:
	return offer if buy else ask


func patience_ratio() -> float:
	return clampf(patience / max_patience, 0.0, 1.0)
