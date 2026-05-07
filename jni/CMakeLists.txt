cmake_minimum_required(VERSION 3.10)
project(voicefx)

set(ST_DIR ${CMAKE_SOURCE_DIR}/soundtouch)

file(GLOB ST_SOURCES ${ST_DIR}/*.cpp)

add_library(soundtouch STATIC ${ST_SOURCES})
target_include_directories(soundtouch PUBLIC ${ST_DIR})
target_compile_options(soundtouch PRIVATE -O2 -fPIC)

add_library(voicefx SHARED voicefx.cpp)
target_include_directories(voicefx PRIVATE ${ST_DIR})
target_compile_options(voicefx PRIVATE -O2 -fPIC)
target_link_libraries(voicefx soundtouch log android)

set_target_properties(voicefx PROPERTIES OUTPUT_NAME "voicefx")
