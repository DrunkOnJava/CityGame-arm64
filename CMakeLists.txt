cmake_minimum_required(VERSION 3.16)
project(CityGame-arm64 LANGUAGES C CXX OBJC)

# Set C and C++ standards
set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)

# Set build type
if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Release)
endif()

# Compiler flags
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -O2 -std=c11 -Wall -Wextra")
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -O2 -std=c++17 -Wall -Wextra")

# Include directories
include_directories(src)
include_directories(src/ai)
include_directories(src/simulation)
include_directories(src/graphics)
include_directories(src/platform)
include_directories(src/memory)

# Find required frameworks on macOS
find_library(COCOA_FRAMEWORK Cocoa)
find_library(METAL_FRAMEWORK Metal)
find_library(METALKIT_FRAMEWORK MetalKit)
find_library(COREGRAPHICS_FRAMEWORK CoreGraphics)

# Source files
set(CORE_SOURCES
    src/ai/ai_integration.c
    src/ai/steering_behaviors.c
    src/simulation/entity_system.c
    src/core/memory_manager.c
)

# Main executables
add_executable(citygame_minimal
    src/main_minimal.c
    ${CORE_SOURCES}
)

add_executable(citygame_enhanced 
    src/main_enhanced.c
    ${CORE_SOURCES}
)

add_executable(citygame_visual
    src/main_visual.c
    ${CORE_SOURCES}
)

# Link frameworks
target_link_libraries(citygame_minimal ${COCOA_FRAMEWORK} ${METAL_FRAMEWORK} ${METALKIT_FRAMEWORK} ${COREGRAPHICS_FRAMEWORK})
target_link_libraries(citygame_enhanced ${COCOA_FRAMEWORK} ${METAL_FRAMEWORK} ${METALKIT_FRAMEWORK} ${COREGRAPHICS_FRAMEWORK})
target_link_libraries(citygame_visual ${COCOA_FRAMEWORK} ${METAL_FRAMEWORK} ${METALKIT_FRAMEWORK} ${COREGRAPHICS_FRAMEWORK})

# Demo targets
add_subdirectory(demos EXCLUDE_FROM_ALL)