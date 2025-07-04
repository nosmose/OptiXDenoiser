#!/bin/bash
# build_nuke14.1.sh - Build script for OptiXDenoiser Nuke plugin
# Targeting Nuke 14.1 with rez-env cuda

set -e

# Configuration
NUKE_VERSION="14.1v3"
NUKE_INSTALL_PATH="/softwareLocal/nuke/linux/Nuke${NUKE_VERSION}"
BUILD_DIR="build_nuke14.1"
INSTALL_DIR="install_nuke14.1"

# Alternative Nuke paths to check
NUKE_PATHS=(
    "/softwareLocal/nuke/linux/Nuke14.1v3"
    "/opt/Nuke${NUKE_VERSION}"
    "/usr/local/Nuke14.1"
    "/opt/Nuke14.1"
    "$HOME/Nuke${NUKE_VERSION}"
)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Building OptiXDenoiser Plugin for Nuke ${NUKE_VERSION}${NC}"
echo "=================================================="

# Find Nuke installation
FOUND_NUKE=""
for path in "${NUKE_PATHS[@]}"; do
    if [ -d "$path" ]; then
        FOUND_NUKE="$path"
        echo -e "${GREEN}Found Nuke at: $path${NC}"
        break
    fi
done

if [ -z "$FOUND_NUKE" ]; then
    echo -e "${RED}Error: Nuke installation not found in any of these locations:${NC}"
    for path in "${NUKE_PATHS[@]}"; do
        echo "  $path"
    done
    echo ""
    echo "Please set NUKE_INSTALL_PATH manually in this script"
    exit 1
fi

NUKE_INSTALL_PATH="$FOUND_NUKE"

# Check if Nuke is installed and find DDImage library
echo -e "${YELLOW}Checking Nuke installation...${NC}"
echo "Nuke path: ${NUKE_INSTALL_PATH}"

if [ ! -d "${NUKE_INSTALL_PATH}" ]; then
    echo -e "${RED}Error: Nuke installation not found at ${NUKE_INSTALL_PATH}${NC}"
    exit 1
fi

# Check for DDImage library
DDIMAGE_PATHS=(
    "${NUKE_INSTALL_PATH}/lib/libDDImage.so"
    "${NUKE_INSTALL_PATH}/lib64/libDDImage.so"
    "${NUKE_INSTALL_PATH}/libDDImage.so"
    "${NUKE_INSTALL_PATH}/lib/DDImage.so"
)

FOUND_DDIMAGE=""
for ddimage_path in "${DDIMAGE_PATHS[@]}"; do
    if [ -f "$ddimage_path" ]; then
        FOUND_DDIMAGE="$ddimage_path"
        echo -e "${GREEN}Found DDImage library: $ddimage_path${NC}"
        break
    fi
done

if [ -z "$FOUND_DDIMAGE" ]; then
    echo -e "${YELLOW}Warning: DDImage library not found in expected locations${NC}"
    echo "Searched in:"
    for ddimage_path in "${DDIMAGE_PATHS[@]}"; do
        echo "  $ddimage_path"
    done
    echo ""
    echo "Contents of ${NUKE_INSTALL_PATH}/lib:"
    if [ -d "${NUKE_INSTALL_PATH}/lib" ]; then
        ls -la "${NUKE_INSTALL_PATH}/lib" | grep -i ddimage || echo "  No DDImage files found"
    else
        echo "  Directory does not exist"
    fi
    echo ""
    echo "Continuing with build - CMake will search more thoroughly..."
fi

# Check for include directory
if [ ! -d "${NUKE_INSTALL_PATH}/include" ]; then
    echo -e "${RED}Error: Nuke include directory not found at ${NUKE_INSTALL_PATH}/include${NC}"
    echo "This suggests Nuke NDK is not installed or incomplete installation"
    exit 1
else
    echo -e "${GREEN}Found Nuke include directory${NC}"
fi

# Check CUDA installation via rez-env
echo -e "${YELLOW}Checking CUDA installation via rez-env...${NC}"
CUDA_PATH=$(rez-env cuda --command "which nvcc" 2>/dev/null | xargs dirname | xargs dirname || echo "")

if [ -z "$CUDA_PATH" ]; then
    echo -e "${RED}Error: CUDA not found via rez-env cuda${NC}"
    echo "Please make sure rez-env cuda is available in your environment"
    exit 1
else
    echo -e "${GREEN}Found CUDA via rez-env at: $CUDA_PATH${NC}"
fi

# Check OptiX installation
echo -e "${YELLOW}Checking OptiX installation...${NC}"
OPTIX_PATHS=(
    "/opt/NVIDIA-OptiX-SDK-9.0.0-linux64-x86_64"
    "/opt/NVIDIA-OptiX-SDK-8.0.0-linux64-x86_64"
    "/opt/NVIDIA-OptiX-SDK-7.0.0-linux64-x86_64"
    "/rdo/software/rez/packages/optix/7.3.0"
    "/rdo/software/rez/packages/optix/7.0.0"
)

FOUND_OPTIX=""
for optix_path in "${OPTIX_PATHS[@]}"; do
    if [ -d "$optix_path" ] && [ -f "$optix_path/include/optix.h" ]; then
        FOUND_OPTIX="$optix_path"
        echo -e "${GREEN}Found OptiX at: $optix_path${NC}"
        break
    fi
done

