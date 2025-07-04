#!/bin/bash

# Enhanced script to run Nuke with OptiX runtime libraries
# With improved OptiX runtime library detection

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo "OptiXDenoiser Nuke Launcher with Enhanced Runtime Library Detection"
echo "=================================================================="

# Add OptiX runtime directory to LD_LIBRARY_PATH
export LD_LIBRARY_PATH="/mnt/users/jhery/optix_runtime:$LD_LIBRARY_PATH"
echo -e "${GREEN}Added OptiX runtime path: /mnt/users/jhery/optix_runtime${NC}"

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
    
    # Add OptiX SDK path to LD_LIBRARY_PATH
    OPTIX_SDK_PATH="/software/nvidia/optiX/NVIDIA-OptiX-SDK-9.0.0-linux64-x86_64"
    if [ -d "$OPTIX_SDK_PATH" ]; then
        echo -e "${GREEN}Adding OptiX SDK path to LD_LIBRARY_PATH: $OPTIX_SDK_PATH${NC}"
        export LD_LIBRARY_PATH="$OPTIX_SDK_PATH/lib64:$OPTIX_SDK_PATH/lib:$LD_LIBRARY_PATH"
    fi
    
    # Print final LD_LIBRARY_PATH for debugging
    echo -e "${YELLOW}LD_LIBRARY_PATH: $LD_LIBRARY_PATH${NC}"
    
    # Try to run Nuke
    echo -e "${GREEN}Starting Nuke...${NC}"
    nuke "$@"
else
    echo -e "${GREEN}Found CUDA at $CUDA_PATH${NC}"
    echo "Running Nuke with CUDA environment..."
    
    # Add OptiX SDK path to LD_LIBRARY_PATH
    OPTIX_SDK_PATH="/software/nvidia/optiX/NVIDIA-OptiX-SDK-9.0.0-linux64-x86_64"
    if [ -d "$OPTIX_SDK_PATH" ]; then
        echo -e "${GREEN}Adding OptiX SDK path to LD_LIBRARY_PATH: $OPTIX_SDK_PATH${NC}"
        export LD_LIBRARY_PATH="$OPTIX_SDK_PATH/lib64:$OPTIX_SDK_PATH/lib:$LD_LIBRARY_PATH"
    fi
    
    # Print final LD_LIBRARY_PATH for debugging
    echo -e "${YELLOW}LD_LIBRARY_PATH: $LD_LIBRARY_PATH${NC}"
    
    # Run Nuke with CUDA environment
    echo -e "${GREEN}Starting Nuke with rez-env cuda...${NC}"
    rez-env cuda nuke-14.1 -- nuke "$@"
fi
