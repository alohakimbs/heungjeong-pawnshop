# 흥정왕 전당포 — Claude 작업 규칙

딜러스라이프2의 게임 시스템을 재현한 뒤 독자 콘텐츠로 발전시켜 구글 플레이에 출시하는 장기 프로젝트.
사용자(Vincent)는 한국어로 소통하는 개인 개발자이며, 구글 플레이 개인 개발자 계정으로 다른 게임을 출시한 경험이 있다.

## 원칙
- 규칙·구조는 원작을 따르되 이름·그림·대사·캐릭터는 전부 자체 제작한다. 원작의 이름·문구·그림을 가져오지 않는다.
- 게임 로직은 화면과 분리하고 헤드리스 테스트로 검증한다. 테스트가 깨진 상태로 main에 푸시하지 않는다.
- 콘텐츠(물건·손님·이벤트)는 `godot/data/*.json`에 둔다.
- 세계관: **기준 문서 `docs/WORLD_HANDOFF.md`**(사용자 제공) + 게임 제안 `docs/WORLD.md`. 수도 운경(산악 교역 도시, 옥 에너지, 부상열차, 짐꾼 로봇, 원형 교역 시설). 「현재 시안 / 확장 제안 / 미정」을 구분하고, 미정(행성명·정치체제·역사·종족·관문 이동 방식)은 임의로 확정하지 않는다. 조선·특정 국가 역사·국가 상징·네온·기존 작품 복제 금지. 기준 그림 `docs/art/ref/`(아트북 6장: 운경·천문항·월류시장·옥맥공방·청경농원·설운관 → 나들이 장소 그림 `godot/assets/places/`).
- UI 기준: `docs/art/ref/ui_mock_haggle.png` — 아래 먹빛·금테 패널(물건 정보 / 손님 요구가 / 내 제안가 −·+ / 거래 거절·수락 / 붉은 「제안하기」).
- 로드맵: `docs/ROADMAP.md` · 변경 내역: `docs/CHANGELOG.md` (이 저장소의 것이 기준)

## 환경
- 엔진: Godot 4.7.2. 작업 공간에 없으면 받는다:
  `curl -sSL -o /tmp/godot.zip https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip`
  → 별도 폴더에 압축 해제 → `--headless --path godot --import` → `--headless --path godot -s res://tests/run_tests.gd`
- CI: `.github/workflows/ci.yml` (푸시마다 헤드리스 테스트). 푸시 후 `gh run list -R alohakimbs/heungjeong-pawnshop`로 결과 확인.
- 테스트 APK: main 푸시 → CI가 GitHub 릴리스 `test-latest`에 `heungjeong-test.apk` 갱신. 내려받기: `curl -sSL -o x.apk https://github.com/alohakimbs/heungjeong-pawnshop/releases/download/test-latest/heungjeong-test.apk` (Actions 아티팩트 저장소는 작업 공간에서 차단됨). 릴리스 조회는 `gh api repos/alohakimbs/heungjeong-pawnshop/releases/tags/test-latest` (GraphQL 차단).
- 화면 스크린샷: `xvfb-run -a -s "-screen 0 540x1170x24" godot --path godot --rendering-driver opengl3 --resolution 540x1170 -s res://tests/_shots.gd` → /tmp/shot_*.png
- 드라이브 업로드: 큰 파일(APK 60MB)은 파일 참조 업로드가 안 됨 → 링크만 문서로 남긴다. 작은 이미지는 작업 폴더(/home/claude 아래)에 두고 sha256 참조로 업로드.
- 출시용 AAB: Actions 「출시용 AAB」 수동 실행(`gh api -X POST repos/alohakimbs/heungjeong-pawnshop/actions/workflows/release.yml/dispatches -f ref=main`) → 릴리스 `aab-latest`. 업로드 키 Secrets 4개가 있으면 정식 서명.
- 스토어 문서: `docs/store/`, 아이콘·그래픽 생성: `tools/store_art.gd` (xvfb 필요)
- 개인정보처리방침 페이지(비공개 상태): https://claude.ai/artifact/2Jq7oLhZK2Nk3Y7jEGd7c6
- 웹 프로토타입 v0.2(참고): `web/index.html`, https://claude.ai/artifact/Nk7PV3mSaa26BNdmLksho7

