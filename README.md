# 계엄성도 한국어 패치

**v2026.11.25-r4b**

니트로플러스 『사바토 나베』 수록 『계엄성도』의 Windows판 한국어 패치와 편의 기능입니다. r4b 는 검수에서 나온 오역·용어 불일치 수정, 남아 있던 9행 번역, 한국어 Windows 에서 바로 실행되는 수정을 담았습니다. 전체 분기와 시나리오를 재완주한 검증은 완료되지 않았습니다. [번역·검증 범위](docs/STATUS.md)를 먼저 확인하세요.

## 다운로드와 설치

[Releases](https://github.com/sirecoymarsh/kaigen-seito-korean/releases)에서 `KaigenSeito-Korean-v2026.11.25-r4b.zip`을 받아 압축을 풉니다. 저장소의 소스 ZIP에도 같은 설치 도구와 패치가 들어 있습니다.

1. 원본 게임을 준비하고 게임을 종료합니다. `KaigenSeito.exe`와 PAK 파일들이 같은 폴더에 있어야 합니다.
2. 패치의 `Install.cmd`를 실행하고 **게임 폴더**를 선택합니다.
3. `INSTALL PASS`가 표시되면 설치가 끝납니다. 필요하면 `Verify.cmd`로 파일을 다시 확인합니다.
4. `KaigenSeito.exe`를 그대로 실행합니다. 한국어 Windows 에서도 Locale Emulator 나 일본어 로캘 설정 없이 실행되며, 게임 폴더·사용자 폴더 경로에 한글이 있어도 됩니다.

이전 판(r4a)이 설치된 폴더에는 그대로 `Install.cmd`를 실행하면 r4b 로 올라갑니다. 원본 백업은 그대로 다시 씁니다.

설치 도구는 Windows 10/11 **x64**, PowerShell 5.1 이상을 대상으로 합니다. 게임 글꼴로 **맑은 고딕(Malgun Gothic)**이 필요합니다. Microsoft 글꼴은 배포하지 않습니다. 설치 과정에는 인터넷 연결이 필요하지 않습니다.

원본 버전은 파일 크기와 SHA-256으로 확인합니다. [지원 원본 해시](docs/original-files.json)와 다른 파일, 다른 한패가 이미 적용된 파일, 링크·정션을 거친 게임 폴더에는 설치하지 않습니다. 다른 판본을 강제로 덮어쓰지 말고 지원 원본으로 돌아간 뒤 적용하세요. 설치 도중 원본 백업(약 150 MB)과 임시 완성 파일을 위해 약 450 MB의 여유 공간이 필요합니다.

## 저장과 원본 복원

`SAVE`, 개인 `.ini` 설정은 패키지에 포함하지 않으며 설치·복원 대상에도 넣지 않습니다. 기존 저장이 참조하는 대본 명령 위치를 보존한 통합본입니다. 모든 저장 시점과 분기의 호환성을 보증하는 것은 아닙니다.

원본 파일 6개는 게임 폴더의 `.kaigen-ko-backup`에 보관합니다(r4a 의 `.kaigen-ko-backup-r4a` 는 설치할 때 이 이름으로 옮깁니다). **이 백업 폴더를 삭제하지 마세요.** 게임을 종료하고 `Restore.cmd`에서 같은 게임 폴더를 선택하면 원본 파일을 복원하고 패치가 추가한 `ko.dll`을 제거합니다. 저장과 설정은 유지하며 백업은 복원 뒤에도 남습니다.

설치 준비 단계에서 모든 차분을 적용하고 목표 해시를 확인한 뒤 게임 파일을 교체합니다. 교체 중 일반 오류가 발생하면 백업으로 되돌립니다. 정전이나 프로세스 강제 종료 후에는 백업을 보존하세요. 설치 프로그램이 실행 중이 아님을 확인한 뒤 남아 있는 `.kaigen-ko-install.lock`만 제거하고 `Restore.cmd`를 실행할 수 있습니다. 다른 도구로 추가 변경한 파일은 자동 복원 대상에서 거부합니다.

폴더 선택 창 대신 명령줄에서도 사용할 수 있습니다.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Patch.ps1 -Action Install -GameDir 'D:\Games\KaigenSeito'
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Patch.ps1 -Action Verify  -GameDir 'D:\Games\KaigenSeito'
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Patch.ps1 -Action Restore -GameDir 'D:\Games\KaigenSeito'
```

## 포함 기능

- 시나리오·선택지·환경 설정·이미지 UI 한국어화. 한국어 줄바꿈 정리와 단순 독음 루비 숨김.
- 저장·불러오기·확인 창을 닫은 뒤 본창 입력이 멎는 엔진 문제 수정.
- 방향키 즉시·연속 이동, 미니맵 목적지 클릭 이동, 장비를 한 메뉴에서 변경.
- 환경 설정의 모드 탭: 수동·어시스트·자동 선택, 경험치·피해 배율, 조우 배율, 지도 표시 설정.
- 피해·성공 확률을 반영한 기대 피해 추천. 자동 선택은 확인된 필승 수를 우선하며, 승리를 보장하지 않습니다.
- 미완료 이벤트 녹색·완료 이벤트 붉은색, 획득한 아이템 숨김, 방문한 출구·잠금 상태·다음 목표 표시.
- 일반 선택지와 전투 선택지의 흰색 글자 선명화. 원래 버튼 배경과 마우스 강조는 유지합니다.

상세 동작과 제한은 [조작 안내](docs/CONTROLS.md)를 확인하세요.

## 패키지 구성

`patches/`에는 원본 6개 파일의 차분만, `files/`에는 새 한국어 런타임 `ko.dll`을 넣었습니다. 원본 게임 실행 파일·PAK·음악·영상·저장 파일을 제공하지 않습니다. `manifest.json`은 원본·결과·패치·적용 도구의 해시를 기록합니다.

차분 생성·적용은 공식 [HDiffPatch 5.1.3](https://github.com/sisong/HDiffPatch/releases/tag/v5.1.3)을 사용합니다. 도구 출처와 라이선스는 [THIRD_PARTY.md](THIRD_PARTY.md), 재생성 방법은 [BUILD.md](docs/BUILD.md)에 있습니다. 원본 게임과 원본에서 유래한 자료의 권리는 각 권리자에게 있습니다. 이 저장소는 게임 자체를 배포하거나 해당 권리를 양도하지 않습니다.

번역·한국어 문구 작성: **Codex internal**. r4b 의 검수 수정과 9행 번역은 Claude 가 사용자의 결정(帝=황제, 錦旗=비단 깃발, 禁裏=황궁)에 따라 반영했습니다. 외부 번역 서비스는 쓰지 않았습니다.