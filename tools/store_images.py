"""스토어·아이콘 이미지 만들기: python3 tools/store_images.py <icon.png> <feature.png>
- icon.png(정사각, 원형 금테) → godot/assets/icon/icon_512·192, adaptive_fg/bg_432
- feature.png(약 2:1) → docs/store/feature_graphic.png, store/feature_graphic.png (1024x500, 오른쪽 하늘에 제목)
"""
import sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont

icon_src, feat_src = sys.argv[1], sys.argv[2]
ICON = "godot/assets/icon"
FONT = "godot/assets/fonts/NotoSerifKR-Black.otf"
FONT2 = "godot/assets/fonts/NotoSerifKR-Bold.otf"

ic = Image.open(icon_src).convert("RGB")
S = ic.width
ic.resize((512, 512), Image.LANCZOS).save(f"{ICON}/icon_512.png", optimize=True)
ic.resize((192, 192), Image.LANCZOS).save(f"{ICON}/icon_192.png", optimize=True)
# 적응형: 보이는 영역은 가운데 72/108. 금테 원(지름 약 97%)이 그 안에 들어오게 줄인 그림을 앞층에,
# 뒤층은 그림 네 귀퉁이 색(먹빛 초록) 한 색.
cs = [ic.crop(b).resize((1, 1), Image.BOX).getpixel((0, 0)) for b in
      [(0, 0, 60, 60), (S - 60, 0, S, 60), (0, S - 60, 60, S), (S - 60, S - 60, S, S)]]
bgc = tuple(sum(c[i] for c in cs) // 4 for i in range(3))
bg = Image.new("RGB", (432, 432), bgc)
bg.save(f"{ICON}/adaptive_bg_432.png", optimize=True)
d = 284
fg = ic.resize((d, d), Image.LANCZOS).convert("RGBA")
m = Image.new("L", (d * 4, d * 4), 0)
ImageDraw.Draw(m).ellipse((0, 0, d * 4 - 1, d * 4 - 1), fill=255)
fg.putalpha(m.resize((d, d), Image.LANCZOS))
canvas = Image.new("RGBA", (432, 432), (0, 0, 0, 0))
canvas.paste(fg, ((432 - d) // 2, (432 - d) // 2), fg)
canvas.save(f"{ICON}/adaptive_fg_432.png", optimize=True)

ft = Image.open(feat_src).convert("RGB")
w, h = ft.size
th = round(w * 500 / 1024)
if th <= h:
    y0 = (h - th) // 2
    ft = ft.crop((0, y0, w, y0 + th))
else:
    tw = round(h * 1024 / 500)
    ft = ft.crop((w - tw, 0, w, h))
ft = ft.resize((1024, 500), Image.LANCZOS)
dr = ImageDraw.Draw(ft)
ink, red = (34, 30, 38), (150, 36, 32)
f1 = ImageFont.truetype(FONT, 58)
f2 = ImageFont.truetype(FONT2, 22)
cx = 868
for i, ch in enumerate(["흥정왕", "전당포"]):
    tw_ = dr.textlength(ch, font=f1)
    dr.text((cx - tw_ / 2, 92 + i * 74), ch, font=f1, fill=ink)
for i, s in enumerate(["싸게 사서 비싸게 판다", "운경의 흥정 시뮬레이션"]):
    tw_ = dr.textlength(s, font=f2)
    dr.text((cx - tw_ / 2, 268 + i * 34), s, font=f2, fill=red if i == 0 else ink)
for p in ["docs/store/feature_graphic.png", "store/feature_graphic.png"]:
    ft.save(p, optimize=True)
print("ok")
