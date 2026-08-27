# Ultima IV++

Godot 4로 만든 **Ultima IV: Quest of the Avatar** 팬 리메이크입니다.  
맵·퀘스트·대화 구조는 원작에 맞추고, 화면·조작·전투·언어는 지금 플레이하기 쉽게 다시 짰습니다.

A Godot 4 fan remake of **Ultima IV: Quest of the Avatar**.  
Maps, quests, and dialogue structure follow the original; visuals, controls, combat, and localization are rebuilt for modern play.

이 프로젝트는 Electronic Arts 또는 원 권리자와 제휴하거나 승인받은 제품이 아닙니다.  
This fan project is not affiliated with or endorsed by Electronic Arts or the original rights holders.

---

## 플레이하려면

원작 **Ultima IV DOS** 데이터가 필요합니다. 이 저장소는 그 데이터를 배포하지 않습니다. GOG 등에서 합법적으로 구한 뒤, 게임 데이터 폴더를 `data/u4`로 연결하거나 실행 시 경로를 지정하세요.

Apple II Color / Mono 그래픽은 별도로 Apple II **Program** 디스크(`.dsk`, Side A)가 필요합니다. 없어도 DOS 데이터만으로 플레이할 수 있고, 나중에 옵션에서 지정할 수 있습니다.

원본 데이터는 사용자가 취득한 라이선스와 배포처 조건을 따릅니다.

## To play

You need original **Ultima IV for DOS** game data. This repository does not ship that data. Obtain it lawfully (for example from GOG), then point the game at it with a `data/u4` link or a path at runtime.

Apple II Color / Mono graphics also need an Apple II **Program** disk (`.dsk`, Side A). The game is playable without it; you can set the disk later in Options.

That data remains subject to the license and terms under which you acquired it.

---

## 언어 / Languages

| ID | 언어 | 성격 |
|----|------|------|
| `en_u4` | English (Original) | 원작 문구 |
| `en_us` | English (Modern) | 현대 미국 영어 |
| `ko` | 한국어 | 현대 한국어 |

키보드 A–Z는 원작 명령입니다. 게임패드로도 플레이할 수 있게 맞추는 중입니다.

---

## About

게임 안의 **About**과 같은 출처·면책입니다.

### Ultima IV (DOS) 게임 데이터

이 프로젝트를 플레이하려면 사용자가 합법적으로 취득한 Ultima IV DOS 버전의 원본 게임 데이터가 필요합니다. 이 프로젝트는 해당 게임 데이터를 배포하지 않습니다. 원본 데이터는 사용자가 취득한 라이선스 및 배포처의 이용 조건을 따릅니다.

Ultima, Ultima IV, Britannia, Origin Systems 및 관련 명칭과 자산의 권리는 각 권리자에게 있습니다. 이 팬 프로젝트는 Electronic Arts 또는 원 권리자와 제휴하거나 승인받은 제품이 아닙니다.

### xu4

