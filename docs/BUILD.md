# 배포 패치 재생성

이 저장소는 배포용 차분, 설치기, 검사 도구와 현재 검증된 스냅샷의 해시를 보관합니다. 시나리오 번역 작업공간이나 게임 전체의 소스 빌드 저장소는 아닙니다.

필요한 입력:

- `docs/original-files.json`과 일치하는 직접 보유한 원본 게임.
- `docs/target-files.json`과 일치하는 검증된 한국어 통합본.
- 공식 HDiffPatch 5.1.3 Windows x64의 `hdiffz.exe`, `hpatchz.exe`. 다운로드 ZIP 해시는 `THIRD_PARTY.md`를 확인합니다.
- Python 3.11 이상, Windows x64.

```powershell
python .\scripts\build_release.py --original 'P:\inputs\original' --target 'P:\inputs\verified-korean' --hdiffz 'P:\tools\hdiffz.exe' --hpatchz 'P:\tools\hpatchz.exe' --original-catalog .\docs\original-files.json --target-catalog .\docs\target-files.json --output 'P:\build\new-payload'
```

출력은 새 폴더를 지정합니다. 이미 존재하는 차분 파일은 덮어쓰지 않습니다. 생성기는 원본과 목표의 해시를 먼저 검사하고, 각 차분 생성 뒤 HDiffPatch의 적용 비교도 실행합니다. 설치기와 문서는 현재 저장소에서 함께 복사해 배포합니다. 생성된 `manifest.json`과 페이로드를 서로 다른 버전과 섞지 마세요.

새 설치 검사가 필요할 때:

```powershell
python .\scripts\test_release.py --original 'P:\inputs\original' --package 'P:\build\package' --work 'P:\build\new-validation-work' --report 'P:\build\validation.json'
```

`--work`는 존재하지 않는 전용 임시 폴더여야 합니다. 이 검사는 게임을 실행하지 않고 원본 8개 파일의 시험 사본과 가짜 저장·설정 표본으로 설치, 결과 해시, 재설치, 복원, 손상 거부를 확인합니다. 사용자 저장을 가져오지 않습니다. 검사 뒤 이 전용 폴더는 결과를 확인하고 삭제할 수 있습니다.

최초 게시 시 검사 결과: [release-validation.json](release-validation.json). 기존 네이티브 게임 검증과 이번 배포 검증의 구분: [STATUS.md](STATUS.md).