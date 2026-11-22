# 「흥정왕 전당포」 개발 이전 지시서 — ChatGPT용

> 작성: 2026-11-22 · 기준 버전 **1.12.0** (versionCode 31) · 저장소 `alohakimbs/heungjeong-pawnshop` main
> 이 문서 하나로 새 개발자(ChatGPT)가 프로젝트를 이어받아 같은 품질로 개발을 계속할 수 있게 쓴 문서다.
> 저장소 안 위치: `docs/HANDOFF_CHATGPT.md` · 드라이브 사본: 「흥정왕 전당포 › 01_기획」

---

## 0. 이 문서를 ChatGPT에서 쓰는 방법

### 0-1. 준비 (사용자가 한 번)
ChatGPT는 쓰는 기능에 따라 할 수 있는 일이 다르다. 둘 중 하나로 시작한다.

| 방식 | ChatGPT가 하는 일 | 사용자가 하는 일 |
|---|---|---|
| **A. 저장소에 직접 연결되는 코딩 기능** (GitHub 저장소를 열어 코드를 고치고 커밋·PR을 만드는 기능 — 쓰는 요금제에서 제공될 때) | 저장소를 읽고, 코드 수정, 테스트 실행, 브랜치·PR 생성 | PR 확인 후 main에 병합 → CI가 테스트 APK를 자동으로 만듦 |
| **B. 일반 대화 + 파일 첨부** (프로젝트 기능에 파일을 올려 두는 방식) | 첨부한 파일을 읽고 바꿀 코드·JSON을 통째로 써 줌 | 받은 파일을 PC의 저장소에 덮어쓰기 → Godot로 테스트 실행 → 커밋·푸시 |

- 방식 B로 할 때 ChatGPT 프로젝트에 올려 둘 파일(이 순서로 중요):
  1. 이 문서 `docs/HANDOFF_CHATGPT.md`
  2. `CLAUDE.md`(작업 규칙 원본), `docs/CHANGELOG.md`, `docs/ROADMAP.md`, `docs/WORLD_HANDOFF.md`
  3. 코드: `godot/scripts/core/game_state.gd`, `negotiation.gd`, `game_data.gd`, `godot/scripts/ui/shop_screen.gd`, `godot/tests/run_tests.gd`, `godot/tests/bots.gd`
  4. 데이터: `godot/data/*.json` 전부 (12개)
  5. 그림 기준: `docs/art/ref/ui_mock_haggle.png`, 화면 스크린샷 몇 장
- 저장소가 지금 **공개**다. 비공개로 바꾸면 방식 A는 GitHub 연결 권한을 줘야 하고, 방식 B는 영향 없음.

### 0-2. 새 대화 첫 메시지 (그대로 붙여 넣기)
```
너는 지금부터 모바일 게임 「흥정왕 전당포」의 개발 담당이야. 첨부한 HANDOFF_CHATGPT.md가 프로젝트 전체 인수인계 문서야.
1) 문서를 끝까지 읽고 ① 게임 핵심 루프 ② 코드 구조 ③ 지켜야 할 규칙 ④ 지금 남은 일을 각각 두세 줄로 요약해.
2) 앞으로 모든 작업은 문서 「8. 작업 규칙」을 따른다. 특히: 게임 로직은 game_state.gd에, 화면은 shop_screen.gd에, 콘텐츠는 data/*.json에. 로직을 바꾸면 run_tests.gd에 테스트를 추가하고, 버전과 CHANGELOG를 올린다.
3) 원작(딜러스라이프2)의 이름·대사·그림은 절대 가져오지 않는다. 세계관 미정 사항(행성명·정치체제·역사·종족·관문 이동 방식)은 임의로 확정하지 않는다. 이야기(스토리 장면)는 넣지 않는다.
4) 코드를 줄 때는 바꿀 파일 전체 또는 정확한 바꿀 부분(앞뒤 줄 포함)을 주고, 내가 실행할 테스트 명령도 함께 알려 줘.
요약이 끝나면 「10. 다음 개발 목록」의 1번부터 진행할지 물어봐.
```

---

## 1. 프로젝트 한눈에

