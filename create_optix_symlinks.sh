#!/bin/bash

# Script to create symbolic links for OptiX runtime libraries
# This is a workaround when you can't download the official OptiX runtime package

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}OptiX Runtime Symlink Creator${NC}"
echo "=================================="
echo ""

# Create a directory for the OptiX runtime libraries
RUNTIME_DIR="$HOME/optix_runtime"
mkdir -p "$RUNTIME_DIR"

# Check for the NVIDIA driver with OptiX runtime
NVIDIA_DRIVER_PATH="/software/nvidia/current/linux/NVIDIA-Linux-x86_64-470.63.01"
if [ -f "$NVIDIA_DRIVER_PATH/libnvoptix.so.470.63.01" ]; then
    echo -e "${GREEN}Found NVIDIA OptiX runtime library at: $NVIDIA_DRIVER_PATH${NC}"
    
    # Create symbolic links
    echo -e "${GREEN}Creating symbolic links in $RUNTIME_DIR...${NC}"
    ln -sf "$NVIDIA_DRIVER_PATH/libnvoptix.so.470.63.01" "$RUNTIME_DIR/libnvoptix.so.1"
    ln -sf "$RUNTIME_DIR/libnvoptix.so.1" "$RUNTIME_DIR/libnvoptix.so"
    
    echo -e "${GREEN}Created symbolic links for libnvoptix.so${NC}"
else
    echo -e "${RED}Could not find NVIDIA OptiX runtime library${NC}"
    echo "Searching for alternative OptiX libraries..."
    
    # Try to find any OptiX libraries on the system
    OPTIX_LIBS=$(find /usr /opt /software -name "liboptix*.so*" -o -name "libnvoptix*.so*" 2>/dev/null)
    
    if [ -n "$OPTIX_LIBS" ]; then
        echo -e "${GREEN}Found OptiX libraries:${NC}"
        echo "$OPTIX_LIBS"
        
        # Create symbolic links for each found library
        for lib in $OPTIX_LIBS; do
            base_name=$(basename "$lib")
            echo -e "${GREEN}Creating symbolic link for $base_name${NC}"
            ln -sf "$lib" "$RUNTIME_DIR/$base_name"
            
            # Create additional links without version numbers
            base_without_version=$(echo "$base_name" | sed 's/\.[0-9]\+\.[0-9]\+$//')
            if [ "$base_without_version" != "$base_name" ]; then
                ln -sf "$RUNTIME_DIR/$base_name" "$RUNTIME_DIR/$base_without_version"
            fi
            
            base_without_version=$(echo "$base_name" | sed 's/\.[0-9]\+$//')
            if [ "$base_without_version" != "$base_name" ]; then
                ln -sf "$RUNTIME_DIR/$base_name" "$RUNTIME_DIR/$base_without_version"
            fi
        done
    else
        echo -e "${RED}No OptiX libraries found on the system${NC}"
        echo "You may need to download the OptiX runtime package from NVIDIA."
    fi
fi

# Create a script to set up the environment
echo -e "${GREEN}Creating environment setup script...${NC}"
cat > "$RUNTIME_DIR/setup_optix_env.sh" << EOF
#!/bin/bash
# Add OptiX runtime libraries to LD_LIBRARY_PATH
export LD_LIBRARY_PATH="$RUNTIME_DIR:\$LD_LIBRARY_PATH"
echo "OptiX runtime environment set up successfully"
EOF
chmod +x "$RUNTIME_DIR/setup_optix_env.sh"

# Create an enhanced run_nuke script
echo -e "${GREEN}Creating enhanced run_nuke script...${NC}"
cat > "$(dirname "$0")/run_nuke_with_optix.sh" << EOF
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
export LD_LIBRARY_PATH="$RUNTIME_DIR:\$LD_LIBRARY_PATH"
echo -e "\${GREEN}Added OptiX runtime path: $RUNTIME_DIR\${NC}"

# Find CUDA path using rez-env
CUDA_PATH=\$(rez-env cuda --command "echo \\\$REZ_CUDA_ROOT" 2>/dev/null || echo "")

if [ -z "\$CUDA_PATH" ]; then
    echo -e "\${YELLOW}Warning: Could not find CUDA via rez-env\${NC}"
    echo "Trying to run Nuke with default environment..."
    CUDA_LIB_PATH="/rdo/software/rez/packages/cuda/12.3.1_545.23.08/cuda/lib64"
    
    if [ -d "\$CUDA_LIB_PATH" ]; then
        echo -e "\${GREEN}Found CUDA libraries at \$CUDA_LIB_PATH\${NC}"
        export LD_LIBRARY_PATH="\$CUDA_LIB_PATH:\$LD_LIBRARY_PATH"
    fi
    
    # Add OptiX SDK path to LD_LIBRARY_PATH
    OPTIX_SDK_PATH="/software/nvidia/optiX/NVIDIA-OptiX-SDK-9.0.0-linux64-x86_64"
    if [ -d "\$OPTIX_SDK_PATH" ]; then
        echo -e "\${GREEN}Adding OptiX SDK path to LD_LIBRARY_PATH: \$OPTIX_SDK_PATH\${NC}"
        export LD_LIBRARY_PATH="\$OPTIX_SDK_PATH/lib64:\$OPTIX_SDK_PATH/lib:\$LD_LIBRARY_PATH"
    fi
    
    # Print final LD_LIBRARY_PATH for debugging
    echo -e "\${YELLOW}LD_LIBRARY_PATH: \$LD_LIBRARY_PATH\${NC}"
    
    # Try to run Nuke
    echo -e "\${GREEN}Starting Nuke...\${NC}"
    nuke "\$@"
else
    echo -e "\${GREEN}Found CUDA at \$CUDA_PATH\${NC}"
    echo "Running Nuke with CUDA environment..."
    
    # Add OptiX SDK path to LD_LIBRARY_PATH
    OPTIX_SDK_PATH="/software/nvidia/optiX/NVIDIA-OptiX-SDK-9.0.0-linux64-x86_64"
    if [ -d "\$OPTIX_SDK_PATH" ]; then
        echo -e "\${GREEN}Adding OptiX SDK path to LD_LIBRARY_PATH: \$OPTIX_SDK_PATH\${NC}"
        export LD_LIBRARY_PATH="\$OPTIX_SDK_PATH/lib64:\$OPTIX_SDK_PATH/lib:\$LD_LIBRARY_PATH"
    fi
    
    # Print final LD_LIBRARY_PATH for debugging
    echo -e "\${YELLOW}LD_LIBRARY_PATH: \$LD_LIBRARY_PATH\${NC}"
    
    # Run Nuke with CUDA environment
    echo -e "\${GREEN}Starting Nuke with rez-env cuda...\${NC}"
    rez-env cuda nuke-14.1 -- nuke "\$@"
fi
EOF
chmod +x "$(dirname "$0")/run_nuke_with_optix.sh"

echo ""
echo -e "${GREEN}OptiX runtime environment setup completed!${NC}"
echo ""
echo "To use the OptiX runtime libraries, you can:"
echo "1. Source the setup script: source $RUNTIME_DIR/setup_optix_env.sh"
echo "2. Use the new run_nuke_with_optix.sh script"
echo ""
echo -e "${YELLOW}Note:${NC} You may need to restart Nuke for the changes to take effect."
