class_name ItemArt
extends RefCounted
## 물건 아이콘: 먹선 + 채색 SVG. viewBox 0 0 100 100. 이모지 대신 쓴다.
## 키 → [모양, 주색, 보조색]. 같은 모양을 색만 바꿔 여러 물건에 쓴다.

const K := "#2a1a14"
const S := ' stroke="#2a1a14" stroke-width="3" stroke-linejoin="round" stroke-linecap="round"'

const MAP := {
	"maebyeong": ["vase", "#7fb8a8", "#4a8a7a"], "bottle": ["vase", "#f4efe6", "#c83a3a"], "moonjar": ["jar", "#f4efe6", "#d8d0c0"],
	"onggi": ["jar", "#8a4a2a", "#5a2a18"], "bowl": ["bowl", "#c8c0a8", "#6a8aa8"], "cup": ["bowl", "#9ac8d8", "#e0d8c8"],
	"brass_bowl": ["bowl", "#d8a840", "#a87820"], "dropper": ["dropper", "#f4efe6", "#3a5ab8"], "teapot": ["teapot", "#e8e4dc", "#5a7a9a"],
	"sinseollo": ["teapot", "#d8a840", "#c83a3a"], "incense": ["incense", "#7fb8a8", "#4a8a7a"], "brazier": ["incense", "#5a5048", "#e8702a"],
	"scroll": ["scroll", "#4a7a6a", "#f0e8d0"], "tiger_scroll": ["scroll", "#e8902a", "#f0e8d0"], "star_scroll": ["scroll", "#2a2a6a", "#f0e8d0"],
	"portrait": ["scroll", "#c83a3a", "#f0e8d0"], "calli_scroll": ["scroll", "#1a1410", "#f0e8d0"], "magpie_scroll": ["scroll", "#3a5ab8", "#f0e8d0"],
	"screen": ["screen", "#c8a060", "#3a6a8a"], "fan": ["fan", "#7ad8e8", "#c83a8a"],
	"hairpin": ["hairpin", "#d8d8e0", "#7a9ad8"], "hairpin_jade": ["hairpin", "#6ac89a", "#e0d0a0"], "tteoljam": ["tteoljam", "#e0c040", "#7ad8e8"],
	"norigae": ["norigae", "#c83a6a", "#e0c040"], "norigae_coral": ["norigae", "#e8604a", "#7ad8e8"], "ring": ["ring", "#d8d8e0", "#9a7ad8"],
	"gwanja": ["ring", "#e0c040", "#c8a060"], "manggeon": ["ring", "#2a2420", "#6a6058"], "amber": ["gem", "#e8a030", "#5a3a1a"],
	"orb": ["gem", "#9a7ad8", "#e8e0ff"], "chest": ["chest", "#8a5a32", "#d8a840"], "inlay_box": ["chest", "#2a1a2a", "#8ad8e8"],
	"cabinet": ["cabinet", "#a8743a", "#d8a840"], "drawers": ["cabinet", "#6a4a2a", "#d8a840"], "box": ["box", "#5a3a2a", "#d8a840"],
	"box_plain": ["box", "#b8905a", "#5a7ad8"], "soban": ["soban", "#a8743a", "#6a4a2a"], "desk": ["soban", "#6a4a2a", "#3a2a1a"],
	"inkstone": ["inkstone", "#3a3a40", "#6a7ad8"], "inkstick": ["inkstick", "#1a1a20", "#d8a840"], "brush": ["brush", "#b8905a", "#1a1a20"],
	"seal": ["seal", "#7ad8a8", "#c83a3a"], "brushpot": ["brushpot", "#c8c0a8", "#5a7a9a"], "book": ["book", "#3a4a8a", "#f0e8d0"],
	"book_red": ["book", "#a83a2a", "#f0e8d0"], "map": ["map", "#e8d8a8", "#3a5ab8"],
	"gayageum": ["zither", "#b8805a", "#f0e0a0"], "geomungo": ["zither", "#5a3a2a", "#d8c890"], "haegeum": ["haegeum", "#8a5a32", "#d8c890"],
	"flute": ["flute", "#c8a060", "#c83a3a"], "danso": ["flute", "#8ab060", "#5a3a2a"], "janggu": ["janggu", "#c83a3a", "#e8e0d0"],
	"drum": ["drum", "#c83a3a", "#3a6ac8"], "gong": ["gong", "#d8a840", "#c83a3a"],
	"gat": ["gat", "#1a1612", "#4a4038"], "robe": ["robe", "#5a5ab8", "#f4efe6"], "wedding_robe": ["robe", "#c83a3a", "#3a8a4a"],
	"jeogori": ["robe", "#f0d040", "#c83a6a"], "flower_shoes": ["shoe", "#e86a9a", "#7ad8a8"], "shoes": ["shoe", "#3a3a5a", "#e0c040"],
	"jobawi": ["jobawi", "#3a2440", "#e0c040"],
	"sword": ["sword", "#7af0ff", "#5a3a2a"], "eunjangdo": ["knife", "#d8d8e0", "#c83a6a"], "bow": ["bow", "#8a5a32", "#e8e0d0"],
	"quiver": ["quiver", "#6a4a2a", "#c83a3a"], "helmet": ["helmet", "#8a8a98", "#c83a3a"], "armor": ["armor", "#5a4a6a", "#d8a840"],
	"mace": ["mace", "#8a8a98", "#7af0ff"], "flag": ["flag", "#c83a3a", "#f0e040"],
	"spoon": ["spoon", "#d8a840", "#a87820"], "lamp": ["lamp", "#c8a060", "#f8d040"], "coins": ["coins", "#d8a840", "#a87820"],
	"abacus": ["abacus", "#6a4a2a", "#7af0ff"], "compass": ["compass", "#c8905a", "#c83a3a"], "mold": ["mold", "#b8905a", "#6a4a2a"],
	"lantern": ["lantern", "#3a6ac8", "#c83a3a"],
	"mask": ["mask", "#f0e0c0", "#c83a3a"], "talisman": ["talisman", "#f0d040", "#c83a3a"], "jangseung": ["jangseung", "#b8905a", "#c83a3a"],
	"ship": ["ship", "#8a5a32", "#7af0ff"], "haetae": ["haetae", "#b8b0a0", "#7ad8a8"], "yut": ["yut", "#d8b880", "#5a3a2a"],
	"gourd": ["gourd", "#c8a050", "#7ad8e8"],
}