- **무엇**: 딜러스라이프2(Abylight)의 **게임 시스템**을 재현하고, 이름·그림·대사·세계관은 전부 자체 제작한 **흥정 경영 게임**. 구글 플레이 **전 세계 출시** 목표.
- **사용자**: Vincent. 한국어로 소통하는 개인 개발자. 구글 플레이 개인 개발자 계정 보유(다른 게임 출시 경험 있음).
- **엔진**: Godot **4.7.2** (GDScript), 세로 화면 540x1170 기준.
- **핵심 루프 (2026-11-22 사용자 확정)**: 이야기 없이 **돈 벌기 → 가게 확장·이전 → 장비 강화 → 내 살림(집·창밖 풍경·탈것·우주선) 장만 → 급하면 살림 되팔기**. 사용자가 계속 하게 만드는 힘은 "다음 한 걸음"이 늘 보이는 성장 구조다.
- **세계관**: 봉래 성계의 수도 **운경**(산악 교역 도시, 옥 에너지, 부상열차, 짐꾼 로봇, 원형 교역 시설). 범동아시아 미래 과학 판타지. 기준 문서 `docs/WORLD_HANDOFF.md`(사용자 제공).
- **화풍**: **수묵 담채 반실사** (2026-11-22 확정). 그림은 사용자가 ChatGPT 이미지 생성으로 만들어 드라이브에 올린다.
- **UI 기준**: `docs/art/ref/ui_mock_haggle.png` — 화면 아래 먹빛·금테(옥빛) 패널: 물건 정보 / 손님 요구가 / 내 제안가 −·+ / 거래 거절·즉시 수락 / 큰 붉은 「제안하기」.

## 2. 지금 게임에 들어 있는 것 (1.12.0)

| 영역 | 내용 |
|---|---|
| 하루 흐름 | 아침(신문·가게 준비) → 패 뒤집어 개점 → 방문객 이벤트(있으면) → 손님 줄(사러 N·팔러 M) → 마감 영수증 → 다음 날 |
| 손님 | 종족 13종(인간 계열 7 + 외계 6), 성향 12종, 단골 8명(지난 거래 기억), 「거래합시다 / 필요 없소 / 나중에 오시오」 선택 → 나중에 미룬 손님은 줄 끝에 다시 옴 |
| 흥정 | 판매·구매·전당(맡기기). 제안가 −/+ (5% 단위), 즉시 수락, 거절, 스킬·직원·평판 조건 특수 선택지(설득 등) |
| 물건 | 10종류 83개, 희귀도 4단계 × 상태 5단계 × 시세, 가짜(8% 가치), 감정·수리·도매 처분, 보물 도감 |
| 성장 | 레벨·스킬 4종(흥정·감정·관상·화술), 직원 6종, 평판 |
| 가게 준비(아침, 운경 6곳) | 운경 상단 거리(가게 확장·이전·집·창밖 풍경·일꾼) / 월류시장(싼 매물, 가짜 섞임) / 천문항(귀한 매물·우주선·성간 경매) / 옥맥공방(장비 3종 강화·탈것·즉시 수리) / 설운관(내일 시세 관측) / 청경농원(홍보로 손님 +2) |
| 가게 | 5곳(수로 아래 좌판 → 다리목 전당 → 상단 거리 전당포 → 산 중턱 회랑 전당 → 운경 대전당), 가게마다 확장 3단계(창고 +3·손님 +1·평판 +10), 확장을 다 해야 이전 가능 |
| 내 살림 | 집 6단계(2단계마다 화술 +1, 새 집 사면 옛 집 자동 되팖), 창밖 풍경 6(집 단계 제한), 탈것 5(단계마다 시장 매물 3% 할인), 우주선 3(단계만큼 천문항 매물 +1), 언제든 70%에 되팔기 |
| 기타 | 방문객(불청객) 17종, 경매, 통계(셈판), 튜토리얼 카드, 효과음, 저장/불러오기, 파산 처리, 목표 막대(아침 화면) |
| 그림 | 전부 수묵 담채: 손님·단골 19명 × 표정 4, 직원 6, 방문객 16, 물건 83, 가게 배경 5, 소품 4, 장소 6, 타이틀 1 |
| 테스트 | 헤드리스 113개 + 무작위 봇 5명×30일, 숙련 봇 8명×30일 밸런스 |

## 3. 저장소 구조

