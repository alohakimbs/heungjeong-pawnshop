"""확정 수묵 원본으로 출시용 규격을 만든다. 새 그림은 생성하지 않는다.

    python3 tools/prepare_store_art.py

원본: docs/art/generated/icon.png, feature.png
출력: godot/assets/icon/, docs/store/, store/ (기존 등록 자료 경로 호환)
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageOps

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "docs/art/generated"
ICONS = ROOT / "godot/assets/icon"
STORE = ROOT / "docs/store"


def main():
    ICONS.mkdir(parents=True, exist_ok=True)
    STORE.mkdir(parents=True, exist_ok=True)
    icon = Image.open(SOURCE / "icon.png").convert("RGB")
    for size in (512, 192):
        ImageOps.fit(icon, (size, size), method=Image.Resampling.LANCZOS).save(
            ICONS / f"icon_{size}.png", optimize=True
        )
    # 전체 그림의 중심 피사체가 안전 영역 안에 있어 원형·둥근 사각형에서도 유지된다.
    ImageOps.fit(icon, (432, 432), method=Image.Resampling.LANCZOS).save(
        ICONS / "adaptive_fg_432.png", optimize=True
    )
    Image.new("RGB", (432, 432), (18, 40, 35)).save(
        ICONS / "adaptive_bg_432.png", optimize=True
    )
    feature = Image.open(SOURCE / "feature.png").convert("RGB")
    feature = ImageOps.fit(feature, (1024, 500), method=Image.Resampling.LANCZOS)
    feature.save(STORE / "feature_base.png", optimize=True)
    font = ImageFont.truetype(str(ROOT / "godot/assets/fonts/NotoSansKR-Black.otf"), 52)
    draw = ImageDraw.Draw(feature)
    draw.multiline_text((735, 175), "흥정왕\n전당포", font=font, fill=(29, 58, 50), spacing=8)
    feature.save(STORE / "feature_graphic.png", optimize=True)
    legacy = ROOT / "store"
    legacy.mkdir(exist_ok=True)
    feature.save(legacy / "feature_graphic.png", optimize=True)
    print("아이콘 4종, 대표 그래픽 1024×500 저장 완료")


if __name__ == "__main__":
    main()
