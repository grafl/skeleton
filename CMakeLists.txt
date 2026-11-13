cmake_minimum_required(VERSION 3.15)

project(skeleton VERSION 0.0.1 LANGUAGES C)

set(CMAKE_C_STANDARD 17)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_C_EXTENSIONS OFF)

add_executable(skeleton)
target_sources(skeleton PRIVATE src/main.c)
target_include_directories(skeleton PRIVATE include)

set(APR_BUILD_SHARED OFF CACHE BOOL "Build APR shared libraries")
set(APR_BUILD_STATIC ON CACHE BOOL "Build APR static libraries")
set(CMAKE_POLICY_VERSION_MINIMUM 3.5)
add_subdirectory(external/apr)

target_link_libraries(skeleton PRIVATE apr-1)
