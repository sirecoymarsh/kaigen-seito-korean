# 계엄성도 한국어 패치

**v2026.11.26-r5 통합 검수판 + r5.1 · r5.2 소형 업데이트**

니트로플러스 『사바토 나베』 수록 『계엄성도』 Windows판의 한국어 패치입니다. 시나리오·UI 한국어화에 탐색·전투 편의 기능, 확장 기록실, 한국어 오프닝, 최신 저장 이어하기를 통합했습니다. 전체 분기 재완주 검수는 끝나지 않아 **Pre-release**로 배포합니다.

[패치 다운로드](https://github.com/sirecoymarsh/kaigen-seito-korean/releases/tag/v2026.11.26-r5) · [전체 수정 사항](docs/CHANGELOG.ko.md) · [조작·모드 안내](docs/CONTROLS.md) · [검증 범위와 남은 제한](docs/STATUS.md)

## r5.2 소형 업데이트

[소형 업데이트 다운로드](https://github.com/sirecoymarsh/kaigen-seito-korean/releases/tag/v2026.11.27-r5.2) · [수정·검증 범위](docs/HOTFIX-r5.2.ko.md)

오프닝 검은 화면, 크기 조절 후 전투 복귀 시 미니맵 표시 누락, 큰 창에서 타이틀 가사 자막이 잘리는 문제를 고칩니다. **r5 → r5.1 → r5.2 순서**로 설치하세요. r5.2도 `ko.dll` 변경분만 포함하며 저장·설정·영상은 바꾸지 않습니다.

## r5.1 소형 업데이트

[소형 업데이트 다운로드](https://github.com/sirecoymarsh/kaigen-seito-korean/releases/tag/v2026.11.27-r5.1) · [수정·검증 범위](docs/HOTFIX-r5.1.ko.md)

부지사 자동 항복과 실제 창 테두리 크기 조절을 고칩니다. **아래 r5 통합본을 설치한 뒤** r5.1 ZIP의 `Install.cmd`를 실행하세요. 변경분은 `ko.dll` 하나이며 영상·PAK·SAVE·설정은 그대로입니다. 저장소 루트의 통합 설치기와 아래 통합본 링크는 r5 기준이고, 소형 업데이트는 `updates/r5.1`에 따로 있습니다.

## 다운로드

- `KaigenSeito-Korean-v2026.11.26-r5.zip`: 설치·검사·원본 복원 도구와 패치 차분.
- `KaigenSeito-PV-Korean.mp4`: 별도 감상·공유용 한국어 프로모션 영상. **9,633,133바이트(9.63MB)**로 50MB 미만입니다.
- `KaigenSeito-Changes-v2026.11.26-r5.md`: 전체 수정 사항을 따로 읽을 수 있는 문서.
- `SHA256SUMS.txt`: 내려받은 파일의 SHA-256.

완성된 PV의 검증된 파일을 재사용하여 추가 압축에 따른 화질 손실을 피했습니다. 게임에 들어가는 오프닝은 엔진 규격의 MPEG이며 MP4와 별도입니다.

## 설치와 업데이트

1. 원본 게임 또는 이 저장소의 r4a·r4b를 설치한 게임을 준비하고 종료합니다.
2. 패치 ZIP을 **게임 폴더와 다른 폴더**에 풉니다.
3. `Install.cmd`를 실행하고 `KaigenSeito.exe`가 있는 게임 폴더를 선택합니다.
4. ‘설치 통과’가 나오면 `KaigenSeito.exe`를 실행합니다. `Verify.cmd`로 파일 일치 여부를 다시 확인할 수 있습니다.

Windows 10/11 x64, Windows PowerShell 5.1 이상과 Windows 기본 글꼴 맑은 고딕을 사용합니다. Locale Emulator·일본어 시스템 로캘·설치 중 인터넷 연결은 필요하지 않습니다. Microsoft 글꼴은 배포하지 않습니다. 설치·교체 과정에는 **약 1GB의 여유 공간**을 확보하세요.

r4a·r4b는 기존 원본 백업을 유지한 채 r5로 업데이트합니다. 이전 백업에 없던 `mpeg.pak`는 현재 게임의 파일이 확인된 원본과 일치할 때에만 백업에 추가합니다. 다른 비공식 수정본·개발 중간판은 자동으로 덮어쓰지 않습니다. [지원 원본 해시](docs/original-files.json)와 다른 판본에는 적용하지 않으며 링크·정션을 경유한 게임 폴더도 거부합니다.

## 저장과 원본 복원

개인 `SAVE`·`.ini`·로그는 패키지에 포함하지 않으며 설치·복원 때 변경하지 않습니다. 기존 이야기 대본의 저장 위치에 영향을 주는 명령 배열을 보존한 통합본입니다. 모든 저장 시점과 분기의 호환성을 검증한 것은 아닙니다.

원본 7개 파일은 게임 폴더의 `.kaigen-ko-backup`에 보관합니다. r4a의 `.kaigen-ko-backup-r4a`는 설치 시 이 이름으로 이전합니다. **원본 백업을 보존하세요.** 게임 종료 후 `Restore.cmd`에서 같은 폴더를 고르면 원본을 복구하고 추가한 `ko.dll`을 제거합니다. 저장·설정·원본 백업은 남습니다.

설치기는 모든 차분 적용 결과를 임시 공간에서 먼저 검사한 뒤 교체합니다. 교체 오류가 발생하면 원본으로 복구합니다. 정전·강제 종료 뒤에는 백업을 보존하고, 설치기가 종료되었는지 확인한 다음 남은 `.kaigen-ko-install.lock`을 제거하고 복원을 실행할 수 있습니다. 알 수 없는 파일 변경은 자동 복원도 거부합니다.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Patch.ps1 -Action Install -GameDir 'D:\Games\KaigenSeito'
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Patch.ps1 -Action Verify  -GameDir 'D:\Games\KaigenSeito'
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Patch.ps1 -Action Restore -GameDir 'D:\Games\KaigenSeito'
```

## 주요 기능

- 한국어 대사·선택지·이미지 UI·설정·저장 설명, 줄바꿈과 긴 대화창의 페이지 처리.
- 방향키 즉시 이동, 문을 포함한 미니맵 클릭 이동, 조건을 반영하는 통합 마커와 다음 목표.
- 수동·어시스트·자동 선택, 기대 피해 추천, 불리한 전투 경고와 특수 전투 대응.
- 전투·이벤트 종료 후 자동 저장, 가장 최근 수동·빠른·자동 저장을 불러오는 타이틀 ‘이어하기’.
- 한 화면의 검기 사용·기억하기, 선택형 스테이터스·아이템·장비 통합 메뉴.
- 경험치·주는 피해·받는 피해·조우·자동 이동 속도 등 선택형 모드와 그림을 곁들인 설명.
- 썸네일 CG 감상, 구역별 장면 다시보기 38개, 음악 26곡, 하나치라스 요약 11항목.
- 첫 실행 한국어 오프닝, 타이틀 로고 선택, 창 크기 조절, 설정 탭 기억.
- 설정창 뒤 입력 정지, 기록실 선택 강조 잔상·음악 전환 흰 번쩍임·오프닝 순서 수정.

자동 선택은 승리를 보장하지 않습니다. 난이도를 조절하려면 ‘주는 피해 배율’과 ‘받는 피해 감소’를 이용하세요. 모드는 환경 설정의 **모드** 탭에서 조절합니다.

## 구성과 제작 기록

원본 7개 파일의 HDiffPatch 차분과 새 `ko.dll`을 제공합니다. 원본 게임 실행 파일·PAK·개인 저장은 제공하지 않습니다. 차분에도 원작에서 유래한 변경 데이터가 포함되며 별도 한국어 PV는 원작 영상·음원을 이용한 편집본입니다.

공식 [HDiffPatch 5.1.3](https://github.com/sisong/HDiffPatch/releases/tag/v5.1.3)을 사용합니다. [재생성 방법](docs/BUILD.md), [외부 도구와 출처](THIRD_PARTY.md), [기여·번역 출처](docs/PROVENANCE.md)를 참고하세요. 번역·후속 한국어 문구는 **Codex internal**, r4b 검수 수정은 Claude, 하나치라스 요약 초안은 사용자가 제공한 Gemini 작성본이며 Codex가 사실관계 검수와 통합을 담당했습니다.