static func n(v: float) -> String:
	return str(snappedf(v, 0.1))


static func svg(key: String) -> String:
	var m: Array = MAP.get(key, ["gem", "#9a9a9a", "#ffffff"])
	var a: String = m[1]
	var b: String = m[2]
	var s := '<ellipse cx="50" cy="92" rx="30" ry="5" fill="#000" opacity=".18"/>'
	match m[0]:
		"vase":
			s += '<path d="M42 10 L58 10 L57 18 Q80 30 72 60 Q66 84 58 90 L42 90 Q34 84 28 60 Q20 30 43 18 Z" fill="%s"%s/><path d="M34 46 Q50 56 66 46" stroke="%s" stroke-width="4" fill="none"/><circle cx="50" cy="66" r="7" fill="none" stroke="%s" stroke-width="3"/>' % [a, S, b, b]
		"jar":
			s += '<path d="M38 12 L62 12 L64 20 Q90 34 84 58 Q78 86 50 90 Q22 86 16 58 Q10 34 36 20 Z" fill="%s"%s/><path d="M30 34 Q40 28 46 30" stroke="#fff" stroke-width="5" opacity=".6" fill="none"/><path d="M20 56 Q50 64 80 56" stroke="%s" stroke-width="3" fill="none"/>' % [a, S, b]
		"bowl":
			s += '<path d="M12 40 L88 40 Q84 76 56 80 L58 88 L42 88 L44 80 Q16 76 12 40 Z" fill="%s"%s/><ellipse cx="50" cy="40" rx="38" ry="8" fill="%s"%s/><path d="M24 56 Q50 64 76 56" stroke="%s" stroke-width="3" fill="none"/>' % [a, S, b, S, b]
		"dropper":
			s += '<rect x="18" y="40" width="64" height="44" rx="10" fill="%s"%s/><rect x="42" y="28" width="16" height="14" rx="3" fill="%s"%s/><path d="M30 56 L44 64 L30 72 M56 52 L70 62 L58 72" stroke="%s" stroke-width="3" fill="none"/>' % [a, S, a, S, b]
		"teapot":
			s += '<path d="M24 46 Q22 86 50 86 Q78 86 76 46 Z" fill="%s"%s/><path d="M76 54 Q94 50 90 34" stroke="%s" stroke-width="7" fill="none"/><path d="M24 54 Q8 58 14 72" stroke="%s" stroke-width="6" fill="none"/><ellipse cx="50" cy="46" rx="26" ry="7" fill="%s"%s/><circle cx="50" cy="36" r="6" fill="%s"%s/>' % [a, S, K, K, b, S, b, S]
		"incense":
			s += '<path d="M20 44 L80 44 Q78 76 50 80 Q22 76 20 44 Z" fill="%s"%s/><path d="M28 80 L24 92 M72 80 L76 92 M50 80 L50 92" stroke="%s" stroke-width="5"/><path d="M38 40 Q34 26 44 18 Q40 10 48 4 M58 40 Q64 28 56 20" stroke="#bbb" stroke-width="3" fill="none" opacity=".8"/><rect x="18" y="40" width="64" height="7" rx="3" fill="%s"%s/>' % [a, S, K, b, S]
		"scroll":
			s += '<rect x="20" y="12" width="60" height="74" fill="%s"%s/><rect x="26" y="18" width="48" height="62" fill="%s"/><rect x="14" y="8" width="72" height="7" rx="3" fill="#5a3a2a"%s/><rect x="14" y="84" width="72" height="7" rx="3" fill="#5a3a2a"%s/><path d="M30 66 L42 44 L50 56 L58 40 L70 66 Z" fill="%s" opacity=".85"/><circle cx="62" cy="28" r="5" fill="%s" opacity=".7"/>' % [a, S, b, S, S, a, a]
		"screen":
			for i in 4:
				var x := 10 + i * 20
				s += '<path d="M%d %d L%d %d L%d %d L%d %d Z" fill="%s"%s/><rect x="%d" y="%d" width="12" height="40" fill="%s" opacity=".8"/>' % [x, 16 + (i % 2) * 4, x + 20, 16 + ((i + 1) % 2) * 4, x + 20, 84 - ((i + 1) % 2) * 4, x, 84 - (i % 2) * 4, a, S, x + 4, 30, b]
		"fan":
			s += '<path d="M50 84 L8 40 Q50 0 92 40 Z" fill="%s"%s/><path d="M50 84 L22 26 M50 84 L36 16 M50 84 L50 12 M50 84 L64 16 M50 84 L78 26" stroke="%s" stroke-width="2"/><circle cx="50" cy="84" r="5" fill="%s"%s/><path d="M30 40 Q50 30 70 40" stroke="%s" stroke-width="5" fill="none"/>' % [a, S, K, b, S, b]
		"hairpin":
			s += '<path d="M16 84 L76 24" stroke="%s" stroke-width="7" stroke-linecap="round"/><path d="M16 84 L76 24" stroke="%s" stroke-width="3" opacity=".4"/><path d="M68 16 Q90 18 84 40 Q72 38 68 16 Z" fill="%s"%s/>' % [K, a, b, S]
		"tteoljam":
			s += '<path d="M50 90 L50 46" stroke="%s" stroke-width="5"/><circle cx="50" cy="36" r="20" fill="%s"%s/>' % [K, a, S]
			for i in 6:
				var ang := TAU * i / 6.0
				s += '<circle cx="%s" cy="%s" r="5" fill="%s"%s/>' % [n(50 + cos(ang) * 14), n(36 + sin(ang) * 14), b, S]
		"norigae":
			s += '<path d="M50 6 L50 26" stroke="%s" stroke-width="4"/><path d="M38 26 Q50 14 62 26 Q62 42 50 48 Q38 42 38 26 Z" fill="%s"%s/>' % [K, b, S]
			for i in 5:
				s += '<path d="M%d 48 Q%d 72 %d 92" stroke="%s" stroke-width="4" fill="none"/>' % [42 + i * 4, 40 + i * 5, 36 + i * 7, a]
		"ring":
			s += '<ellipse cx="50" cy="58" rx="30" ry="24" fill="none" stroke="%s" stroke-width="13"/><ellipse cx="50" cy="58" rx="30" ry="24" fill="none" stroke="%s" stroke-width="7"/><circle cx="50" cy="32" r="11" fill="%s"%s/>' % [K, a, b, S]
		"gem":
			s += '<circle cx="50" cy="52" r="34" fill="%s"%s/><circle cx="50" cy="52" r="20" fill="%s" opacity=".5"/><ellipse cx="38" cy="38" rx="9" ry="6" fill="#fff" opacity=".7"/>' % [a, S, b]
		"chest":
			s += '<rect x="10" y="30" width="80" height="54" rx="4" fill="%s"%s/><path d="M10 48 L90 48" stroke="%s" stroke-width="3"/><rect x="40" y="44" width="20" height="16" rx="3" fill="%s"%s/><path d="M14 34 L24 34 L14 44 Z M86 34 L76 34 L86 44 Z M14 80 L24 80 L14 70 Z M86 80 L76 80 L86 70 Z" fill="%s"/>' % [a, S, K, b, S, b]
		"cabinet":
			s += '<rect x="18" y="10" width="64" height="76" rx="3" fill="%s"%s/>' % [a, S]
			for r in 3:
				for c in 2:
					s += '<rect x="%d" y="%d" width="26" height="20" fill="none" stroke="%s" stroke-width="2"/><circle cx="%d" cy="%d" r="3" fill="%s"/>' % [22 + c * 30, 14 + r * 24, K, 35 + c * 30, 24 + r * 24, b]
		"box":
			s += '<rect x="16" y="36" width="68" height="46" rx="5" fill="%s"%s/><rect x="12" y="28" width="76" height="14" rx="5" fill="%s"%s/><circle cx="50" cy="56" r="7" fill="%s"%s/>' % [a, S, a, S, b, S]
		"soban":
			s += '<ellipse cx="50" cy="40" rx="40" ry="14" fill="%s"%s/><path d="M22 46 L18 86 M78 46 L82 86 M40 52 L38 88 M60 52 L62 88" stroke="%s" stroke-width="6"/><path d="M20 70 L80 70" stroke="%s" stroke-width="4"/>' % [a, S, b, b]
		"inkstone":
			s += '<rect x="20" y="14" width="60" height="76" rx="8" fill="%s"%s/><rect x="28" y="22" width="44" height="22" rx="10" fill="%s" opacity=".7"/><path d="M30 56 Q50 48 70 56 Q66 80 50 82 Q34 80 30 56 Z" fill="#111" opacity=".5"/>' % [a, S, b]
		"inkstick":
			s += '<rect x="34" y="8" width="32" height="84" rx="4" fill="%s"%s/><path d="M40 30 L60 30 M40 70 L60 70" stroke="%s" stroke-width="3"/><path d="M44 40 L56 40 L56 60 L44 60 Z" fill="none" stroke="%s" stroke-width="2"/>' % [a, S, b, b]
		"brush":
			s += '<rect x="44" y="6" width="12" height="60" rx="4" fill="%s"%s/><path d="M42 64 L58 64 Q60 82 50 94 Q40 82 42 64 Z" fill="%s"%s/>' % [a, S, b, S]
		"seal":
			s += '<rect x="28" y="54" width="44" height="34" rx="3" fill="%s"%s/><path d="M34 54 Q32 30 50 26 Q68 30 66 54 Z" fill="%s"%s/><circle cx="50" cy="20" r="8" fill="%s"%s/><rect x="36" y="62" width="28" height="18" fill="none" stroke="%s" stroke-width="3"/>' % [a, S, a, S, a, S, b]
		"brushpot":
			s += '<path d="M44 20 L36 4 M50 20 L50 2 M56 20 L66 6" stroke="%s" stroke-width="5"/><rect x="26" y="24" width="48" height="64" rx="6" fill="%s"%s/><path d="M34 44 Q50 36 66 44 M34 64 Q50 56 66 64" stroke="%s" stroke-width="3" fill="none"/>' % [K, a, S, b]
		"book":
			s += '<rect x="20" y="10" width="62" height="80" fill="%s"%s/><rect x="74" y="14" width="10" height="72" fill="%s"%s/><rect x="34" y="18" width="16" height="44" fill="%s"%s/>' % [a, S, b, S, b, S]
			for i in 4:
				s += '<path d="M20 %d L28 %d" stroke="%s" stroke-width="3"/>' % [22 + i * 18, 22 + i * 18, b]
		"map":
			s += '<path d="M10 20 L36 12 L64 20 L90 12 L90 82 L64 90 L36 82 L10 90 Z" fill="%s"%s/><path d="M36 12 L36 82 M64 20 L64 90" stroke="%s" stroke-width="2"/><circle cx="30" cy="42" r="6" fill="%s"/><circle cx="70" cy="60" r="9" fill="none" stroke="%s" stroke-width="3"/><path d="M30 42 Q50 30 70 60" stroke="%s" stroke-width="2" stroke-dasharray="4 3" fill="none"/>' % [a, S, K, b, b, K]
		"zither":
			s += '<path d="M10 70 L80 20 Q92 24 90 32 L22 84 Q8 82 10 70 Z" fill="%s"%s/>' % [a, S]
			for i in 6:
				s += '<path d="M%d %d L%d %d" stroke="%s" stroke-width="1.5"/><path d="M%d %d l4 -6 l4 6 Z" fill="%s"/>' % [16 + i * 2, 72 - i * 3, 82 - i * 1, 26 + i * 2, b, 40 + i * 6, 56 - i * 5, b]
		"haegeum":
			s += '<path d="M50 6 L50 80" stroke="%s" stroke-width="6"/><ellipse cx="50" cy="80" rx="14" ry="10" fill="%s"%s/><path d="M56 14 L56 76" stroke="%s" stroke-width="2"/><path d="M20 40 Q50 60 86 50" stroke="%s" stroke-width="3" fill="none"/>' % [a, a, S, b, K]
		"flute":
			s += '<rect x="8" y="44" width="84" height="12" rx="6" fill="%s"%s/>' % [a, S]
			for i in 6:
				s += '<circle cx="%d" cy="50" r="3" fill="%s"/>' % [28 + i * 10, K]
			s += '<path d="M14 56 Q12 74 20 84" stroke="%s" stroke-width="4" fill="none"/>' % b
		"janggu":
			s += '<ellipse cx="18" cy="50" rx="12" ry="32" fill="%s"%s/><ellipse cx="82" cy="50" rx="12" ry="32" fill="%s"%s/><path d="M18 18 Q50 46 82 18 M18 82 Q50 54 82 82" fill="none" stroke="%s" stroke-width="10"/><path d="M22 24 L78 76 M22 76 L78 24" stroke="%s" stroke-width="2"/>' % [b, S, b, S, a, K]
		"drum":
			s += '<rect x="16" y="28" width="68" height="48" rx="10" fill="%s"%s/><ellipse cx="50" cy="28" rx="34" ry="10" fill="%s"%s/><circle cx="50" cy="28" r="6" fill="%s"/><path d="M50 28 m0 -6 a6 6 0 0 1 0 12 a3 3 0 0 0 0 -6" fill="#f0e040"/>' % [a, S, "#f0e8d0", S, b]
		"gong":
			s += '<circle cx="50" cy="50" r="36" fill="%s"%s/><circle cx="50" cy="50" r="24" fill="none" stroke="%s" stroke-width="3" opacity=".6"/><path d="M50 14 L50 4" stroke="%s" stroke-width="4"/><path d="M72 76 L92 92" stroke="%s" stroke-width="6"/>' % [a, S, "#fff", b, K]
		"gat":
			s += '<ellipse cx="50" cy="64" rx="44" ry="12" fill="%s" fill-opacity=".85"%s/><path d="M32 62 L34 26 Q50 20 66 26 L68 62 Z" fill="%s"%s/><path d="M34 70 Q30 86 40 94 M66 70 Q70 86 60 94" stroke="%s" stroke-width="3" fill="none"/>' % [a, S, a, S, b]
		"robe":
			s += '<path d="M30 12 L70 12 L92 40 L80 50 L72 42 L74 90 L26 90 L28 42 L20 50 L8 40 Z" fill="%s"%s/><path d="M38 12 L54 46 L62 12" stroke="%s" stroke-width="6" fill="none"/><path d="M54 46 Q70 56 62 76 M54 46 Q48 60 52 74" stroke="%s" stroke-width="5" fill="none"/>' % [a, S, b, b]
		"shoe":
			s += '<path d="M8 66 Q10 48 30 48 L70 46 Q90 44 94 30 Q98 50 88 66 Z" fill="%s"%s/><path d="M30 48 Q50 58 70 46" stroke="%s" stroke-width="3" fill="none"/><circle cx="76" cy="54" r="5" fill="%s"/>' % [a, S, b, b]
		"jobawi":
			s += '<path d="M14 66 Q14 20 50 20 Q86 20 86 66 L72 66 Q70 40 50 40 Q30 40 28 66 Z" fill="%s"%s/><circle cx="50" cy="26" r="7" fill="%s"%s/><path d="M50 66 L50 92" stroke="%s" stroke-width="4"/>' % [a, S, b, S, b]
		"sword":
			s += '<path d="M24 82 L84 14 L90 18 L32 88 Z" fill="%s"%s/><path d="M16 70 L36 92" stroke="%s" stroke-width="7" stroke-linecap="round"/><path d="M8 92 L22 80" stroke="%s" stroke-width="9" stroke-linecap="round"/>' % [a, S, K, b]
		"knife":
			s += '<path d="M30 78 L70 22 Q78 20 76 30 L38 84 Z" fill="%s"%s/><rect x="16" y="72" width="22" height="16" rx="4" transform="rotate(-50 27 80)" fill="%s"%s/>' % [a, S, b, S]
		"bow":
			s += '<path d="M22 10 Q90 50 22 90 Q12 92 18 84 Q70 50 18 16 Q12 8 22 10 Z" fill="%s"%s/><path d="M20 12 L20 88" stroke="%s" stroke-width="2"/>' % [a, S, b]
		"quiver":
			s += '<path d="M30 30 L70 30 L64 92 L36 92 Z" fill="%s"%s/><path d="M38 30 L32 6 M50 30 L50 4 M62 30 L70 6" stroke="%s" stroke-width="3"/><path d="M28 8 l4 -4 l4 6 M46 4 l4 -4 l4 4 M66 8 l4 -4 l2 6" stroke="%s" stroke-width="3" fill="none"/>' % [a, S, K, b]
		"helmet":
			s += '<path d="M18 64 Q18 18 50 16 Q82 18 82 64 Z" fill="%s"%s/><path d="M10 66 L90 66 L84 76 L16 76 Z" fill="%s"%s/><path d="M50 16 L50 2" stroke="%s" stroke-width="4"/><circle cx="50" cy="4" r="5" fill="%s"/>' % [a, S, a, S, K, b]
		"armor":
			s += '<path d="M24 14 L76 14 L86 30 L80 88 L20 88 L14 30 Z" fill="%s"%s/>' % [a, S]
			for r in 5:
				for c in 4:
					s += '<path d="M%d %d q6 8 12 0" stroke="%s" stroke-width="2" fill="none"/>' % [24 + c * 13, 30 + r * 11, b]
		"mace":
			s += '<path d="M24 88 L60 40" stroke="%s" stroke-width="8" stroke-linecap="round"/><circle cx="66" cy="32" r="20" fill="%s"%s/><circle cx="66" cy="32" r="7" fill="%s"/>' % [K, a, S, b]
		"flag":
			s += '<path d="M24 92 L24 6" stroke="%s" stroke-width="5"/><path d="M26 10 L86 14 L78 34 L88 52 L26 50 Z" fill="%s"%s/><circle cx="52" cy="30" r="9" fill="%s"%s/>' % [K, a, S, b, S]
		"spoon":
			s += '<ellipse cx="34" cy="28" rx="16" ry="20" fill="%s"%s/><path d="M38 46 L54 92" stroke="%s" stroke-width="6" stroke-linecap="round"/><path d="M66 10 L66 92 M74 10 L74 92" stroke="%s" stroke-width="5" stroke-linecap="round"/>' % [a, S, a, b]
		"lamp":
			s += '<path d="M50 90 L50 46" stroke="%s" stroke-width="6"/><ellipse cx="50" cy="90" rx="22" ry="5" fill="%s"%s/><ellipse cx="50" cy="44" rx="22" ry="8" fill="%s"%s/><path d="M50 36 Q40 22 50 8 Q60 22 50 36 Z" fill="%s"%s/>' % [a, a, S, a, S, b, S]
		"coins":
			for i in 5:
				s += '<ellipse cx="50" cy="%d" rx="28" ry="8" fill="%s"%s/>' % [82 - i * 9, a, S]
			s += '<circle cx="50" cy="32" r="20" fill="%s"%s/><rect x="44" y="26" width="12" height="12" fill="%s"%s/><path d="M50 14 l3 7 l7 0 l-6 4 l2 7 l-6 -4 l-6 4 l2 -7 l-6 -4 l7 0 Z" fill="#fff" opacity=".4"/>' % [a, S, "#3a2a1a", S]
		"abacus":
			s += '<rect x="10" y="18" width="80" height="64" rx="4" fill="none" stroke="%s" stroke-width="7"/><path d="M10 36 L90 36" stroke="%s" stroke-width="4"/>' % [a, a]
			for c in 6:
				s += '<path d="M%d 18 L%d 82" stroke="%s" stroke-width="2"/><ellipse cx="%d" cy="28" rx="5" ry="4" fill="%s"/><ellipse cx="%d" cy="%d" rx="5" ry="4" fill="%s"/>' % [20 + c * 12, 20 + c * 12, K, 20 + c * 12, b, 20 + c * 12, 50 + (c % 3) * 9, b]
		"compass":
			s += '<circle cx="50" cy="50" r="38" fill="%s"%s/><circle cx="50" cy="50" r="26" fill="#f0e8d0"%s/><path d="M50 28 L56 50 L50 72 L44 50 Z" fill="%s"/>' % [a, S, S, b]
		"mold":
			s += '<rect x="10" y="40" width="80" height="22" rx="4" fill="%s"%s/><circle cx="30" cy="51" r="8" fill="none" stroke="%s" stroke-width="3"/><circle cx="54" cy="51" r="8" fill="none" stroke="%s" stroke-width="3"/><path d="M90 50 L96 50" stroke="%s" stroke-width="6"/>' % [a, S, b, b, b]
		"lantern":
			s += '<path d="M50 4 L50 16" stroke="%s" stroke-width="3"/><rect x="34" y="14" width="32" height="8" fill="%s"%s/><path d="M30 22 L70 22 Q80 50 70 78 L30 78 Q20 50 30 22 Z" fill="%s"%s/><path d="M26 50 L74 50" stroke="%s" stroke-width="12"/><rect x="34" y="78" width="32" height="8" fill="%s"%s/><path d="M44 86 L42 98 M50 86 L50 98 M56 86 L58 98" stroke="%s" stroke-width="2"/>' % [K, K, S, b, S, a, K, S, b]
		"mask":
			s += '<path d="M18 30 Q18 6 50 6 Q82 6 82 30 Q86 70 50 92 Q14 70 18 30 Z" fill="%s"%s/><path d="M28 36 Q36 30 44 38 M56 38 Q64 30 72 36" stroke="%s" stroke-width="4" fill="none"/><path d="M30 64 Q50 84 70 64" stroke="%s" stroke-width="5" fill="none"/><ellipse cx="28" cy="52" rx="6" ry="4" fill="%s" opacity=".6"/><ellipse cx="72" cy="52" rx="6" ry="4" fill="%s" opacity=".6"/>' % [a, S, K, K, b, b]
		"talisman":
			s += '<rect x="28" y="6" width="44" height="86" fill="%s"%s/><path d="M50 14 L50 84 M38 26 L62 26 M36 44 Q50 34 64 44 Q50 54 36 44 M40 62 L60 74 M60 62 L40 74" stroke="%s" stroke-width="4" fill="none"/>' % [a, S, b]
		"jangseung":
			s += '<rect x="30" y="20" width="40" height="72" rx="14" fill="%s"%s/><path d="M26 22 Q50 2 74 22 Z" fill="%s"%s/><circle cx="40" cy="38" r="6" fill="#fff"%s/><circle cx="60" cy="38" r="6" fill="#fff"%s/><path d="M38 58 L62 58" stroke="%s" stroke-width="5"/><path d="M42 58 L42 64 M50 58 L50 64 M58 58 L58 64" stroke="#fff" stroke-width="3"/>' % [a, S, K, S, S, S, b]
		"ship":
			s += '<path d="M10 54 L90 54 L80 76 L20 76 Z" fill="%s"%s/><path d="M22 54 Q50 26 78 54 Z" fill="#4a6a5a"%s/>' % [a, S, S]
			for i in 5:
				s += '<path d="M%d 40 l4 -4 l4 4" stroke="#f0e8d0" stroke-width="2" fill="none"/>' % (30 + i * 9)
			s += '<path d="M10 54 Q2 46 8 38" stroke="%s" stroke-width="5" fill="none"/><path d="M80 76 L94 82 L80 84" fill="%s"/>' % [K, b]
		"haetae":
			s += '<path d="M14 88 L18 54 Q16 30 36 22 Q56 14 70 30 Q86 36 84 60 L86 88 Z" fill="%s"%s/><path d="M36 22 Q30 6 44 10 M56 18 Q60 4 70 12" stroke="%s" stroke-width="4" fill="none"/><circle cx="46" cy="38" r="5" fill="%s"/><circle cx="64" cy="38" r="5" fill="%s"/><path d="M44 56 Q55 64 66 56" stroke="%s" stroke-width="4" fill="none"/>' % [a, S, K, b, b, K]
		"yut":
			for i in 4:
				s += '<rect x="%d" y="14" width="14" height="72" rx="7" fill="%s"%s/>' % [18 + i * 18, a if i % 2 == 0 else "#f0e8d0", S]
			s += '<path d="M25 30 l0 6 M25 50 l0 6" stroke="%s" stroke-width="3"/>' % b
		"gourd":
			s += '<circle cx="50" cy="32" r="16" fill="%s"%s/><circle cx="50" cy="66" r="24" fill="%s"%s/><path d="M50 16 L50 6" stroke="%s" stroke-width="5"/><path d="M38 44 Q50 52 62 44" stroke="%s" stroke-width="6" fill="none"/>' % [a, S, a, S, K, b]
	return s


static func texture(key: String, px: int = 96) -> ImageTexture:
	return SvgArt.rasterize(svg(key), [0, 0, 100, 100], px / 100.0)