```
.github/workflows/ci.yml        푸시마다: 헤드리스 테스트 → 통과하면 테스트 APK를 릴리스 test-latest에 올림
.github/workflows/release.yml   수동 실행: 출시용 AAB → 릴리스 aab-latest (Secrets 4개 있으면 정식 서명)
CLAUDE.md                       작업 규칙 원본 (이 문서와 내용이 겹치면 최신인 쪽을 따름)
docs/CHANGELOG.md               버전별 변경 내역 (맨 위에 새 버전 추가)
docs/ROADMAP.md                 마일스톤 M0~M4
docs/WORLD_HANDOFF.md           세계관 기준 문서(사용자 제공, 최우선)
docs/WORLD.md                   게임용 세계관 제안표
docs/STORY.md                   폐기(이야기 제거 결정) — 참고만
docs/art/                       ChatGPT 그림 지시서들, ref/ 기준 그림(아트북·UI 목업)
docs/art/chatgpt_handoff_2.md   남은 그림(내 살림·스토어) 지시서
docs/store/                     스토어 등록정보(한/영), 설문 초안, 개인정보처리방침, 대표 그래픽(임시)
tools/slice_sheets.py           ChatGPT 그림 시트 자르기 도구
web/index.html                  초기 웹 프로토타입 v0.2(참고용, 개발 안 함)
godot/
  project.godot                 config/version
  export_presets.cfg            안드로이드 내보내기 2종(APK·AAB), version/code·version/name (각 2곳)
  scenes/main.tscn              shop_screen.gd 하나를 붙인 씬
  scripts/core/game_data.gd     data/*.json 로드 (D.items, D.shops, D.belong …)
  scripts/core/game_state.gd    ★ 게임 로직 전부 (1,550줄). 화면 코드 없음
  scripts/core/negotiation.gd   ★ 손님 한 명과의 흥정 규칙 (순수 로직)
  scripts/ui/shop_screen.gd     ★ 화면 전부 (2,550줄). 렌더·버튼·모달·가게 준비·살림 화면
  scripts/ui/svg_art.gd         그림 파일이 없을 때 쓰는 코드 그림(SVG) — 지금은 거의 안 쓰임
  scripts/ui/item_art.gd        물건 코드 그림(대체용)
  scripts/ui/sfx.gd             효과음 합성
  data/*.json                   콘텐츠 (아래 5장)
  assets/chars|items|bg|ui|places|belong|icon   그림
  tests/run_tests.gd            ★ 헤드리스 테스트 진입점
  tests/bots.gd                 자동 플레이 봇(random / smart)
  tests/_shots.gd, _shots_table.gd   스크린샷 촬영 스크립트(개발용)
  tools/store_art.gd            아이콘·대표 그래픽 생성(xvfb 필요)
```

## 4. 핵심 시스템 (코드 읽기 지도)

### 4-1. 상태와 저장 — `game_state.gd`
- 모든 상태는 GameState의 변수. 저장되는 변수는 `FIELDS` 배열, 그중 정수는 `INT_FIELDS`. **새 상태 변수를 만들면 두 배열에 꼭 추가**(안 하면 저장이 안 됨). 저장 파일 `user://save.json`, `SAVE_VERSION=1`(형식이 크게 바뀔 때만 올림 — 올리면 옛 저장이 안 열림). 옛 저장에 없는 키는 기본값 유지, 모르는 키는 무시.
- `phase`: `morning` → `visit`(방문객) → `open`(영업) → `night`(마감). 가게 준비 기능은 대부분 `phase == "morning"`에서만 된다(`expand`는 예외로 언제든).
- 돈 기록은 `book(키, 금액)` → `today`에 쌓이고 마감 때 `history`로. 셈판 화면이 이걸 읽는다.

### 4-2. 물건 가치와 감정
- 진짜 가치 `val(it, true) = base × 희귀도배수 × 상태배수 × 오늘 시세`. 가짜는 `×0.08`.
- 감정 범위 `est(it)`: 진짜 가치를 항상 포함(테스트로 보장). 폭 `est_w() = max(0.06, 0.55 − 감정실력×0.07 − 감정사 0.2)`. 감정실력 `app_lv() = 감정 스킬 + 감정 렌즈 단계`.
- `gen_item(가짜확률, 보정)`: 가게 단계가 높을수록 귀한 물건과 비싼 base.

