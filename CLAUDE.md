# 흥정왕 전당포 — Claude 작업 규칙

딜러스라이프2의 게임 시스템을 재현한 뒤 독자 콘텐츠로 발전시켜 구글 플레이에 출시하는 장기 프로젝트.
사용자(Vincent)는 한국어로 소통하는 개인 개발자이며, 구글 플레이 개인 개발자 계정으로 다른 게임을 출시한 경험이 있다.

## 원칙
- 규칙·구조는 원작을 따르되 이름·그림·대사·캐릭터는 전부 자체 제작한다. 원작의 이름·문구·그림을 가져오지 않는다.
- 게임 로직은 화면과 분리하고 헤드리스 테스트로 검증한다. 테스트가 깨진 상태로 main에 푸시하지 않는다.
- 콘텐츠(물건·손님·이벤트)는 `godot/data/*.json`에 둔다.
- 로드맵: `docs/ROADMAP.md` · 변경 내역: `docs/CHANGELOG.md` (이 저장소의 것이 기준)

## 환경
- 엔진: Godot 4.7.2. 작업 공간에 없으면 받는다:
  `curl -sSL -o /tmp/godot.zip https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip`
  → 별도 폴더에 압축 해제 → `--headless --path godot --import` → `--headless --path godot -s res://tests/run_tests.gd`
- CI: `.github/workflows/ci.yml` (푸시마다 헤드리스 테스트). 푸시 후 `gh run list -R alohakimbs/heungjeong-pawnshop`로 결과 확인.
- 웹 프로토타입 v0.2(참고): `web/index.html`, https://claude.ai/artifact/Nk7PV3mSaa26BNdmLksho7

## 구글 드라이브 (폴더 ID)
- 루트 「흥정왕 전당포」: 1W-VLuxaav7WgyNP9DwHYiY5DbTqIBurt
- 01_기획: 1Rv7mvBjQh5jbv8hgFfoxRxBOJ7qQIwdv (00_프로젝트 안내, 로드맵)
- 02_아트: 12Z8cUSxW1zzI7YtjsbM_01tmrTXYMnuQ
- 03_빌드: 1DsEfCHNQDot8wRVm_UP80NnQ_Hgi7emI
- 04_백업: 1RDWaCyc3hwj5GowVLpxpVm_FEId9goG2
- 05_일일 보고: 1AijXmoMFZrzYpKGvHk3JC-Sw7F5knT-S

## 사용자 요청 목록 (사용자만 할 수 있는 일)
- [ ] 저장소 공개 범위를 비공개로 전환 (권장)
- [ ] (M1 후반, PC) 업로드 키스토어 생성 → GitHub Secrets 등록
- [ ] (M2) 아트 공급 방식 결정: 외주 / 이미지 생성 / 직접
- [ ] (M4) 수익 모델 결정: 유료 / 광고 / 인앱
새로 생기면 여기에 추가하고 일일 보고에도 적는다.
