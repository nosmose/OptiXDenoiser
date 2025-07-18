# CMakeLists.txt for OptiXDenoiser Nuke Plugin
# Nuke 14.1 / OptiX / CUDA

cmake_minimum_required(VERSION 3.12)
project(OptiXDenoiser LANGUAGES CXX)

# Set the C++ Standard for the project (C++14 for Nuke 14.1 compatibility)
set(CMAKE_CXX_STANDARD 14)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Ensure compatibility with Nuke/DDImage ABI
add_definitions(-D_GLIBCXX_USE_CXX11_ABI=0)

# Nuke 14.1 paths - adjust these to your installation
set(NUKE_INSTALL_PATH "/softwareLocal/nuke/linux/Nuke14.1v3" CACHE PATH "Path to Nuke installation")
set(NUKE_NDK_PATH "${NUKE_INSTALL_PATH}/include" CACHE PATH "Path to Nuke NDK headers")

# CUDA path from rez-env
execute_process(
    COMMAND bash -c "rez-env cuda --command \"which nvcc\" | xargs dirname | xargs dirname"
    OUTPUT_VARIABLE CUDA_ROOT_DIR
    OUTPUT_STRIP_TRAILING_WHITESPACE
)

if(NOT CUDA_ROOT_DIR)
    set(CUDA_ROOT_DIR "/usr/local/cuda" CACHE PATH "Path to CUDA installation")
endif()

message(STATUS "Using CUDA from: ${CUDA_ROOT_DIR}")

# OptiX path - try to find it or make it optional
set(OPTIX_ROOT_DIR "" CACHE PATH "Path to OptiX SDK")

# Try to find OptiX in common locations if not specified
if(NOT OPTIX_ROOT_DIR)
    # First try the known path provided by user
    set(OPTIX_ROOT_DIR "/software/nvidia/optiX/NVIDIA-OptiX-SDK-9.0.0-linux64-x86_64")
    
    if(NOT EXISTS "${OPTIX_ROOT_DIR}/include/optix.h")
        # If the known path doesn't work, try other common locations
        set(OPTIX_ROOT_DIR "")
        foreach(optix_path 
                "/software/nvidia/optiX/NVIDIA-OptiX-SDK-9.0.0-linux64-x86_64"
                "/opt/NVIDIA-OptiX-SDK-9.0.0-linux64-x86_64"
                "/opt/NVIDIA-OptiX-SDK-8.0.0-linux64-x86_64"
                "/opt/NVIDIA-OptiX-SDK-7.0.0-linux64-x86_64"
                "/rdo/software/rez/packages/optix/7.3.0"
                "/rdo/software/rez/packages/optix/7.0.0")
            if(EXISTS "${optix_path}/include/optix.h")
                set(OPTIX_ROOT_DIR "${optix_path}")
                message(STATUS "Found OptiX at: ${OPTIX_ROOT_DIR}")
                break()
            endif()
        endforeach()
    else()
        message(STATUS "Using provided OptiX SDK path: ${OPTIX_ROOT_DIR}")
    endif()
endif()

# Check if Nuke paths exist
if(NOT EXISTS ${NUKE_INSTALL_PATH})
    message(FATAL_ERROR "Nuke installation not found at: ${NUKE_INSTALL_PATH}")
endif()

if(NOT EXISTS ${NUKE_NDK_PATH})
    message(FATAL_ERROR "Nuke NDK headers not found at: ${NUKE_NDK_PATH}")
endif()

# Check if OptiX is available
set(OPTIX_AVAILABLE FALSE)
if(OPTIX_ROOT_DIR)
    set(OPTIX_INCLUDE_DIR "${OPTIX_ROOT_DIR}/include")
    set(OPTIX_SDK_DIR "${OPTIX_ROOT_DIR}/SDK")
    
    if(EXISTS "${OPTIX_INCLUDE_DIR}/optix.h")
        set(OPTIX_AVAILABLE TRUE)
        message(STATUS "OptiX SDK found at: ${OPTIX_ROOT_DIR}")
    else()
        message(WARNING "OptiX include file not found at: ${OPTIX_INCLUDE_DIR}/optix.h")
    endif()
