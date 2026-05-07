cmake_minimum_required(VERSION 3.10)
project(voicefx)

set(RB_DIR ${CMAKE_SOURCE_DIR}/rubberband-src)

add_library(rubberband STATIC ${RB_DIR}/single/RubberBandSingle.cpp)
target_include_directories(rubberband PUBLIC ${RB_DIR})
target_compile_options(rubberband PRIVATE -O2 -fPIC -DUSE_BQRESAMPLER=1)

add_library(voicefx SHARED voicefx.cpp)
target_include_directories(voicefx PRIVATE ${RB_DIR} ${RB_DIR}/rubberband)
target_compile_options(voicefx PRIVATE -O2 -fPIC)
target_link_libraries(voicefx rubberband log android)

set_target_properties(voicefx PROPERTIES OUTPUT_NAME "voicefx")
