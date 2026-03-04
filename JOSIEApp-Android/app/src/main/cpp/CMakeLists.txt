cmake_minimum_required(VERSION 3.22.1)
project("josie-llama")

# Set the path to llama.cpp
set(LLAMA_DIR ${CMAKE_CURRENT_SOURCE_DIR}/llama.cpp)

# Disable Vulkan for stability on Android Emulator
set(GGML_VULKAN OFF)
set(LLAMA_VULKAN OFF)

# Disable unnecessary things
set(LLAMA_BUILD_COMMON OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_SERVER OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_TOOLS OFF CACHE BOOL "" FORCE)

# Include llama.cpp
# Limit parallel jobs to prevent OOM/Freezes during monster C++ compilations
set_property(GLOBAL PROPERTY JOB_POOLS compile=1 link=1)
set(CMAKE_JOB_POOL_COMPILE compile)
set(CMAKE_JOB_POOL_LINK link)

add_subdirectory(${LLAMA_DIR} llama.cpp_build)

# Create the JNI library
add_library(josie-llama SHARED llama-jni.cpp)

# Link llama and Android libraries
target_link_libraries(josie-llama PUBLIC llama log)
target_include_directories(josie-llama PUBLIC 
    ${LLAMA_DIR} 
    ${LLAMA_DIR}/common 
    ${LLAMA_DIR}/include
)
