# 외부 도구와 권리 고지

## HDiffPatch

수정하지 않은 공식 `hpatchz.exe` 5.1.3 Windows x64 바이너리를 포함합니다. 차분 생성에도 같은 공식 배포 ZIP의 `hdiffz.exe`를 사용했습니다. 별도 차분 포맷이나 런타임을 새로 구현하지 않았습니다.

- 프로젝트: https://github.com/sisong/HDiffPatch
- 고정 배포판: https://github.com/sisong/HDiffPatch/releases/tag/v5.1.3
- 배포 ZIP: https://github.com/sisong/HDiffPatch/releases/download/v5.1.3/hdiffpatch_v5.1.3_bin_windows64.zip
- ZIP SHA-256: `77f141386e5d8f785c1c846e10fbbc19b6c05aa00e3f59cc44670fb3f0e2ae94`
- 포함 바이너리의 크기와 SHA-256: `manifest.json`의 `patcher`.
- HDiffPatch와 libdivsufsort의 MIT 고지: `LICENSES/HDiffPatch-LICENSE.txt`.

공식 기본 도구의 압축·체크섬 의존성 고지를 `LICENSES/`에 함께 보관합니다. 배포 바이너리는 위 ZIP 해시로 고정하며, 아래 문서의 최신 버전 번호가 이 바이너리의 각 내부 라이브러리 버전을 증명하는 것은 아닙니다.

| 구성 요소 | 고지 출처 |
|---|---|
| zstd | https://github.com/sisong/zstd/blob/master/LICENSE |
| zlib | https://github.com/sisong/zlib/blob/master/zlib.h (첫 저작권·라이선스 주석) |
| libdeflate | https://github.com/sisong/libdeflate/blob/master/COPYING |
| bzip2 | https://github.com/sisong/bzip2/blob/master/LICENSE |
| xxHash | https://github.com/sisong/xxHash/blob/master/LICENSE |
| libmd5 | https://github.com/sisong/libmd5/blob/master/md5.h (첫 저작권·라이선스 주석) |
| LZMA SDK | https://github.com/sisong/lzma/blob/master/DOC/lzma-sdk.txt |

HDiffPatch 저작자: housisong. 자세한 저작권·사용 조건은 각 고지 원문을 따릅니다.

## 기존 프로젝트에서 재사용한 설치 기반

기존 드라코이 한국어 패치의 `DraKoI.Release.psm1`을 검토해 경로 정규화, 정션/심볼릭 링크 거부, 원본 백업, 해시 검증, 임시 파일을 통한 원자적 교체 방식을 계엄성도 파일 목록에 맞춰 적용했습니다. 원래 모듈은 완성 파일 배포와 드라코이 전용 목록을 전제로 하므로 통째로 가져오지 않고, 파일 교체 기반에 HDiffPatch 적용 단계를 연결했습니다. 다른 게임의 파일이나 저장은 포함하지 않습니다.

## 게임·폰트·실행 환경

게임 원본과 그로부터 유래한 자료, 공식 공략·아이콘의 권리는 니트로플러스 등 해당 권리자에게 있습니다. 이 패치는 비공식 사용자 패치이며 게임 자체나 원본 음악·영상의 배포물이 아닙니다. 패치 데이터와 한국어 런타임에 HDiffPatch의 MIT 라이선스를 자동 적용하지 않습니다.

맑은 고딕은 Windows에서 제공하는 Microsoft 글꼴이며 이 저장소에는 포함하지 않습니다. Locale Emulator도 포함하지 않고 사용자가 별도로 준비합니다.

- 공식 공략: https://www.nitroplus.co.jp/pc/lineup/into_10/kaigen.php
- Locale Emulator: https://github.com/xupefei/Locale-Emulator