# 获取脚本的绝对路径（包括脚本名）
SCRIPT_PATH="$(realpath "$0")"

YUANWEI_ZHI="$(dirname "$SCRIPT_PATH")"

UBUNTU_ROOT="/data/data/com.termux/files/usr/var/lib/proot-distro/installed-rootfs/ubuntu/root"

FIRST_LOGIN="$HOME/.jack_eason1"
######检查proot-distro######
if command -v "proot-distro" >/dev/null 2>&1; then
    echo "proot-distro 已安装"
else
     pkg install -y proot-distro
fi

while true; do
# 检查目录是否存在
if [ -d "$UBUNTU_ROOT" ]; then
    echo "Ubuntu已经安装"
    break

else
    echo "Ubuntu暂未安装，正在安装"
    proot-distro install ubuntu
fi
done
if [ ! -f "$FIRST_LOGIN" ]; then
touch "$FIRST_LOGIN"  # 创建标记文件
    echo "换源。。。"
    sleep 1
    
    
    
    ########
    Jack_Eason
   #####手动制造错误退出proot并换源#####
   
    
proot-distro login ubuntu -- bash -c 'bash -c "$(curl -L https://gitee.com/jiangnan-qwq/AetherCraft_cn/raw/main/容器换源.sh)"'
else
    echo "欢迎，即将进入"
    sleep 1
    proot-distro login ubuntu -- bash -c 'bash -c "$(curl -L https://gitee.com/jiangnan-qwq/AetherCraft_cn/raw/main/menu.sh)"'
fi