### 4-3. 흥정 — `negotiation.gd`
- 판매 손님: 요구가 `ask`는 마지노선 `min_price` 아래로 안 내려감. 구매 손님: 제시가 `offer`는 `max_price` 위로 안 올라감(테스트로 보장).
- 인내심 `patience`(기본 100, 성급 ×0.6, 느긋 ×1.5, 화술 레벨×8). 같은 값 반복 −15, 터무니없는 값은 크게 깎임, 자존심 강한 손님은 모욕적 가격에 바로 떠남.
- `line`(deal, counter, low, repeat, insulted, final_no, gave_up) → `data/lines.json`의 대사 키로 이어짐.
- 화술 실력 `charm_lv() = 화술 스킬 + 청동 향로 단계 + 집 단계/2`.

### 4-4. 손님 생성
- `gen_customer()`: 종족(archetypes) + 이름(text.json) + 성향(traits, 서로 충돌하는 조합 제외) + 사러/팔러/맡기러. 단골(specials)은 확률로 등장하고 `rel`에 지난 거래 결과를 기억해 인사가 달라짐.
- 하루 손님 수 `cust_base()(가게 손님 + 걸상 확장) + 점원 2 + 평판/25 + 홍보 보너스`. 아침에 사러(`plan_buy`)·팔러(`plan_sell`)로 나눠 상단에 숫자로 표시.

### 4-5. 가게 준비·성장
- 장비 `EQUIP`(lens·shelf·censer, 각 3단계, 비용 표 코드 상수). 확장 `shops.json`의 `ups`, 함수 `expand()`·`next_up_step()`·`can_move()`·`move_shop()`. 목표 막대 `goal()` → `{kind: up|move, n, cost, step, of}`, 끝이면 `{}`.
- 살림 `belongings.json` + `buy_belong(id)`·`sell_belong(id)`·`set_view(id)`·`best_lv(cat)`·`home_lv()`·`resale(id)`.
- 시장 매물 `stall(id)`: 하루 단위로 캐시. 할인(탈것)·추가 매물(우주선) 반영.

### 4-6. 화면 — `shop_screen.gd`
- 레이아웃 상수: `COUNTER_Y=620`(계산대 뒷선), `DESK_Y=720`(아래 패널 시작), 화면 540x1170.
- `render()`가 phase에 따라 `_render_morning / _render_haggle_desk / _offer_page …`를 그림. 버튼 도우미: `_jbtn(사각형, 글, 콜백, "dark|jade|jade2|red", 글자크기)`, 모달 시트 `sheet(...)` + `t()`(글) `btn()`(버튼).
- 손님 그림 `_char_tex(키, 표정)`: `assets/chars/<키>_<ok|happy|angry|meh>.png` → 없으면 `_ok` → 없으면 코드 그림. 직원 `s_<키>.png`, 방문객 `v_<키>.png`.
- 행동은 `_act(cb)`로 감싸면 저장·다시 그리기·효과(도장·돈 떠오름)·다음 손님 예약까지 처리됨.
- 가게 준비 `show_map()` → 장소 카드 목록 `_map_list` / 장소 장면 `_map_scene`(그림 좌우로 끌기) + `_place_actions(v, 장소id)`. 내 살림 `show_home()`. 장부 `show_menu()`.

## 5. 데이터 형식 (`godot/data/*.json`) — 콘텐츠는 여기만 고치면 됨

| 파일 | 형식 | 예 / 주의 |
|---|---|---|
| items.json | `categories.<키>.{n, up, dn, items:[[이름, 아이콘키, 기본값]]}`, `rarity[]`, `condition[]` | 아이콘키 = `assets/items/<키>.png`. 한 종류 최대 9개(그림 시트가 3x3) |
| shops.json | `[{n, rent, st(창고), cust(손님), cost(이전비), wall, ups:[{n, k:room|seat|sign, cost}]}]` | 5개 |
| belongings.json | `resale`, `home[]{id,n,lv,cost,d}`, `view[]{id,n,img,cost,need}`, `ride[]`, `ship[]` | view의 img = `assets/places/<img>.jpg` |
| archetypes.json | `[{id, n, tic[], species}]` | id = 그림 키 |
| specials.json | 단골 `{키:{n, role, tr[], tic[], hi, cb{steal,fair,angry,scam}, …}}` | `granny`의 그림은 `granny_junk` |
| events.json | 방문객 `{키:{n, d, opts[], res[[{money, rep, md, t…}]], art?}}` | `art` 없으면 `v_<키>.png` |
| staff.json | `{키:{n, pn, d, q, w(일급)}}` | 그림 `s_<키>.png` |
| traits.json | `traits{키:{n,d}}`, `conflicts[]` | |
| lines.json | 대사 `{키:[문장…]}`, `{item}`·`{price}` 치환 | |
| text.json | 신문 제목·단신·성·이름·경매 상대 | |
| tips.json | 오늘의 비결 | |
| trips.json | 장소 6곳 `{n, sub, img, fare, d, lore}` | 순서 = 지도 카드 순서 |

