cmake_minimum_required(VERSION 3.22)
project(MyMod)

# Collect source files
file(GLOB_RECURSE SRC_FILES "*.cpp" "*.c" "*.cc")
file(GLOB_RECURSE HDR_FILES "*.hpp" "*.h")

# Create shared library
add_library(MyMod SHARED ${SRC_FILES} ${HDR_FILES})

# Link against UE4SS
target_link_libraries(MyMod PRIVATE UE4SS)

# Include directories
target_include_directories(MyMod PRIVATE 
    ${UE4SS_SOURCE_DIR}/UE4SS/include
    ${UE4SS_SOURCE_DIR}/deps/first/Unreal/include
)

# Set C++ standard
target_compile_features(MyMod PRIVATE cxx_std_20)
