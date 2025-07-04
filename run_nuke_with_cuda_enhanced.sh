#!/bin/bash

# Enhanced script to run Nuke with CUDA environment for OptiXDenoiser
# With improved OptiX runtime library detection

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo "OptiXDenoiser Nuke Launcher with Enhanced Runtime Library Detection"
echo "=================================================================="

# Find CUDA path using rez-env
CUDA_PATH=$(rez-env cuda --command "echo \$REZ_CUDA_ROOT" 2>/dev/null || echo "")

# Function to add OptiX runtime paths
add_optix_runtime_paths() {
    echo "Searching for OptiX runtime libraries..."
    
    # Add the known NVIDIA driver location with OptiX runtime
    NVIDIA_DRIVER_PATH="/software/nvidia/current/linux/NVIDIA-Linux-x86_64-470.63.01"
    if [ -f "$NVIDIA_DRIVER_PATH/libnvoptix.so.470.63.01" ]; then
        echo -e "${GREEN}Found OptiX runtime library at: $NVIDIA_DRIVER_PATH${NC}"
        export LD_LIBRARY_PATH="$NVIDIA_DRIVER_PATH:$LD_LIBRARY_PATH"
    fi
    
    # Add OptiX SDK path
    OPTIX_SDK_PATH="/software/nvidia/optiX/NVIDIA-OptiX-SDK-9.0.0-linux64-x86_64"
    if [ -d "$OPTIX_SDK_PATH" ]; then
        echo -e "${GREEN}Adding OptiX SDK path to LD_LIBRARY_PATH: $OPTIX_SDK_PATH${NC}"
        export LD_LIBRARY_PATH="$OPTIX_SDK_PATH/lib64:$OPTIX_SDK_PATH/lib:$LD_LIBRARY_PATH"
    fi
    
    # Check for OptiX runtime libraries in common locations
    for optix_path in "/usr/local/nvidia/optix" "/opt/nvidia/optix" "/software/nvidia/optix" "/software/nvidia/optiX" "/usr/lib/x86_64-linux-gnu" "/usr/lib64" "/usr/local/lib" "/opt/nvidia/lib64"; do
        if [ -d "$optix_path" ]; then
            echo -e "${GREEN}Adding potential OptiX runtime path: $optix_path${NC}"
            export LD_LIBRARY_PATH="$optix_path:$LD_LIBRARY_PATH"
            
            # Check if this directory contains OptiX libraries
            if ls "$optix_path"/liboptix*.so* 1> /dev/null 2>&1 || ls "$optix_path"/libnvoptix*.so* 1> /dev/null 2>&1; then
                echo -e "${GREEN}Found OptiX libraries in: $optix_path${NC}"
            fi
        fi
    done
    
    # Print final LD_LIBRARY_PATH for debugging
    echo -e "${YELLOW}LD_LIBRARY_PATH: $LD_LIBRARY_PATH${NC}"
}

if [ -z "$CUDA_PATH" ]; then
    echo -e "${YELLOW}Warning: Could not find CUDA via rez-env${NC}"
    echo "Trying to run Nuke with default environment..."
    CUDA_LIB_PATH="/rdo/software/rez/packages/cuda/12.3.1_545.23.08/cuda/lib64"
    
    if [ -d "$CUDA_LIB_PATH" ]; then
        echo -e "${GREEN}Found CUDA libraries at $CUDA_LIB_PATH${NC}"
        export LD_LIBRARY_PATH="$CUDA_LIB_PATH:$LD_LIBRARY_PATH"
    fi
    
    # Add OptiX runtime libraries
    add_optix_runtime_paths
    
    # Try to run Nuke
    echo -e "${GREEN}Starting Nuke...${NC}"
    nuke "$@"
else
    echo -e "${GREEN}Found CUDA at $CUDA_PATH${NC}"
    echo "Running Nuke with CUDA environment..."
    
    # Add OptiX runtime libraries
    add_optix_runtime_paths
    
    # Run Nuke with CUDA environment
    echo -e "${GREEN}Starting Nuke with rez-env cuda...${NC}"
    rez-env cuda nuke-14.1 -- nuke "$@"
fi
