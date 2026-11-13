cmake_minimum_required(VERSION 3.15)

project(skeleton VERSION 0.0.1 LANGUAGES C)

set(CMAKE_C_STANDARD 17)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_C_EXTENSIONS OFF)

add_executable(skeleton)
target_sources(skeleton PRIVATE src/main.c)
target_include_directories(skeleton PRIVATE include)
