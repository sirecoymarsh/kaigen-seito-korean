# 제작 및 출처

- **Codex internal**: 기본 한국어 번역, 후속 문구·이름·설명, 영상 화면 문구, 코드·UI·모드·패키지 통합과 검증.
- **Claude**: 사용자가 진행한 r4b 검수에서 확정 수정 49건과 이전 번역 제외 9행 반영, 용어 결정 적용과 코드 페이지 수정. 이 작업을 Codex 단독 번역으로 표시하지 않습니다.
- **Gemini / Antigravity, 사용자 제공 자료**: 하나치라스 요약 초안. Codex가 게임 자료에 대조해 사실관계 오류를 수정하고 대표 CG·재생 구조로 통합했습니다. 공식 추가 시나리오로 표시하지 않습니다.
- 사용자 직접 선택: 음악 7개·하나치라스 요약 2개 썸네일.
- 원작 게임·일러스트·음원·공식 자료의 권리는 해당 권리자에게 있습니다. 이 문서는 원작 권리나 외부 도구의 라이선스를 패치에 일괄 적용하지 않습니다.

## 재사용한 자료와 도구

- [한국어화의 바탕이 된 프로모션 영상](https://www.youtube.com/watch?v=LfhB7dHDYTw)
- [HDiffPatch 5.1.3](https://github.com/sisong/HDiffPatch/releases/tag/v5.1.3): 원본 해시에 묶인 배포 차분 생성·검사·복원.
- [GARbro NitroPlus 어댑터](https://github.com/morkt/GARbro/blob/master/ArcFormats/NitroPlus/ArcNitro.cs): PAK 이름·추가 항목 키 처리 대조. 기존 프로젝트 어댑터 재사용.
- [FFmpeg 문서](https://ffmpeg.org/ffmpeg.html), [MPEG muxer](https://github.com/FFmpeg/FFmpeg/blob/master/libavformat/mpegenc.c): 기존 게임용 MPEG 인코딩·muxrate 확인. 이번 배포에서는 완료된 인코딩을 그대로 사용합니다.
- [GitHub 대용량 파일 안내](https://docs.github.com/en/repositories/working-with-files/managing-large-files/about-large-files-on-github): 다운로드 ZIP·영상은 Release 자산으로 제공합니다.
- [Win32 창 배치](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-deferwindowpos)와 [DirectShow 실행](https://learn.microsoft.com/en-us/windows/win32/api/control/nf-control-imediacontrol-run): 최근 기록실 갱신과 영상 준비 상태 수정의 API 근거. 기존 엔진·런타임을 유지했습니다.
