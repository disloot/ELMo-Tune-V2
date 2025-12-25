#!/bin/bash

set -e

# apt-get update && apt-get install -y build-essential libgflags-dev libsnappy-dev zlib1g-dev libbz2-dev liblz4-dev libzstd-dev git python3 python3-pip wget fio 

# uv sync

# cd 到当前文件目录
cd "$(dirname "$0")"
root_dir=$(pwd)
echo "Root directory: $root_dir"
# 安装依赖
apt update || echo "Warning: apt update failed"
apt-get install -y build-essential libgflags-dev libsnappy-dev zlib1g-dev libbz2-dev liblz4-dev libzstd-dev wget fio || echo "Warning: apt install failed"

# 安装 Python 依赖
if command -v uv &> /dev/null; then
    uv sync


install_rocksdb() {
    mkdir -p tmp && cd tmp
    if [ ! -f "rocksdb-8.8.1.tar.gz" ]; then
    wget https://github.com/facebook/rocksdb/archive/refs/tags/v8.8.1.tar.gz -O rocksdb-8.8.1.tar.gz
    fi
    if [ ! -d "rocksdb-8.8.1" ]; then
    tar -xzf rocksdb-8.8.1.tar.gz
    # If the extracted directory is not rocksdb-8.8.1, rename it
    EXTRACTED_DIR=$(tar -tf rocksdb-8.8.1.tar.gz | head -n 1 | cut -f1 -d"/")
    if [ "$EXTRACTED_DIR" != "rocksdb-8.8.1" ]; then
        mv "$EXTRACTED_DIR" rocksdb-8.8.1
    fi
    fi
    
    echo "Copying custom tools to RocksDB source..."
     cp "$root_dir/db_bench_dynamic_opts/db_bench_tool.cc" "./rocksdb-8.8.1/tools/"
     cp "$root_dir/db_bench_dynamic_opts/json.hpp" "./rocksdb-8.8.1/tools/"
     cp "$root_dir/trace_analyzer/tools/trace_analyzer_tool.cc" "./rocksdb-8.8.1/tools/"
     cp "$root_dir/trace_analyzer/tools/trace_analyzer_tool.h" "./rocksdb-8.8.1/tools/"
    
    cd rocksdb-8.8.1
    make -j4 static_lib db_bench trace_analyzer
    mkdir -p $root_dir/bin/
    cp db_bench trace_analyzer $root_dir/bin/
    cd $root_dir
}
 
# 检查是否已安装 RocksDB
if [ ! -f "$root_dir/bin/db_bench" ]; then
    echo "Install RocksDB."
    install_rocksdb
else
    echo "RocksDB already installed."
fi

configure_sudoers() {
    local HELPER_SCRIPT=$1
    local SUDO_FILE_NAME=$2
    local SUDO_FILE="/etc/sudoers.d/$SUDO_FILE_NAME"

    echo "Configuring sudoers for $(basename "$HELPER_SCRIPT")..."
    
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
    
    echo "Attempting to write sudoers configuration to $SUDO_FILE..."
    
    # 写入配置 (需要 sudo 权限)
    if [ "$EUID" -ne 0 ]; then
        echo "Warning: Not running as root. Skipping sudoers configuration."
        echo "You may need to manually configure sudoers for cgroup helper."
        return 0
    fi

    if [ ! -w "/etc/sudoers.d/" ]; then
        echo "Warning: /etc/sudoers.d/ is not writable. Skipping sudoers configuration."
        return 0
    fi

    echo "$SUDO_CONFIG" | tee "$SUDO_FILE" > /dev/null || { echo "Warning: Failed to write to $SUDO_FILE"; return 0; }
    chmod 0440 "$SUDO_FILE" || true
    
    # 验证配置
    if visudo -c -f "$SUDO_FILE"; then
        echo "Sudoers configured successfully."
    else
        echo "Error: Invalid sudoers configuration generated."
        rm -f "$SUDO_FILE"
        return 1
    fi
}

HELPER_SCRIPT="$root_dir/utils/root_cgroup_helper.sh"
SUDO_FILE_NAME="ELMo-Tune-V2"
configure_sudoers "$HELPER_SCRIPT" "$SUDO_FILE_NAME"
