#!/usr/bin/env bash

# 创建临时文件来存储环境变量
TEMP_DIR=$(mktemp -d)
BEFORE_ENV="${TEMP_DIR}/before_env.txt"
AFTER_ENV="${TEMP_DIR}/after_env.txt"
BEFORE_OF="${TEMP_DIR}/before_of.txt"
AFTER_OF="${TEMP_DIR}/after_of.txt"

# 保存当前环境变量
env | sort > "$BEFORE_ENV"

# 提取 OpenFOAM 相关变量
env | grep -E "^(FOAM|WM)" | sort > "$BEFORE_OF"

# 获取 OpenFOAM 目录
OPENFOAM_DIR="${1:-/path/to/openfoam}"

echo "=== 设置第一个环境 ==="
source "$OPENFOAM_DIR/etc/bashrc"

# 保存第一个环境的变量
env | sort > "$AFTER_ENV"
env | grep -E "^(FOAM|WM)" | sort > "$AFTER_OF"

# 比较所有变量的差异
echo -e "\n=== 所有环境变量的变化 ==="
diff "$BEFORE_ENV" "$AFTER_ENV" | grep -E "^[<>]" | sed 's/^< /[-] /;s/^> /[+] /'

# 比较 OpenFOAM 相关变量
echo -e "\n=== OpenFOAM 相关变量 ==="
cat "$AFTER_OF"

# 重置环境
for var in $(diff "$BEFORE_ENV" "$AFTER_ENV" | grep "^>" | cut -d' ' -f2- | cut -d= -f1); do
    unset "$var"
done

# 恢复原始环境
while read -r line; do
    export "$line"
done < "$BEFORE_ENV"

echo -e "\n=== 设置第二个环境 ==="
source "$OPENFOAM_DIR/../bin/set-openfoam-vars"

# 保存第二个环境的变量
AFTER2_ENV="${TEMP_DIR}/after2_env.txt"
AFTER2_OF="${TEMP_DIR}/after2_of.txt"
env | sort > "$AFTER2_ENV"
env | grep -E "^(FOAM|WM)" | sort > "$AFTER2_OF"

# 比较两种设置方式的 OpenFOAM 变量差异
echo -e "\n=== 两种设置方式的 OpenFOAM 变量差异 ==="
diff "$AFTER_OF" "$AFTER2_OF" | grep -E "^[<>]" | sed 's/^< /[etc\/bashrc] /;s/^> /[set-openfoam-vars] /'

# 清理临时文件
rm -rf "$TEMP_DIR" 