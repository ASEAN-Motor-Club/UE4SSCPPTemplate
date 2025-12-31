cmake_minimum_required(VERSION 3.22)

project(MyCPPMods)

# requirements
if(NOT UE4SS_SOURCE_DIR)
    set(UE4SS_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/RE-UE4SS")
endif()
add_subdirectory("${UE4SS_SOURCE_DIR}" RE-UE4SS)

add_subdirectory(MyCPPMods)
