# 흥정왕 전당포 — 가벼운 개발 재개 메모

기준일: 2026-11-22. 이전 대화의 이미지나 대형 로그를 다시 읽지 않고 저장소에서 이어서 작업하기 위한 메모.

## 현재 상태

- 저장소: https://github.com/alohakimbs/heungjeong-pawnshop
- 작업 브랜치: `codex/growth-audit-1.13`
- PR: https://github.com/alohakimbs/heungjeong-pawnshop/pull/1
- 버전: 1.13.0 / versionCode 32 / Godot 4.7.2
- 기능 코드 커밋: `ae286144052b63b6633936fc797deaaf01667e69`
- 마지막 확인한 문서 커밋: `eb42125d9c1a276870a6fe5382652ad8f535668e`. 작업 전 최신 head를 다시 확인한다.
- main은 아직 1.12.0. PR 병합은 인수 지시서의 사용자 검토 단계다.
- 최신 확인 CI: https://github.com/alohakimbs/heungjeong-pawnshop/actions/runs/44989330427 — 성공.
- 테스트 129개 통과. 성장 봇 32개 시드×120일, 추가 8개 시드×240일 진단 기록 존재.
- APK 84,087,802 bytes. 패키지 `com.alohakimbs.heungjeong`, targetSdk 36. 휴대폰 설치·터치·성능은 미검증.

## 완료한 변경

집 6채·탈것 5종·우주선 3종, 수묵 아이콘·대표 그래픽, 실제 화면 8장을 적용했다. 무료 집 환급·집 단계와 풍경 자격·살림 및 가게 이전 장부 오류를 수정했다. 마감에 살림을 팔아 영업을 재개하는 흐름을 검증했다. 원본 인물을 보존하고 실행용 이미지 크기와 압축을 조정했다.

## 유지할 규칙

이야기 장면 없이 거래 → 가게·장비 성장 → 살림 장만·급전 되팔기가 핵심이다. 세계관은 봉래 성계 운경, 수묵 담채 반실사다. 미정 세계 설정을 확정하지 않는다. 게임 로직은 core, 화면은 ui, 콘텐츠는 data/*.json에 둔다. 로직 변경에는 회귀 테스트와 버전·CHANGELOG 갱신이 필요하다.

## 다음 작업

1. 휴대폰 플레이 피드백이 도착하면 최우선 반영한다.
2. 없으면 전환·거래·가게 성장 연출, 가독성·접근성을 점검한다. 새로운 성장 수치는 검증 후 별도 제안한다.
3. 물건 200종·방문객 40종·의뢰·주간 시세는 아직 후속 범위다. 현재 물건 83종·방문객 17종이다.

상세 근거: `docs/qa/1.13.0/REPORT.md`. 전체 규칙: `CLAUDE.md`, `docs/HANDOFF_CHATGPT.md`, `docs/WORLD_HANDOFF.md`. 대화 출력은 `AGENTS.md`에 따라 작게 유지한다. ChatGPT 앱 종료 문제와 게임 APK 결함을 구분한다.

## 새 대화에 붙여 넣을 문장

`alohakimbs/heungjeong-pawnshop`의 PR #1과 `docs/RESUME_LIGHT.md`, `AGENTS.md`를 확인하고 개발을 이어서 진행해줘. 기존 수묵 세계관과 이야기 없는 성장 구조를 유지하고, 대형 로그와 이미지 미리보기는 대화에 출력하지 말아줘. main 병합은 기존 인수 지시서의 검토 절차를 따라줘.