## 구글 드라이브 (폴더 ID)
- 루트 「흥정왕 전당포」: 1W-VLuxaav7WgyNP9DwHYiY5DbTqIBurt
- 01_기획: 1Rv7mvBjQh5jbv8hgFfoxRxBOJ7qQIwdv (00_프로젝트 안내, 로드맵)
- 02_아트: 12Z8cUSxW1zzI7YtjsbM_01tmrTXYMnuQ
  - 캐릭터_원본: 1ywMFiklUnrESvagA870V6IYT0Xt36wV5 (사용자가 ChatGPT로 만든 그림을 올림, 프롬프트 문서 `docs/art/chatgpt_prompts.md`)
    - 0_화풍기준 1Nd0Y5pSFzlF9_lAkIQWoN93f_1H3dG5k · 1_손님 1NCO1RYdZMHGRisiJXhmdgVdYIgBnWo0U · 2_단골 1sAGMoSk15xpTPhlc5xy_WfTdTrxt0ym- · 3_직원 1cfsYqagD9Bz-12_aNP_5vTXLytRFS1dX · 4_불청객 1C7SkHO9BIBrSsBH9m4VQPBu5EwPtTZ-8
    - (2026-11-21 변경) 시트 방식: 손님·단골은 `키.png` 한 장에 2x2 표정(왼위 ok, 오른위 happy, 왼아래 angry, 오른아래 meh). 직원 `staff_1.png`(expert, restorer, profiler, analyst) `staff_2.png`(clerk, guard), 불청객 `visit_1.png`(insurance, grandma, tax, blackout) `visit_2.png`(fortune, rival, puppy, blogger) `visit_3.png`(rain) (선택: `visit_4.png` scholar, ricecake, peddler, goblin · `visit_5.png` errand, inspector, herbal — 오면 `v_키_ok.png`로 넣고 events.json의 `art` 키 삭제) — 2x2 칸 순서 왼위→오른위→왼아래→오른아래. 칸 단위로 잘라 쓴다. 단골 고물 할멈은 `granny_junk`(specials.json의 granny). 그림이 들어오면: 내려받기 → 배경 정리·크기 맞춤 → `godot/assets/chars/` → SvgArt 대신 텍스처 사용(없는 캐릭터는 코드 그림 유지) → 스크린샷 확인.
  - 계산대 소품 `props.png`(2x2: chest, books, cushion, seal) → `godot/assets/ui/` 적용 완료 (2026-11-22)
  - 수묵_최종: 19kPE_Bxa6CKxM-ngt3E9WgLLsgr2Vc1V — **최종 화풍 「수묵 담채 반실사」(2026-11-22 결정)로 전부 새로 그린 그림**. 지시서 `docs/art/chatgpt_sumuk_final.md`. 인물 시트는 2x2 표정·무릎 위까지(반신). 새 배치: staff_1/2 그대로, visit_1(insurance,grandma,tax,blackout) visit_2(fortune,rival,puppy,blogger) visit_3(rain,scholar,ricecake,peddler) visit_4(goblin,errand,inspector,herbal) → `v_키_ok.png`, events.json `art` 키 삭제. fox=홍란, mrq=백운(청운 도사). 들어오면 기존 그림을 전부 교체. 반신이라 손님 표시 크기·위치 다시 맞출 것.
  - 봉래_수정본(폐기 — 수묵_최종으로 대체): 1yT_4BHOxH1vuZVe16GMYptGWUI-g9wy0 — 기존 그림 전체를 봉래 세계관으로 고친 것(같은 파일 이름). 지시서 `docs/art/chatgpt_rework_bongnae.md`. 들어오면 캐릭터·물건·배경을 같은 방법으로 잘라 교체. `mukhyang.png`(이야기 맞수, 2x2 표정) → `mukhyang_표정.png`
  - 물건·배경_원본: 1KcArXXuKToAANwbzPHqJckFBBTcDMqNn (프롬프트 `docs/art/chatgpt_prompts_items_bg.md`). `items_<종류키>.png` 3x3(행 순서 = items.json 순서) → 잘라서 `godot/assets/items/<아이콘키>.png`; `bg_0~4.png`(2:3) → `godot/assets/bg/bg_N.png`. 코드는 파일이 있으면 자동 사용. import는 손실 압축(compress/mode=1, 0.85)으로 바꿀 것.
- 03_빌드: 1DsEfCHNQDot8wRVm_UP80NnQ_Hgi7emI
- 04_백업: 1RDWaCyc3hwj5GowVLpxpVm_FEId9goG2
- 05_일일 보고: 1AijXmoMFZrzYpKGvHk3JC-Sw7F5knT-S
- 06_출시 준비: 1DCH_r_2H5V64TbfNQeAeKUpTKpQK_BO6 (등록정보·설문·업로드 키 안내·그래픽)

## 사용자 요청 목록 (사용자만 할 수 있는 일)
- [ ] 저장소 공개 범위를 비공개로 전환 (권장)
- [ ] (휴대폰) 테스트 APK 설치 후 플레이 감각 피드백: https://github.com/alohakimbs/heungjeong-pawnshop/releases/tag/test-latest
- [ ] (PC) 업로드 키 생성 → GitHub Secrets 4개 등록 — 드라이브 06_출시 준비의 안내 문서 참고
- [ ] 게임 이름 확정 (가제 「흥정왕 전당포」, 상표 검색)
- [ ] 개인정보처리방침 공개 URL 준비 (아티팩트 공개 공유 또는 다른 공개 주소) + 개발자 이메일
- [x] (M2) 아트 공급 방식: 사용자가 ChatGPT 이미지 생성으로 캐릭터를 만들어 드라이브에 올림 (2026-11-21 결정)
- [x] 캐릭터 시트 20장 업로드 (2026-11-21, 폴더 1131cRcnz4He3F5laRQD7eZhhEyPQYEnJ) → `godot/assets/chars/` 75장 적용. 경매 상대 3명은 단골·손님 그림 재사용
- [x] 물건 시트 10장 + 가게 배경 5장 업로드 → 적용 완료 (2026-11-21)
- [ ] 수묵 담채 반실사로 전체 그림 새로 그리기(인물 시트 22장 + 직원·방문객 6장 + 물건 10장 + 배경 5장 + 소품 1장) — `docs/art/chatgpt_sumuk_final.md`, 드라이브 「수묵_최종」
- [ ] (M4) 수익 모델 결정: 유료 / 광고 / 인앱
새로 생기면 여기에 추가하고 일일 보고에도 적는다.

## 사용자 결정 대기 중일 때 할 일
결정이 필요한 항목(아트·수익 모델·이름)에 막혀도 멈추지 말고 다음을 한다:
화면 다듬기(애니메이션·전환·가독성), 버그 수정, 밸런스(봇 시뮬레이션), 콘텐츠(물건·이벤트·단골 사연·대사), 접근성(글자 크기·색 대비), 테스트 보강.
