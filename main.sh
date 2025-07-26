#启动脚本

# 检测Termux环境
check_termux() {
    if [ -d "/data/data/com.termux/files/usr" ] && [ -n "$TERMUX_VERSION" ]; then
        return 0  # 是Termux环境
    else
        return 1  # 不是Termux环境
    fi
}

# 主逻辑
if check_termux; then
    echo "检测到运行环境: Termux"
    echo "欢迎，即将进入"
    sleep 1
cd ~
pkg install -y curl ; bash -c "$(curl -L https://gitee.com/jiangnan-qwq/AetherCraft_cn/raw/main/proot.sh)"
else
    echo "检测到运行环境: 标准Linux系统"
bash -c "$(curl -L https://gitee.com/jiangnan-qwq/AetherCraft_cn/raw/main/menu.sh)"
   fi
