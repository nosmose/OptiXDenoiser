#!/bin/bash

# Script to download and extract OptiX runtime libraries for OptiX SDK 9.0.0
# Note: This requires an NVIDIA developer account

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}OptiX Runtime Downloader${NC}"
echo "================================="
echo ""
echo "This script will help you download and install the OptiX runtime libraries."
echo ""
echo -e "${YELLOW}Important:${NC} You need an NVIDIA developer account to download OptiX."
echo "If you don't have one, you can register at: https://developer.nvidia.com/login"
echo ""
echo "Steps to download OptiX runtime libraries:"
echo "1. Go to: https://developer.nvidia.com/designworks/optix/download"
echo "2. Log in with your NVIDIA developer account"
echo "3. Download the Linux version of OptiX SDK 9.0.0"
echo "4. Place the downloaded file in this directory"
echo "5. Run this script again with the downloaded file name as an argument"
echo ""

# Check if a file was provided
if [ $# -eq 0 ]; then
    echo -e "${RED}Error: No OptiX SDK package file specified${NC}"
    echo "Usage: $0 <path-to-optix-package>"
    exit 1
fi

OPTIX_PACKAGE=$1

# Check if the file exists
if [ ! -f "$OPTIX_PACKAGE" ]; then
    echo -e "${RED}Error: File not found: $OPTIX_PACKAGE${NC}"
    exit 1
fi

# Extract the package
echo -e "${GREEN}Extracting OptiX package...${NC}"
mkdir -p optix_runtime_extract
tar -xf "$OPTIX_PACKAGE" -C optix_runtime_extract

# Find the runtime libraries
echo -e "${GREEN}Searching for OptiX runtime libraries...${NC}"
RUNTIME_LIBS=$(find optix_runtime_extract -name "*.so*" | grep -v "libglfw")

if [ -z "$RUNTIME_LIBS" ]; then
    echo -e "${RED}Error: No OptiX runtime libraries found in the package${NC}"
    exit 1
fi

# Create runtime directory
RUNTIME_DIR="$HOME/optix_runtime"
mkdir -p "$RUNTIME_DIR"

# Copy runtime libraries
echo -e "${GREEN}Copying OptiX runtime libraries to $RUNTIME_DIR...${NC}"
for lib in $RUNTIME_LIBS; do
    cp -v "$lib" "$RUNTIME_DIR/"
done

# Create a script to set up the environment
echo -e "${GREEN}Creating environment setup script...${NC}"
cat > "$RUNTIME_DIR/setup_optix_env.sh" << EOF
#!/bin/bash
# Add OptiX runtime libraries to LD_LIBRARY_PATH
export LD_LIBRARY_PATH="$RUNTIME_DIR:\$LD_LIBRARY_PATH"
echo "OptiX runtime environment set up successfully"
EOF
chmod +x "$RUNTIME_DIR/setup_optix_env.sh"

# Update the run_nuke_with_cuda.sh script
echo -e "${GREEN}Updating run_nuke_with_cuda.sh script...${NC}"
NUKE_SCRIPT="$(dirname "$0")/run_nuke_with_cuda_enhanced.sh"

if [ -f "$NUKE_SCRIPT" ]; then
    # Add the OptiX runtime path to the script
    sed -i "s|export LD_LIBRARY_PATH=|export LD_LIBRARY_PATH=\"$RUNTIME_DIR:\" |g" "$NUKE_SCRIPT"
    echo -e "${GREEN}Updated $NUKE_SCRIPT with OptiX runtime path${NC}"
fi

echo ""
echo -e "${GREEN}OptiX runtime libraries installed successfully!${NC}"
echo ""
echo "To use the OptiX runtime libraries, you can:"
echo "1. Source the setup script: source $RUNTIME_DIR/setup_optix_env.sh"
echo "2. Use the updated run_nuke_with_cuda_enhanced.sh script"
echo ""
echo -e "${YELLOW}Note:${NC} You may need to restart Nuke for the changes to take effect."
