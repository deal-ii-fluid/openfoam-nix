#!/usr/bin/env bash

# 设置颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 获取当前系统架构
CURRENT_ARCH=$(uname -m)
if [ "$CURRENT_ARCH" = "aarch64" ]; then
    SYSTEM_ARCH="aarch64-linux"
elif [ "$CURRENT_ARCH" = "x86_64" ]; then
    SYSTEM_ARCH="x86_64-linux"
else
    echo -e "${RED}Unsupported architecture: $CURRENT_ARCH${NC}"
    exit 1
fi

# 函数：构建并推送包
build_and_push() {
    local package="$1"
    echo -e "${YELLOW}Building and pushing ${package} on ${SYSTEM_ARCH}...${NC}"
    
    # 清理旧的构建结果
    rm -f result
    
    # 构建包
    nix build .#"${package}"
    
    # 检查构建是否成功
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Build successful for ${package} on ${SYSTEM_ARCH}, pushing to cachix...${NC}"
        # 推送到 cachix
        if cachix push jiaqiwang969 result; then
            echo -e "${GREEN}Successfully pushed ${package} to cachix${NC}"
            return 0
        else
            echo -e "${RED}Failed to push ${package} to cachix${NC}"
            return 1
        fi
    else
        echo -e "${RED}Build failed for ${package} on ${SYSTEM_ARCH}!${NC}"
        return 1
    fi
}

# 所有需要构建的包
PACKAGES=(
    "openfoam-9"
    "openfoam-10"
    "openfoam-11"
    "blastfoam-9"
    "solids4foam-9"
    "solids4foam-10"
    "solids4foam-11"
    "precice-openfoam-9"
    "precice-openfoam-10"
    "precice-openfoam-11"
    "calculix-adapter"
)

# 如果提供了参数，只构建指定的包
if [ $# -gt 0 ]; then
    if [[ " ${PACKAGES[@]} " =~ " $1 " ]]; then
        build_and_push "$1"
        exit $?
    else
        echo -e "${RED}Unknown package: $1${NC}"
        echo "Available packages:"
        printf '%s\n' "${PACKAGES[@]}"
        exit 1
    fi
fi

# 构建所有包
FAILED_PACKAGES=()
for pkg in "${PACKAGES[@]}"; do
    if ! build_and_push "$pkg"; then
        FAILED_PACKAGES+=("$pkg")
    fi
done

# 报告结果
echo -e "\n${YELLOW}Build and push summary:${NC}"
echo -e "${GREEN}Total packages: ${#PACKAGES[@]}${NC}"
echo -e "${RED}Failed packages: ${#FAILED_PACKAGES[@]}${NC}"

if [ ${#FAILED_PACKAGES[@]} -gt 0 ]; then
    echo -e "\n${RED}Failed packages list:${NC}"
    printf '%s\n' "${FAILED_PACKAGES[@]}"
    exit 1
fi

exit 0
