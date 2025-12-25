#!/bin/bash

# 获取脚本所在目录的绝对路径
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

configure_sudoers() {
    echo "Configuring sudoers for root_cgroup_helper.sh..."
    
    # 路径修复：HELPER_SCRIPT 就在当前脚本同级目录下
    HELPER_SCRIPT="$SCRIPT_DIR/root_cgroup_helper.sh"
    
    echo "Checking helper script at: $HELPER_SCRIPT"
    
    # 确保脚本存在并有执行权限
    if [ -f "$HELPER_SCRIPT" ]; then
        chmod +x "$HELPER_SCRIPT"
        echo "Found helper script and set execution permission."
    else
        echo "Error: Helper script not found at $HELPER_SCRIPT"
        return 1
    fi
    
    # 定义 sudoers 内容
    SUDO_CONFIG="ALL ALL=(ALL) NOPASSWD: $HELPER_SCRIPT"
    SUDO_FILE="/etc/sudoers.d/ELMo_Tune_V2"
    
    echo "Attempting to write sudoers configuration to $SUDO_FILE..."
    
    # 写入配置 (需要 sudo 权限)
    if [ "$EUID" -ne 0 ]; then
        echo "Error: Please run this script with sudo (e.g., sudo $0)"
        return 1
    fi

    echo "$SUDO_CONFIG" | tee "$SUDO_FILE" > /dev/null
    chmod 0440 "$SUDO_FILE"
    
    # 验证配置
    if visudo -c -f "$SUDO_FILE"; then
        echo "Sudoers configured successfully."
    else
        echo "Error: Invalid sudoers configuration generated."
        rm -f "$SUDO_FILE"
        return 1
    fi
}

configure_sudoers
