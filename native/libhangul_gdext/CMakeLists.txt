cmake_minimum_required(VERSION 3.24)
project(ultima4r_hangul_input LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

if(APPLE AND NOT CMAKE_OSX_ARCHITECTURES)
	set(CMAKE_OSX_ARCHITECTURES "arm64;x86_64" CACHE STRING "" FORCE)
endif()

include(FetchContent)

# Pinned revisions keep desktop builds reproducible.
FetchContent_Declare(
	godot_cpp
	GIT_REPOSITORY https://github.com/godotengine/godot-cpp.git
	GIT_TAG 7e18e40d7591429f915035a7de7cf79457d555cc
	GIT_SHALLOW FALSE
)
FetchContent_Declare(
	libhangul
	GIT_REPOSITORY https://github.com/libhangul/libhangul.git
	GIT_TAG libhangul-0.2.0
	GIT_SHALLOW TRUE
)

set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
set(BUILD_TESTING OFF CACHE BOOL "" FORCE)
set(ENABLE_UNIT_TEST OFF CACHE BOOL "" FORCE)
set(ENABLE_TOOLS OFF CACHE BOOL "" FORCE)
set(ENABLE_EXTERNAL_KEYBOARDS OFF CACHE BOOL "" FORCE)

# Godot loads *.debug.* with template_debug and *.release.* with template_release.
# godot-cpp otherwise keeps its template_debug default even for Release builds.
if(CMAKE_BUILD_TYPE STREQUAL "Debug")
	set(HANGUL_GODOT_TARGET "template_debug")
else()
	set(HANGUL_GODOT_TARGET "template_release")
endif()
set(GODOTCPP_TARGET "${HANGUL_GODOT_TARGET}" CACHE STRING
	"Godot target paired with this extension binary" FORCE)
set(GODOTCPP_API_VERSION "4.7" CACHE STRING
	"Godot API version paired with compatibility_minimum" FORCE)

FetchContent_MakeAvailable(godot_cpp libhangul)

# libhangul 0.2.0 assumes a top-level build and otherwise points at the parent
# binary directory for its generated config.h. Supply its real FetchContent
# binary directory when embedded in this extension.
target_include_directories(hangul PRIVATE "${libhangul_BINARY_DIR}")

add_library(ultima4r_hangul_input SHARED
	src/hangul_composer.cpp
	src/register_types.cpp
)
target_include_directories(ultima4r_hangul_input PRIVATE
	src
	"${libhangul_SOURCE_DIR}/hangul"
)
target_link_libraries(ultima4r_hangul_input PRIVATE godot-cpp hangul)

if(CMAKE_BUILD_TYPE STREQUAL "Debug")
	set(HANGUL_VARIANT "debug")
else()
	set(HANGUL_VARIANT "release")
endif()

if(APPLE)
	set(HANGUL_PLATFORM "macos")
	set(HANGUL_ARCH "universal")
elseif(WIN32)
	set(HANGUL_PLATFORM "windows")
	set(HANGUL_ARCH "x86_64")
else()
	set(HANGUL_PLATFORM "linux")
	set(HANGUL_ARCH "x86_64")
endif()

set(HANGUL_OUTPUT_DIR "${CMAKE_CURRENT_SOURCE_DIR}/bin/${HANGUL_PLATFORM}")
set_target_properties(ultima4r_hangul_input PROPERTIES
	OUTPUT_NAME "ultima4r_hangul_input.${HANGUL_PLATFORM}.${HANGUL_VARIANT}.${HANGUL_ARCH}"
	PREFIX "lib"
	RUNTIME_OUTPUT_DIRECTORY "${HANGUL_OUTPUT_DIR}"
	LIBRARY_OUTPUT_DIRECTORY "${HANGUL_OUTPUT_DIR}"
	ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/lib"
)

if(WIN32)
	set_target_properties(ultima4r_hangul_input PROPERTIES PREFIX "")
endif()
