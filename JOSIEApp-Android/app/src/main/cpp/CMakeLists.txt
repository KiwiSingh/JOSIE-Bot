cmake_minimum_required(VERSION 3.22.1)

project("josie-llama")

# ------------------------------------------------
# Locate Android SDK Ninja (reliable inside AS/Gradle)
# ------------------------------------------------

if(DEFINED ENV{ANDROID_SDK_ROOT})
    set(ANDROID_SDK "$ENV{ANDROID_SDK_ROOT}")
elseif(DEFINED ENV{ANDROID_HOME})
    set(ANDROID_SDK "$ENV{ANDROID_HOME}")
else()
    set(ANDROID_SDK "$ENV{HOME}/Library/Android/sdk")
endif()
set(CMAKE_INTERPROCEDURAL_OPTIMIZATION FALSE)
set(ANDROID_NINJA "${ANDROID_SDK}/cmake/3.22.1/bin/ninja")

# Force CMake to use the SDK Ninja
set(CMAKE_MAKE_PROGRAM "${ANDROID_NINJA}" CACHE FILEPATH "" FORCE)

# ------------------------------------------------
# Explicit Release build type — ensures -O3 and -DNDEBUG
# are applied to all llama.cpp sub-targets, not just josie-llama.
# Without this, add_subdirectory(llama.cpp) inherits no build type
# and defaults to an unoptimized none/debug configuration.
# ------------------------------------------------

if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Release CACHE STRING "Build type" FORCE)
endif()

# Strip debug symbols from .so in Release — major contributor to APK size bloat.
set(CMAKE_CXX_FLAGS_RELEASE "-O3 -DNDEBUG")
set(CMAKE_C_FLAGS_RELEASE   "-O3 -DNDEBUG")
set(CMAKE_SHARED_LINKER_FLAGS_RELEASE "-Wl,--strip-all")

# ------------------------------------------------
# Path to llama.cpp
# ------------------------------------------------

set(LLAMA_DIR ${CMAKE_CURRENT_SOURCE_DIR}/llama.cpp)

# MoltenVK headers for host shader compilation
include_directories(/usr/local/include)

# ------------------------------------------------
# GPU + CPU OPTIMIZATIONS
# ------------------------------------------------

# Vulkan backend
set(GGML_VULKAN ON CACHE BOOL "" FORCE)

# Snapdragon (Adreno)
set(GGML_VULKAN_COOPMAT_GLSLC_SUPPORT ON CACHE BOOL "" FORCE)
set(GGML_VULKAN_COOPMAT2_GLSLC_SUPPORT ON CACHE BOOL "" FORCE)
set(GGML_VULKAN_INTEGER_DOT_GLSLC_SUPPORT ON CACHE BOOL "" FORCE)

# MediaTek / Mali
set(GGML_VULKAN_SUBGROUP ON CACHE BOOL "" FORCE)
set(GGML_VULKAN_PARALLEL_COMPUTE ON CACHE BOOL "" FORCE)

# Mixed precision
set(GGML_VULKAN_BFLOAT16_GLSLC_SUPPORT ON CACHE BOOL "" FORCE)

# CPU fallback optimizations
set(GGML_CPU_ARM64 ON CACHE BOOL "" FORCE)
set(GGML_CPU_ARM64_DOTPROD ON CACHE BOOL "" FORCE)
set(GGML_CPU_ARM64_FP16 ON CACHE BOOL "" FORCE)

# ------------------------------------------------
# Disable unnecessary llama components
# ------------------------------------------------

set(LLAMA_BUILD_COMMON OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_SERVER OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_TOOLS OFF CACHE BOOL "" FORCE)

# ------------------------------------------------
# Fix nested Vulkan shader generator build
# ------------------------------------------------

set(SHADER_HOST_CACHE "${CMAKE_BINARY_DIR}/shader-host-cache.cmake")

if(NOT EXISTS "${SHADER_HOST_CACHE}")
    file(WRITE "${SHADER_HOST_CACHE}"
            "set(CMAKE_GENERATOR "Unix Makefiles" CACHE INTERNAL "" FORCE)\n"
            "set(Vulkan_GLSLC_EXECUTABLE "/opt/homebrew/bin/glslc" CACHE FILEPATH "" FORCE)\n"
    )
endif()

set(GGML_VULKAN_SHADERS_GEN_CMAKE_CACHE_ARGS
        "-C${SHADER_HOST_CACHE}"
        CACHE STRING "" FORCE
)

# ------------------------------------------------
# Build llama.cpp
# ------------------------------------------------

add_subdirectory(${LLAMA_DIR} llama.cpp_build)

# ------------------------------------------------
# JNI bridge
# ------------------------------------------------

add_library(josie-llama SHARED llama-jni.cpp)

target_link_libraries(
        josie-llama
        PUBLIC
        llama
        log
        vulkan
)

target_include_directories(
        josie-llama
        PUBLIC
        ${LLAMA_DIR}
        ${LLAMA_DIR}/common
        ${LLAMA_DIR}/include
)