if [ -z "$FOUND_OPTIX" ]; then
    echo -e "${YELLOW}Warning: OptiX SDK not found in standard locations${NC}"
    echo "Trying to find OptiX via rez-env..."
    
    OPTIX_PATH=$(rez-env optix --command "echo \$REZ_OPTIX_ROOT" 2>/dev/null || echo "")
    
    if [ -n "$OPTIX_PATH" ] && [ -f "$OPTIX_PATH/include/optix.h" ]; then
        FOUND_OPTIX="$OPTIX_PATH"
        echo -e "${GREEN}Found OptiX via rez-env at: $OPTIX_PATH${NC}"
    else
        echo -e "${RED}Error: OptiX SDK not found${NC}"
        echo "Please install OptiX SDK or set OPTIX_ROOT_DIR manually in CMakeLists.txt"
        exit 1
    fi
fi

# Clean previous build
if [ -d "${BUILD_DIR}" ]; then
    echo "Cleaning previous build..."
    rm -rf "${BUILD_DIR}"
fi

if [ -d "${INSTALL_DIR}" ]; then
    rm -rf "${INSTALL_DIR}"
fi

# Create build directory
mkdir -p "${BUILD_DIR}"
mkdir -p "${INSTALL_DIR}"

# Run CMake configuration and build using rez-env cuda
echo -e "${GREEN}Running CMake configuration and build with rez-env cuda...${NC}"

# Create a build script to run inside rez-env
cat > build_inside_rez.sh << EOF
#!/bin/bash
set -e

cd "${BUILD_DIR}"

# Run CMake configuration
cmake .. \\
    -DCMAKE_BUILD_TYPE=Release \\
    -DCMAKE_INSTALL_PREFIX="../${INSTALL_DIR}" \\
    -DNUKE_INSTALL_PATH="${NUKE_INSTALL_PATH}" \\
    -DOPTIX_ROOT_DIR="${FOUND_OPTIX}" \\
    -DCUDA_ROOT_DIR="${CUDA_PATH}" \\
    -DCMAKE_VERBOSE_MAKEFILE=ON

# Build the plugin
make -j\$(nproc) VERBOSE=1

# Install the plugin
make install
EOF

chmod +x build_inside_rez.sh

# Run the build script inside rez-env cuda
echo -e "${GREEN}Running build inside rez-env cuda environment...${NC}"
rez-env cuda -- ./build_inside_rez.sh

# Clean up the temporary build script
rm build_inside_rez.sh

# Check if plugin was built successfully
PLUGIN_FILE="${INSTALL_DIR}/plugins/OptiXDenoiser.so"

if [ -f "${PLUGIN_FILE}" ]; then
    echo -e "${GREEN}Success! Plugin built at:"
    echo "  ${PLUGIN_FILE}${NC}"
    
    # Show plugin info
    echo ""
    echo "Plugin Information:"
    echo "=================="
    file "${PLUGIN_FILE}"
    ls -la "${PLUGIN_FILE}"
    
    # Show dependencies
    echo ""
    echo "Plugin Dependencies:"
    echo "==================="
    ldd "${PLUGIN_FILE}"
    
    echo ""
    echo -e "${GREEN}Installation Instructions:${NC}"
    echo "1. Copy the plugin to your Nuke plugin directory:"
    echo "   - ${PLUGIN_FILE}"
    echo "2. Common locations:"
    echo "   - ~/.nuke/"
    echo "   - \$NUKE_PATH/"
    echo "   - /usr/local/Nuke${NUKE_VERSION}/plugins/"
    echo ""
    echo "3. Or set environment variable:"
    echo "   export NUKE_PATH=\$NUKE_PATH:$(pwd)/${INSTALL_DIR}/plugins"
    
    # Create ~/.nuke/plugins directory if it doesn't exist
    echo -e "\n${GREEN}Installing plugin to ~/.nuke/plugins...${NC}"
    mkdir -p ~/.nuke/plugins
    
    # Copy plugin to ~/.nuke/plugins
    cp -v "${PLUGIN_FILE}" ~/.nuke/plugins/
    
    # Create menu.py file if it doesn't exist
    if [ ! -f ~/.nuke/menu.py ]; then
        echo -e "${YELLOW}Creating menu.py file...${NC}"
        cat > ~/.nuke/menu.py << 'EOF'
import nuke

# Add the OptiXDenoiser node to the Filter menu
toolbar = nuke.menu("Nodes")
filterMenu = toolbar.findItem("Filter")
if not filterMenu:
    filterMenu = toolbar.addMenu("Filter")

# Add the node to the menu
filterMenu.addCommand("OptiXDenoiser", "nuke.createNode('OptiXDenoiser')")

# Print debug info
print("OptiXDenoiser plugin registered in the Filter menu")
EOF
    else
        # Append to existing menu.py
        echo -e "${YELLOW}Appending to existing menu.py file...${NC}"
        cat >> ~/.nuke/menu.py << 'EOF'

# Add the OptiXDenoiser node to the Filter menu
toolbar = nuke.menu("Nodes")
filterMenu = toolbar.findItem("Filter")
if not filterMenu:
    filterMenu = toolbar.addMenu("Filter")

# Add the node to the menu
filterMenu.addCommand("OptiXDenoiser", "nuke.createNode('OptiXDenoiser')")

# Print debug info
print("OptiXDenoiser plugin registered in the Filter menu")
EOF
    fi
    
    echo -e "${GREEN}Plugin and menu.py installed to ~/.nuke/plugins${NC}"
    echo "Restart Nuke to use the plugin"
else
    echo -e "${RED}Error: Plugin build failed!${NC}"
    exit 1
fi
