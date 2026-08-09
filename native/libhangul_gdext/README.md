# Ultima IV++ libhangul GDExtension

This extension statically links [libhangul](https://github.com/libhangul/libhangul)
and exposes `HangulComposer` to Godot. Dependencies are pinned and fetched by
CMake. Generated dependency sources stay under `build-*` and are not committed.

## Build

macOS universal debug:

```sh
cmake -S native/libhangul_gdext -B native/libhangul_gdext/build-debug \
  -G Ninja -DCMAKE_BUILD_TYPE=Debug
cmake --build native/libhangul_gdext/build-debug --target ultima4r_hangul_input
```

macOS universal release:

```sh
cmake -S native/libhangul_gdext -B native/libhangul_gdext/build-release \
  -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build native/libhangul_gdext/build-release --target ultima4r_hangul_input
```

Run the same commands on Windows or Linux to produce the platform-specific
binary referenced by `ultima4r_hangul_input.gdextension`.

## Licenses

- libhangul: LGPL-2.1-or-later
- godot-cpp: MIT
- This wrapper follows the project's license.

Relinking information and the pinned source revisions are available in
`CMakeLists.txt`.
