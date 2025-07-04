#!/bin/bash

# Script to run Nuke with CUDA environment for OptiXDenoiser

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Find CUDA path using rez-env
CUDA_PATH=$(rez-env cuda --command "echo \$REZ_CUDA_ROOT" 2>/dev/null || echo "")

if [ -z "$CUDA_PATH" ]; then
    echo -e "${YELLOW}Warning: Could not find CUDA via rez-env${NC}"
    echo "Trying to run Nuke with default environment..."
    CUDA_LIB_PATH="/rdo/software/rez/packages/cuda/12.3.1_545.23.08/cuda/lib64"
    
    if [ -d "$CUDA_LIB_PATH" ]; then
        echo -e "${GREEN}Found CUDA libraries at $CUDA_LIB_PATH${NC}"
        export LD_LIBRARY_PATH="$CUDA_LIB_PATH:$LD_LIBRARY_PATH"
    fi
    
    # Add OptiX paths to LD_LIBRARY_PATH
    OPTIX_SDK_PATH="/software/nvidia/optiX/NVIDIA-OptiX-SDK-8.0.0-linux64-x86_64"
    if [ -d "$OPTIX_SDK_PATH" ]; then
        echo -e "${GREEN}Adding OptiX SDK path to LD_LIBRARY_PATH: $OPTIX_SDK_PATH${NC}"
        export LD_LIBRARY_PATH="$OPTIX_SDK_PATH/lib64:$LD_LIBRARY_PATH"
    fi
    
    # Check for OptiX runtime libraries in common locations
    for optix_path in "/usr/local/nvidia/optix" "/opt/nvidia/optix" "/software/nvidia/optix" "/software/nvidia/optiX"; do
        if [ -d "$optix_path" ]; then
            echo -e "${GREEN}Adding potential OptiX runtime path: $optix_path${NC}"
            export LD_LIBRARY_PATH="$optix_path/lib64:$LD_LIBRARY_PATH"
        fi
    done
    
    # Try to run Nuke
    nuke "$@"
else
    echo -e "${GREEN}Found CUDA at $CUDA_PATH${NC}"
    echo "Running Nuke with CUDA environment..."
    
    # Add OptiX paths to LD_LIBRARY_PATH
    OPTIX_SDK_PATH="/software/nvidia/optiX/NVIDIA-OptiX-SDK-8.0.0-linux64-x86_64"
    if [ -d "$OPTIX_SDK_PATH" ]; then
        echo -e "${GREEN}Adding OptiX SDK path to LD_LIBRARY_PATH: $OPTIX_SDK_PATH${NC}"
        # Pass the LD_LIBRARY_PATH to the rez-env command
        export LD_LIBRARY_PATH="$OPTIX_SDK_PATH/lib64:$LD_LIBRARY_PATH"
    fi
    
    # Check for OptiX runtime libraries in common locations
    for optix_path in "/usr/local/nvidia/optix" "/opt/nvidia/optix" "/software/nvidia/optix" "/software/nvidia/optiX"; do
        if [ -d "$optix_path" ]; then
            echo -e "${GREEN}Adding potential OptiX runtime path: $optix_path${NC}"
            export LD_LIBRARY_PATH="$optix_path/lib64:$LD_LIBRARY_PATH"
        fi
    done
    
    # Run Nuke with CUDA environment
    rez-env cuda nuke-14.1 -- nuke "$@"
fi
