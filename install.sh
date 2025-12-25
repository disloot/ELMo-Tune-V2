#!/bin/bash

set -e

# cd 到当前文件目录
cd "$(dirname "$0")"
root_dir=$(pwd)
echo "Root directory: $root_dir"

# 安装依赖
sudo apt update || echo "Warning: apt update failed"
sudo apt-get install -y build-essential libgflags-dev libsnappy-dev zlib1g-dev libbz2-dev liblz4-dev libzstd-dev wget fio || echo "Warning: apt install failed"
pip install uv
uv sync
# 安装 Python 依赖
if command -v uv &> /dev/null; then
    uv sync
fi

install_rocksdb() {
    # 如果监测到 db_bench trace_analyzer 已安装，跳过安装
    mkdir -p tmp && cd tmp
    if [ ! -f "rocksdb-8.8.1.tar.gz" ]; then
    wget https://github.com/facebook/rocksdb/archive/refs/tags/v8.8.1.tar.gz -O rocksdb-8.8.1.tar.gz
    fi
    if [ ! -f "rocksdb-8.8.1/Makefile" ]; then
    echo "Extracting RocksDB..."
    rm -rf rocksdb-8.8.1
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
if [ ! -f "$root_dir/bin/db_bench" ] || [ ! -f "$root_dir/bin/trace_analyzer" ]; then
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
    
    # 使用 sudo 写入配置
    if ! echo "$SUDO_CONFIG" | sudo tee "$SUDO_FILE" > /dev/null; then
        echo "Warning: Failed to write to $SUDO_FILE. You might need to run this with sudo or manually configure it."
        return 0
    fi
    sudo chmod 0440 "$SUDO_FILE" || true
    
    # 验证配置
    if sudo visudo -c -f "$SUDO_FILE"; then
        echo "Sudoers configured successfully."
    else
        echo "Error: Invalid sudoers configuration generated."
        sudo rm -f "$SUDO_FILE"
        return 1
    fi
}

HELPER_SCRIPT="$root_dir/utils/root_cgroup_helper.sh"
SUDO_FILE_NAME="ELMo-Tune-V2"
configure_sudoers "$HELPER_SCRIPT" "$SUDO_FILE_NAME"