**콘텐츠 문구 규칙**: 돈 단위는 「냥」(별냥), `$`·현대 지명·실제 국가 금지, 「조선·결계·천강석·다섯 구역·고리 교역항」 같은 폐기된 용어 금지. 테스트 `test_all_events`가 `$` 표기를 검사한다.

## 6. 개발 환경과 명령

```bash
# Godot 받기 (리눅스 예)
curl -sSL -o godot.zip https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip
unzip godot.zip  # → Godot_v4.7.2-stable_linux.x86_64
G=./Godot_v4.7.2-stable_linux.x86_64

$G --headless --path godot --import                        # 처음 한 번, 그림 추가 후마다
$G --headless --path godot -s res://tests/run_tests.gd     # 테스트 → 마지막 줄 "결과: N 통과, 0 실패"
$G --headless --path godot --check-only -s res://scripts/ui/shop_screen.gd   # 문법 오류만 빠르게
xvfb-run -a -s "-screen 0 1080x2340x24" $G --path godot --rendering-driver opengl3 --resolution 1080x2340 -s res://tests/_shots_table.gd   # 스크린샷 → /tmp/tshot_*.png
```
- 윈도우·맥: Godot 4.7.2 에디터를 받아 `godot` 폴더를 열면 됨. 테스트는 같은 명령에서 실행 파일 경로만 바꾸기.
- **자주 걸리는 함정**
  - GDScript `var x := 사전["키"]`처럼 Variant에 `:=`를 쓰면 파싱 오류 → `var x: int = …`처럼 타입을 적는다. 파싱 오류가 나면 화면이 통째로 안 뜬다(테스트 `test_ui_smoke`가 잡음).
  - `GameState.fmt(n)`은 이미 「냥」을 붙인다. 문장에 「냥」을 또 쓰지 말 것.
  - 큐에서 지운 노드도 한 프레임 남는다 → 개수 셀 때 `is_queued_for_deletion()` 제외.
  - 그림 import는 손실 압축(`compress/mode=1`, `lossy_quality=0.85`)으로. 무손실이면 APK가 커짐(지금 약 90MB → 줄이는 게 과제).
  - `.gitignore`가 `.import`를 막지만 `godot/assets/chars|items|bg/*.import`는 예외로 올린다(손실 압축 설정 보존).

## 7. 빌드·출시

- **테스트 APK**: main에 푸시 → CI(`ci.yml`) 테스트 통과 → 릴리스 **test-latest**의 `heungjeong-test.apk` 갱신. 사용자 휴대폰 설치 주소: https://github.com/alohakimbs/heungjeong-pawnshop/releases/tag/test-latest
- **출시용 AAB**: GitHub → Actions → 「출시용 AAB」 → Run workflow (또는 `gh api -X POST repos/alohakimbs/heungjeong-pawnshop/actions/workflows/release.yml/dispatches -f ref=main`) → 릴리스 **aab-latest**.
  - Secrets 4개 `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`가 있으면 정식 서명, 없으면 임시 서명(업로드 불가). **업로드 키는 사용자 소유** — ChatGPT는 키 파일·비밀번호를 받거나 다루지 않는다. 안내 문서는 드라이브 「06_출시 준비」.
- 패키지 이름 `com.alohakimbs.heungjeong`, 대상 API 36.
- **버전 올리기(매 반영마다)**: `godot/project.godot`의 `config/version`, `godot/export_presets.cfg`의 `version/code`(정수 +1)·`version/name` **각 2곳**, `docs/CHANGELOG.md` 맨 위 항목.

## 8. 작업 규칙 (꼭 지킬 것)

