# 备份原 sources.list
cp /etc/apt/sources.list /etc/apt/sources.list.bak

# 选择镜像源
MIRROR="https://mirrors.ustc.edu.cn/ubuntu-ports/"

# 检测 Ubuntu 版本代号（如 jammy, noble 等）
CODENAME=$(lsb_release -cs 2>/dev/null || echo "noble")  # 默认 noble (24.04)

# 生成新的 sources.list
cat > /etc/apt/sources.list << EOL
deb ${MIRROR} ${CODENAME} main restricted universe multiverse
deb ${MIRROR} ${CODENAME}-updates main restricted universe multiverse
deb ${MIRROR} ${CODENAME}-backports main restricted universe multiverse
deb ${MIRROR} ${CODENAME}-security main restricted universe multiverse
EOL

echo "已替换为 ${MIRROR} (Ubuntu ${CODENAME})"
echo "正在更新软件列表..."
apt update -y && apt upgrade -y

bash -c "$(curl -L https://gitee.com/jiangnan-qwq/AetherCraft_cn/raw/main/menu.sh)"
