# 배포 패치 재생성

이 저장소는 **검증된 통합본에서 배포 차분을 만드는 도구·설치기·검사기·결과 해시**를 보관합니다. 게임 전체 소스나 시나리오 작업공간을 포함하지 않습니다.

필요한 입력은 직접 보유한 [지원 원본](original-files.json), [검증된 통합본](target-files.json), HDiffPatch 5.1.3 Windows x64, Python 3.11 이상입니다. 공식 도구 출처·라이선스는 [THIRD_PARTY.md](../THIRD_PARTY.md)에 있습니다.

```powershell
python .\scripts\build_release.py --original 'P:\inputs\original' --target 'P:\inputs\verified-korean' --hdiffz 'P:\tools\hdiffz.exe' --hpatchz 'P:\tools\hpatchz.exe' --original-catalog .\docs\original-files.json --target-catalog .\docs\target-files.json --output 'P:\build\new-payload' --version v2026.11.26-r5 --previous .\docs\previous-releases.json
```

새 출력 폴더를 지정합니다. 이미 존재하는 차분은 덮어쓰지 않습니다. 원본·목표 해시를 먼저 검사하고 7개 차분을 생성한 뒤 도구 자체의 적용 비교를 수행합니다. sound.pak는 변경하지 않습니다. ko.dll은 추가 파일입니다. 설치기와 문서는 같은 릴리스의 것을 복사하고 서로 다른 manifest·페이로드를 섞지 않습니다.

`previous-releases.json`은 r4a·r4b 결과의 허용 해시입니다. 예전 버전은 mpeg.pak를 바꾸지 않았으므로 그 원본 해시도 포함합니다. 설치기는 기존 백업 6개 전체와 게임 쪽 mpeg.pak 원본을 확인한 뒤에만 누락된 MPEG 백업을 추가합니다.

```powershell
python .\scripts\test_release.py --original 'P:\inputs\original' --package 'P:\build\package' --work 'P:\build\new-validation-work' --report 'P:\build\validation.json'
python .\scripts\test_release.py --original 'P:\inputs\original' --package 'P:\build\package' --previous-package 'P:\build\previous-package' --work 'P:\build\new-upgrade-work' --report 'P:\build\upgrade.json'
```

검사 폴더는 존재하지 않는 P: 전용 폴더로 지정합니다. 원본 시험 사본과 가짜 저장·설정으로 검사하며 사용자 저장이나 게임 실행은 이용하지 않습니다. 배포 차분 적용 결과가 네이티브 검증 통합본과 같은지는 해시로 연결합니다. 새 패키징을 새 전체 플레이 검증으로 표시하지 않습니다.

릴리스 ZIP에는 저장소의 배포 파일만 넣고 `.git`, 원본 PAK·EXE, 개인 SAVE·INI, 개발 로그·임시 실행 사본은 제외합니다. 별도 PV는 기존 완성 MP4를 해시로 검증해 복사하며, 게임용 MPEG는 기존 검증 규격 그대로 재사용합니다.