1. **원작 복제 금지**: 딜러스라이프2의 이름·문구·그림·캐릭터를 가져오지 않는다. 시스템(규칙·구조)만 참고.
2. **이야기 장면 넣지 않기**(사용자 결정). 세계관은 배경·손님·장소·문구의 분위기로만.
3. **세계관**: `WORLD_HANDOFF.md`의 「현재 시안 / 확장 제안 / 미정」 구분. 미정(행성명·정치체제·역사·종족 구성·관문 이동 방식)은 확정하지 않는다. 조선 등 특정 국가 역사·국가 상징·네온·기존 작품(와칸다 등) 복제 금지. 중국·일본 등 전 세계 사용자가 거부감 없게.
4. **구조**: 로직은 `game_state.gd`/`negotiation.gd`(화면 코드 금지), 화면은 `shop_screen.gd`, 콘텐츠는 `data/*.json`.
5. **테스트**: 로직을 바꾸면 `run_tests.gd`에 테스트 추가. **테스트가 깨진 상태로 main에 넣지 않는다.** 밸런스를 바꾸면 `test_sim_smart` 결과(30일 순자산·가게 단계)를 확인하고 CHANGELOG에 적는다.
6. **기록**: 매 반영마다 버전 +1, CHANGELOG, 필요하면 ROADMAP 체크. 사용자만 할 수 있는 일이 생기면 `CLAUDE.md`의 「사용자 요청 목록」에 추가.
7. **되돌릴 수 없는 일 금지**: 저장소 삭제·강제 푸시·Play Console 조작·결제·저장소 공개 범위 변경은 하지 않는다(사용자에게 요청).
8. **새 제안은 따로 보고**: 사용자가 정하지 않은 설정·수치를 새로 넣으면 "새로 제안한 것" 목록으로 분리해 알린다.
9. 사용자에게 보고할 때: 한국어, 결과 먼저, 짧게. 바뀐 화면은 스크린샷으로 보여 준다.

## 9. 그림 작업 흐름

- 사용자가 ChatGPT 이미지 생성으로 시트를 만들어 구글 드라이브 「흥정왕 전당포 › 02_아트 › 수묵_최종」(폴더 ID `19kPE_Bxa6CKxM-ngt3E9WgLLsgr2Vc1V`)에 올린다.
- 형식: 인물 = 세로 2:3, 2x2 표정(왼위 ok, 오른위 happy, 왼아래 angry, 오른아래 meh), 무릎 위 반신, 투명 배경. 직원·방문객 = 2x2 서로 다른 인물. 물건·살림 = 정사각형 3x3, 칸 순서 = JSON 순서. 배경 = 2:3.
- 자르기: `python3 tools/slice_sheets.py <char|quad|grid3|props|bg> <시트.png> <이름1,이름2,…> <출력폴더>` (Pillow·numpy·scipy 필요). 예:
  - `python3 tools/slice_sheets.py char toad.png toad godot/assets/chars`
  - `python3 tools/slice_sheets.py grid3 belong_1.png backroom,alley,canal,garden,pavilion,skygarden,cart,bike,pass godot/assets/belong`
  - `python3 tools/slice_sheets.py grid3 belong_2.png hover,limo,skiff,freighter,clipper,,,, godot/assets/belong`
- 넣은 뒤: Godot import → `.import` 파일을 손실 압축으로 → 스크린샷으로 확인.
- 남은 그림 지시서: `docs/art/chatgpt_handoff_2.md` (내 살림 belong_1·2, 앱 아이콘, 대표 그래픽) → 드라이브 「수묵_최종 › H_살림_스토어」(`1Z-125ko9RghC94wZkUTiI54xdWpSOOdR`). 코드는 `assets/belong/<id>.png`가 있으면 자동으로 보여 준다.

**구글 드라이브 폴더 ID**
| 폴더 | ID |
|---|---|
| 루트 「흥정왕 전당포」 | 1W-VLuxaav7WgyNP9DwHYiY5DbTqIBurt |
| 01_기획 | 1Rv7mvBjQh5jbv8hgFfoxRxBOJ7qQIwdv |
| 02_아트 | 12Z8cUSxW1zzI7YtjsbM_01tmrTXYMnuQ |
| 02_아트 › 수묵_최종 | 19kPE_Bxa6CKxM-ngt3E9WgLLsgr2Vc1V |
| 03_빌드 | 1DsEfCHNQDot8wRVm_UP80NnQ_Hgi7emI |
| 04_백업 | 1RDWaCyc3hwj5GowVLpxpVm_FEId9goG2 |
| 05_일일 보고 | 1AijXmoMFZrzYpKGvHk3JC-Sw7F5knT-S |
| 06_출시 준비 | 1DCH_r_2H5V64TbfNQeAeKUpTKpQK_BO6 |

## 10. 다음 개발 목록 (우선순위 순, 제안)