게임 규칙, 파일 형식 및 구현을 이해하기 위해 [xu4](https://github.com/xu4-engine/u4) 소스 코드와 문서를 참고했습니다.  
효과음 파일은 xu4에서 가져와 사용합니다.

xu4는 GNU General Public License version 3 (GPL-3.0)으로 배포됩니다.

### libhangul

두벌식, 세벌식 390, 세벌식 최종 한글 조합에 [libhangul](https://github.com/libhangul/libhangul)을 사용합니다.

libhangul은 GNU Lesser General Public License version 2.1 이상 (LGPL-2.1-or-later)으로 배포됩니다.

### Godot Engine 및 godot-cpp

이 프로젝트는 MIT 라이선스의 [Godot Engine](https://godotengine.org)과 GDExtension 바인딩 [godot-cpp](https://github.com/godotengine/godot-cpp)를 사용합니다.

### u4graphics

Ultima IV 타일 그래픽(New Color)은 [jahshuwaa의 u4graphics](https://github.com/jahshuwaa/u4graphics)를 사용합니다.  
The Unlicense에 따라 퍼블릭 도메인으로 공개되었습니다.

### Apple II

선택 가능한 Apple II Color / Mono White / Mono Green 모드는 사용자가 합법적으로 구한 Apple II판 Ultima IV Program 디스크(.dsk, Side A)에서 타일을 읽습니다. Britannia(세이브) 디스크가 아닙니다. 원본 디스크는 배포하지 않습니다. 해당 타일 데이터의 권리는 Origin Systems / Electronic Arts 등 각 권리자에게 있습니다.

Apple II Color의 NTSC 합성 색상 디코딩은 AppleWin의 Color Monitor 경로(NTSC.cpp, William S. Simms / Michael Pohoreski)를 참고했으며, Mariani/AppleWin Composite Monitor hue LUT를 사용합니다.  
[AppleWin](https://github.com/AppleWin/AppleWin) — GNU General Public License version 2 (GPL-2.0) 이상.

### Raven Fantasy Icons

일부 UI 아이콘은 Clockwork Raven의 [Raven Fantasy Icons](https://clockworkraven.itch.io/raven-fantasy-icons)를 사용합니다.

해당 에셋은 제작자가 itch.io 상품 페이지에서 제시한 이용 조건에 따라 사용됩니다. 수정 및 프로젝트 내 사용은 허용되지만, 에셋 자체를 별도 상품으로 재배포하거나 판매할 수 없습니다. 표시는 필수가 아니지만 감사의 뜻으로 출처를 기재합니다.

### Freesound

일부 효과음은 [Freesound](https://freesound.org/)에서 제공하는 무료 음원을 사용합니다.  
각 음원의 라이선스와 제작자 표시는 Freesound의 해당 음원 페이지를 따릅니다.

### 배경음악

배경음악은 Commodore 64판 Ultima IV 사운드트랙(Ken Arnold 작곡)입니다.  
https://www.youtube.com/watch?v=6ibvs5z2H9U

### D2Coding

UI 글꼴은 SIL Open Font License (OFL)의 [D2Coding](https://github.com/naver/d2codingfont)을 사용합니다.

### 면책

각 외부 프로젝트 및 에셋의 저작권과 상표는 해당 제작자와 권리자에게 있습니다. 위 링크에서 최신 원문 라이선스와 이용 조건을 확인할 수 있습니다.

### AI 사용

개발, 대화 번역, 일부 이미지 생성에 AI가 사용되었습니다.

---

### Ultima IV (DOS) game data

This project requires original Ultima IV for DOS game data lawfully obtained by the user. No original game data is distributed with this project. That data remains subject to the license and terms under which the user acquired it.

Ultima, Ultima IV, Britannia, Origin Systems, and related names and assets belong to their respective owners. This fan project is not affiliated with or endorsed by Electronic Arts or the original rights holders.

### xu4

[xu4](https://github.com/xu4-engine/u4) source code and documentation were consulted to understand game rules, file formats, and implementation details.  
Sound-effect files are taken from xu4.

xu4 is distributed under the GNU General Public License version 3 (GPL-3.0).

### libhangul

[libhangul](https://github.com/libhangul/libhangul) provides Dubeolsik, Sebeolsik 390, and Sebeolsik Final composition.

libhangul is distributed under the GNU Lesser General Public License version 2.1 or later (LGPL-2.1-or-later).

### Godot Engine and godot-cpp

This project uses the MIT-licensed [Godot Engine](https://godotengine.org) and its [godot-cpp](https://github.com/godotengine/godot-cpp) GDExtension bindings.

### u4graphics

Ultima IV tile graphics (New Color) use [jahshuwaa's u4graphics](https://github.com/jahshuwaa/u4graphics), dedicated to the public domain under The Unlicense.

### Apple II

The optional Apple II Color / Mono White / Mono Green modes read tiles from a lawfully obtained Apple II Ultima IV Program disk (.dsk, Side A). That is not the Britannia (save) disk. The original disk image is not distributed. Rights in that tile data belong to Origin Systems / Electronic Arts and other respective owners.

Apple II Color NTSC composite decoding consults AppleWin's Color Monitor path (NTSC.cpp, William S. Simms / Michael Pohoreski) and uses a Mariani/AppleWin Composite Monitor hue LUT.  
[AppleWin](https://github.com/AppleWin/AppleWin) — GNU General Public License version 2 (GPL-2.0) or later.

### Raven Fantasy Icons

Some UI icons use [Raven Fantasy Icons](https://clockworkraven.itch.io/raven-fantasy-icons) by Clockwork Raven.

The assets are used under the terms presented by the creator on the itch.io product page. Modification and use within a project are permitted, but the asset may not be redistributed or sold as a separate product. Attribution is not required, but is included with thanks.

### Freesound

Some sound effects use free audio from [Freesound](https://freesound.org/).  
License and attribution for each clip follow that clip's page on Freesound.

### Background music

Background music is the Commodore 64 Ultima IV soundtrack, composed by Ken Arnold.  
https://www.youtube.com/watch?v=6ibvs5z2H9U

### D2Coding

The UI uses the [D2Coding](https://github.com/naver/d2codingfont) font under the SIL Open Font License (OFL).

### Disclaimer

Copyrights and trademarks in third-party projects and assets remain with their respective authors and owners. Follow the links above for the current original license and usage terms.

### AI usage

AI was used for development, dialogue translation, and some image generation.
