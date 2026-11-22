"""수묵 시트 자르기: python3 slice.py <종류> <원본.png> <이름1,이름2,...> <출력폴더>
종류: char(2x2 표정 → 이름_ok/happy/angry/meh), quad(2x2 서로 다른 인물 → 이름.png),
      grid3(3x3 물건 → 이름.png, 빈 이름은 건너뜀), bg(720x1080 RGB), props(2x2 → ui)
"""
import sys
import numpy as np
from PIL import Image
from scipy import ndimage

kind, src, names, out = sys.argv[1], sys.argv[2], sys.argv[3].split(","), sys.argv[4]
im = Image.open(src).convert("RGBA")


def keyed(cell):
    a = np.array(cell)
    if a[..., 3].min() > 250:  # 불투명하면 흰 배경을 지운다
        rgb = a[..., :3].astype(int)
        white = (rgb.min(axis=2) > 238) & (rgb.max(axis=2) - rgb.min(axis=2) < 14)
        lab, _ = ndimage.label(white)
        border = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
        bg = np.isin(lab, list(border))
        a[..., 3] = np.where(bg, 0, 255)
    return a


def trim(a, pad=6):
    al = a[..., 3] > 24
    lab, n = ndimage.label(al)
    if n == 0:
        return None
    sizes = ndimage.sum(al, lab, range(1, n + 1))
    keep = np.isin(lab, [i + 1 for i, s in enumerate(sizes) if s >= max(sizes) * 0.02])
    a = a.copy()
    a[..., 3] = np.where(keep, a[..., 3], 0)
    ys, xs = np.where(keep)
    y0, y1, x0, x1 = max(ys.min() - pad, 0), ys.max() + pad, max(xs.min() - pad, 0), xs.max() + pad
    return Image.fromarray(a[y0:y1 + 1, x0:x1 + 1])


def fit(img, mw, mh):
    s = min(mw / img.width, mh / img.height, 1.0)
    return img.resize((max(1, round(img.width * s)), max(1, round(img.height * s))), Image.LANCZOS)


def cells(n):
    w, h = im.size
    for r in range(n):
        for c in range(n):
            yield im.crop((c * w // n, r * h // n, (c + 1) * w // n, (r + 1) * h // n))


if kind == "char":
    for cell, mood in zip(cells(2), ["ok", "happy", "angry", "meh"]):
        t = trim(keyed(cell))
        fit(t, 520, 760).save(f"{out}/{names[0]}_{mood}.png", optimize=True)
elif kind == "quad":
    for cell, nm in zip(cells(2), names):
        if nm:
            t = trim(keyed(cell))
            if t is not None:
                fit(t, 520, 760).save(f"{out}/{nm}.png", optimize=True)
elif kind == "grid3":
    for cell, nm in zip(cells(3), names):
        if nm:
            a = keyed(cell)
            haze = (a[..., 3] < 70) & (a[..., :3].min(axis=2) > 195)
            a[..., 3] = np.where(haze, 0, a[..., 3])
            t = trim(a)
            if t is not None:
                fit(t, 256, 256).save(f"{out}/{nm}.png", optimize=True)
elif kind == "props":
    for cell, nm in zip(cells(2), names):
        t = trim(keyed(cell))
        fit(t, 560, 560).save(f"{out}/{nm}.png", optimize=True)
elif kind == "bg":
    w, h = im.size
    tw = h * 2 / 3
    if w > tw:
        x0 = (w - tw) / 2
        bgim = im.crop((int(x0), 0, int(x0 + tw), h))
    else:
        th = w * 3 / 2
        y0 = (h - th) / 2
        bgim = im.crop((0, int(y0), w, int(y0 + th)))
    bgim.convert("RGB").resize((720, 1080), Image.LANCZOS).save(f"{out}/{names[0]}.png", optimize=True)
print("ok", src, names)