else()
    message(WARNING "OptiX SDK not found. Building without OptiX support.")
endif()

# Check CUDA paths
set(CUDA_INCLUDE_DIR "${CUDA_ROOT_DIR}/include")
set(CUDA_LIBRARY_DIR "${CUDA_ROOT_DIR}/lib64")
set(CUDA_CUDART_LIBRARY "${CUDA_LIBRARY_DIR}/libcudart.so")

if(NOT EXISTS ${CUDA_INCLUDE_DIR}/cuda.h)
    message(FATAL_ERROR "CUDA include directory not found at: ${CUDA_INCLUDE_DIR}")
endif()

if(NOT EXISTS ${CUDA_CUDART_LIBRARY})
    message(FATAL_ERROR "CUDA runtime library not found at: ${CUDA_CUDART_LIBRARY}")
endif()

# Find CUDA package
find_package(CUDA QUIET)
if(CUDA_FOUND)
    message(STATUS "CUDA found via find_package")
    set(CUDA_AVAILABLE TRUE)
else()
    # Manual CUDA detection
    find_program(NVCC_EXECUTABLE nvcc 
        PATHS 
        ${CUDA_ROOT_DIR}/bin
        /usr/local/cuda/bin
        /opt/cuda/bin
        /usr/bin
        ENV PATH
    )
    
    if(NVCC_EXECUTABLE)
        set(CUDA_AVAILABLE TRUE)
        message(STATUS "CUDA found manually at: ${CUDA_ROOT_DIR}")
    else()
        message(FATAL_ERROR "CUDA nvcc compiler not found!")
    endif()
endif()

# Compiler flags
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fPIC -Wall -Wextra -Wno-unused-parameter")
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -O2 -g")

# Platform specific flags for Linux
if(UNIX AND NOT APPLE)
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -DLINUX")
    set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} -Wl,--as-needed")
endif()

# Include directories
include_directories(
    ${NUKE_NDK_PATH}
    ${CUDA_INCLUDE_DIR}
)

# Add OptiX includes if available
if(OPTIX_AVAILABLE)
    include_directories(
        ${OPTIX_INCLUDE_DIR}
        ${OPTIX_SDK_DIR}
    )
    add_definitions(-DUSE_OPTIX)
endif()

# Find required libraries
# DDImage library can have different names depending on Nuke version
find_library(DDIMAGE_LIB 
    NAMES DDImage libDDImage.so libDDImage DDImage.so
    PATHS 
        ${NUKE_INSTALL_PATH}/lib
        ${NUKE_INSTALL_PATH}/lib64
        ${NUKE_INSTALL_PATH}
    NO_DEFAULT_PATH
)

# If not found, try without NO_DEFAULT_PATH
if(NOT DDIMAGE_LIB)
    find_library(DDIMAGE_LIB 
        NAMES DDImage libDDImage.so libDDImage DDImage.so
        PATHS 
            ${NUKE_INSTALL_PATH}/lib
            ${NUKE_INSTALL_PATH}/lib64
            ${NUKE_INSTALL_PATH}
    )
endif()

# Manual search if still not found
if(NOT DDIMAGE_LIB)
    file(GLOB DDIMAGE_CANDIDATES 
        "${NUKE_INSTALL_PATH}/lib/libDDImage*"
        "${NUKE_INSTALL_PATH}/lib64/libDDImage*"
        "${NUKE_INSTALL_PATH}/libDDImage*"
    )
    if(DDIMAGE_CANDIDATES)
        list(GET DDIMAGE_CANDIDATES 0 DDIMAGE_LIB)
        message(STATUS "Found DDImage library manually: ${DDIMAGE_LIB}")
    endif()
endif()