1. **휴대폰 플레이 피드백 반영** — 사용자가 테스트 APK를 해 보고 말한 것을 최우선으로.
2. **밸런스 재조정** — 1.11.0에서 확장 3단계(가게마다)와 이전 비용 인하를 넣었다. 숙련 봇 30일 결과가 순자산 중앙값 약 1.75만 냥(1.1만~2.8만), 8명 중 7명이 첫 이전. 살림 가격(집 최대 150만, 우주선 최대 250만)이 후반 목표로 적절한지 60~120일 봇으로 확인.
3. **살림 그림 넣기** — 사용자가 `belong_1/2.png`를 올리면 자르기(9장 참고).
4. **APK 용량 줄이기**(약 90MB) — 큰 인물 그림 해상도 축소(표시 높이 500px 기준 1.2배면 충분), 배경 webp/손실 압축 확인, 쓰지 않는 그림(예전 SVG 대체 코드 경로) 정리.
5. **연출** — 화면 전환, 거래 성사 도장·돈 소리 강화, 가게 확장·이전 축하 장면, 살림 장만 장면(창밖 풍경 전환).
6. **콘텐츠** — 물건 200종(지금 83; 종류당 9개 제한 → 새 종류 추가 또는 시트 추가), 방문객 이벤트 40종(지금 17), 단골 연속 사연(며칠 이어지는 부탁 — 「이야기 장면」이 아니라 거래 의뢰 형태로).
7. **원작에 있는 확장 요소** — 수집 세트 보상, 의뢰(특정 물건 구해 오기), 주간 시세 사이클.
8. **접근성** — 글자 크기 설정, 색 대비 점검.
9. **출시 준비** — 대표 그래픽·아이콘 교체(그림 오면), 스크린샷 8장, 등록정보 문구 최신화(이야기 제거·살림 추가 반영).

## 11. 사용자만 할 수 있는 일 (현재)
- [ ] 저장소를 비공개로 전환 (권장)
- [ ] 휴대폰에 테스트 APK 설치 후 플레이 피드백
- [ ] (PC) 업로드 키 생성 → GitHub Secrets 4개 등록 (드라이브 06_출시 준비 안내 문서)
- [ ] 게임 이름 확정 (가제 「흥정왕 전당포」, 상표 검색)
- [ ] 개인정보처리방침 공개 URL + 개발자 이메일 (초안 `docs/store/privacy_policy.md`)
- [ ] 수익 모델 결정: 유료 / 광고 / 인앱
- [ ] ChatGPT로 남은 그림 4장 (`docs/art/chatgpt_handoff_2.md`)
- [ ] ChatGPT 생성 이미지의 상업적 이용 조건 확인

## 12. 사용자가 확인하지 않은 설정 (임시값 — 바꿔도 됨)
- 장소별 기능 배치(6곳), 장비 가격, 가게 확장 이름·가격, 살림 목록·가격·효과(집 2단계마다 화술+1, 탈것 할인 3%/단계, 우주선 매물 +1/단계, 되팔기 70%).
- 손님 종족 이름(월궁 토끼족·뿔족·해파리족 등)과 단골 설정 — 세계관 문서상 종족 구성은 「미정」이므로 게임 안 표현으로만 쓰고 공식 설정으로 굳히지 않는다.

## 13. 지금까지 사용자가 준 주요 방향 (판단 기준)
- "딜러스라이프2처럼 진행이 빠르고 경쾌해야" → 손님이 오자마자 물건과 값을 바로 말하고, 다음 손님은 0.9초 뒤 자동 등장.
- "배경에 녹아드는 UI" → 계산대·패·현판 같은 소품이 버튼. 튀는 버튼 금지. "최종 제안 따로 둘 이유 없음", "버튼이 너무 아래" → 한 패널에 모음.
- "기다리는 손님은 숫자로" → 대기 줄 그림 없음, 상단에 사러/팔러 남은 수.
- "조선 강조 아님, 미래 우주의 동양 느낌, 중·일 사용자도 거부감 없게."
- "유아적 그림 싫음" → 수묵 담채 반실사.
- "장소는 그냥 구경이 아니라 기능" → 장비 강화는 여기, 가게 업그레이드는 여기, 물건 사기는 여기.
- "스토리 없이 돈 벌고 가게 키우는 게 계속하게 만드는 요인", "가게 확장을 세부 단계로, 집·집 배경·차·우주선 사고 급하면 되팔기."