if(NOT DDIMAGE_LIB)
    message(FATAL_ERROR "DDImage library not found. Please check your Nuke installation at: ${NUKE_INSTALL_PATH}")
endif()

# Set the path to the OptiXDenoiser source files
set(OPTIX_DENOISER_SOURCES
    "${CMAKE_SOURCE_DIR}/src/OptiXDenoiser.cpp"
    "${CMAKE_SOURCE_DIR}/src/OptiXDenoiser.h"
)

# Define a preprocessor macro to indicate if OptiX is available
if(OPTIX_AVAILABLE)
    add_definitions(-DOPTIX_AVAILABLE=1)
else()
    add_definitions(-DOPTIX_AVAILABLE=0)
endif()

# Verify source files exist
foreach(SRC_FILE ${OPTIX_DENOISER_SOURCES})
    if(EXISTS ${SRC_FILE})
        message(STATUS "Found source file: ${SRC_FILE}")
    else()
        message(FATAL_ERROR "Source file not found: ${SRC_FILE}")
    endif()
endforeach()

# Create the OptiXDenoiser plugin
add_library(OptiXDenoiser SHARED ${OPTIX_DENOISER_SOURCES})

# Set target properties
set_target_properties(OptiXDenoiser PROPERTIES
    PREFIX ""  # Remove 'lib' prefix
    SUFFIX ".so"
    OUTPUT_NAME "OptiXDenoiser"
    INSTALL_RPATH "${CUDA_LIBRARY_DIR}"
    BUILD_WITH_INSTALL_RPATH TRUE
    INSTALL_RPATH_USE_LINK_PATH TRUE
)

# Link libraries
target_link_libraries(OptiXDenoiser
    ${DDIMAGE_LIB}
    ${CUDA_CUDART_LIBRARY}
    ${CMAKE_DL_LIBS}
)

# Installation
install(
    TARGETS OptiXDenoiser
    LIBRARY DESTINATION plugins
    RUNTIME DESTINATION plugins
)

# Print configuration info
message(STATUS "=== Build Configuration ===")
message(STATUS "Nuke Installation: ${NUKE_INSTALL_PATH}")
message(STATUS "Nuke NDK Path: ${NUKE_NDK_PATH}")
message(STATUS "DDImage Library: ${DDIMAGE_LIB}")
message(STATUS "CUDA Root: ${CUDA_ROOT_DIR}")
message(STATUS "CUDA Include: ${CUDA_INCLUDE_DIR}")
message(STATUS "CUDA Runtime: ${CUDA_CUDART_LIBRARY}")
message(STATUS "OptiX Root: ${OPTIX_ROOT_DIR}")
message(STATUS "OptiX Include: ${OPTIX_INCLUDE_DIR}")
message(STATUS "OptiX SDK: ${OPTIX_SDK_DIR}")
message(STATUS "Build type: ${CMAKE_BUILD_TYPE}")

# Debug: Show what's in the Nuke lib directory
file(GLOB NUKE_LIBS "${NUKE_INSTALL_PATH}/lib/*DDImage*")
if(NUKE_LIBS)
    message(STATUS "Found DDImage files in Nuke lib:")
    foreach(lib ${NUKE_LIBS})
        message(STATUS "  ${lib}")
    endforeach()
else()
    message(STATUS "No DDImage files found in ${NUKE_INSTALL_PATH}/lib/")
    # Check if lib directory exists
    if(EXISTS "${NUKE_INSTALL_PATH}/lib")
        message(STATUS "Nuke lib directory contents:")
        file(GLOB ALL_LIBS "${NUKE_INSTALL_PATH}/lib/*")
        foreach(lib ${ALL_LIBS})
            get_filename_component(lib_name ${lib} NAME)
            message(STATUS "  ${lib_name}")
        endforeach()
    else()
        message(STATUS "Nuke lib directory does not exist: ${NUKE_INSTALL_PATH}/lib")
    endif()
endif()
