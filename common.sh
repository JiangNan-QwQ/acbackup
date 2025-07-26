#!/bin/bash
# AetherCraft - 公共库
# 作者: B站@爱做视频のJack_Eason
# 版本: 3.4
# 日期: 2025-06-29

# 确保使用UTF-8编码
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export NCURSES_NO_UTF8_ACS=1

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # 无颜色

# 加粗颜色
BOLD='\033[1m'
RED_BOLD='\033[1;31m'
GREEN_BOLD='\033[1;32m'
YELLOW_BOLD='\033[1;33m'

# 全局变量
ROOT_DIR="/root"
VERSIONS_DIR="${ROOT_DIR}/versions"
BACKUP_DIR="${ROOT_DIR}/backups"
TEMP_DIR="${ROOT_DIR}/temp"
LOG_DIR="${ROOT_DIR}/logs"

# 系统信息
OS_INFO=$(grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"' || cat /etc/redhat-release 2>/dev/null || echo "未知系统")
KERNEL_INFO=$(uname -r)
ARCH=$(uname -m)

# Java要求版本
JAVA_REQUIRED=21
MIN_RAM=2048  # 最小内存要求(MB)
RECOMMEND_RAM=4096 # 推荐内存(MB)

# 必需依赖
REQUIRED_DEPS=("curl" "jq" "lolcat" "figlet" "dialog" "wget" "tar" "unzip" "screen" "rsync" "python")
INSTALL_CMD="apt-get install -y"

# 检查并安装依赖
check_deps() {
    local missing_deps=()
    
    echo -e "${BLUE}正在检查系统依赖...${NC}"
    
    # 检测包管理器
    if command -v apt-get &> /dev/null; then
        INSTALL_CMD="apt-get install -y"
    elif command -v yum &> /dev/null; then
        INSTALL_CMD="yum install -y"
    elif command -v dnf &> /dev/null; then
        INSTALL_CMD="dnf install -y"
    elif command -v pacman &> /dev/null; then
        INSTALL_CMD="pacman -S --noconfirm"
    else
        echo -e "${RED}错误：不支持的包管理器！${NC}"
        return 1
    fi

    # 检查每个依赖
    for dep in "${REQUIRED_DEPS[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done

    # 安装缺失的依赖
    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo -e "${YELLOW}缺少依赖: ${missing_deps[*]}${NC}"
        echo -e "${GREEN}正在尝试自动安装...${NC}"
        
        if ! $INSTALL_CMD "${missing_deps[@]}"; then
            echo -e "${RED}依赖安装失败！请手动执行:${NC}"
            echo -e "$INSTALL_CMD ${missing_deps[*]}"
            return 1
        fi
        echo -e "${GREEN}所有依赖已成功安装！${NC}"
    else
        echo -e "${GREEN}所有必需依赖已安装。${NC}"
    fi
    
    # 检查是否安装lolcat和figlet
    if ! command -v lolcat &> /dev/null || ! command -v figlet &> /dev/null; then
        echo -e "${YELLOW}建议安装lolcat和figlet以获得更好的显示效果${NC}"
    fi
    
    return 0
}

# 检查Java版本
check_java() {
    echo -e "${BLUE}正在检查Java环境...${NC}"
    
    # Bedrock服务器不需要Java
    if [[ "$1" == *"Bedrock"* ]]; then
        echo -e "${GREEN}Bedrock服务器不需要Java${NC}"
        return 0
    fi

    if ! command -v java &> /dev/null; then
        echo -e "${YELLOW}Java未安装，正在自动安装Java ${JAVA_REQUIRED}...${NC}"
        install_java_21
        return $?
    fi

    local java_version
    java_version=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}' | cut -d. -f1)
    
    if [ -z "$java_version" ]; then
        echo -e "${YELLOW}无法确定Java版本，将重新安装Java ${JAVA_REQUIRED}...${NC}"
        install_java_21
        return $?
    fi

    if [ "$java_version" -lt "$JAVA_REQUIRED" ]; then
        echo -e "${YELLOW}当前Java版本(${java_version})低于要求(${JAVA_REQUIRED})，正在升级...${NC}"
        install_java_21
    elif [ "$java_version" -eq "$JAVA_REQUIRED" ]; then
        echo -e "${GREEN}Java ${JAVA_REQUIRED} 已安装。${NC}"
    else
        echo -e "${YELLOW}当前Java版本(${java_version})高于要求(${JAVA_REQUIRED})，建议使用Java ${JAVA_REQUIRED}${NC}"
        if ! dialog --yesno "检测到Java ${java_version}，是否仍要安装Java ${JAVA_REQUIRED}？" 8 50; then
            return 0
        fi
        install_java_21
    fi
    
    return 0
}

# 安装Java 21
install_java_21() {
    echo -e "${BLUE}开始安装Java ${JAVA_REQUIRED}...${NC}"
    
    # 根据系统使用不同的安装方法
    if command -v apt-get &> /dev/null; then
        if ! apt-get update; then
            echo -e "${RED}更新软件源失败！${NC}"
            return 1
        fi
        
        if ! apt-get install -y openjdk-21-jdk; then
            echo -e "${RED}Java ${JAVA_REQUIRED} 安装失败！${NC}"
            echo -e "请尝试手动安装:"
            echo -e "apt-get update && apt-get install -y openjdk-21-jdk"
            return 1
        fi
    elif command -v yum &> /dev/null; then
        yum install -y java-21-openjdk-devel || {
            echo -e "${RED}Java ${JAVA_REQUIRED} 安装失败！${NC}"
            return 1
        }
    else
        echo -e "${RED}不支持的包管理器！请手动安装Java ${JAVA_REQUIRED}${NC}"
        return 1
    fi
    
    echo -e "${GREEN}Java ${JAVA_REQUIRED} 安装成功！${NC}"
    return 0
}

# 检查系统资源
check_resources() {
    local total_ram=$(free -m | awk '/Mem:/ {print $2}')
    local free_ram=$(free -m | awk '/Mem:/ {print $4}')
    local total_disk=$(df -h --output=size / | tail -n1 | tr -d ' ')
    local free_disk=$(df -h --output=avail / | tail -n1 | tr -d ' ')
    local cpu_cores=$(nproc)
    
    echo -e "\n${CYAN}=== 系统资源检查 ===${NC}"
    echo -e "操作系统: ${OS_INFO}"
    echo -e "内核版本: ${KERNEL_INFO}"
    echo -e "CPU核心: ${cpu_cores} 核"
    echo -e "总内存: ${total_ram}MB"
    echo -e "可用内存: ${free_ram}MB"
    echo -e "磁盘空间: ${total_disk} (可用 ${free_disk})"
    
    # 内存检查
    if [ "$total_ram" -lt "$MIN_RAM" ]; then
        echo -e "\n${RED_BOLD}警告: 系统内存不足!${NC}"
        echo -e "Minecraft服务器至少需要 ${MIN_RAM}MB 内存"
        echo -e "推荐配置: ${RECOMMEND_RAM}MB 或更高"
        if ! dialog --yesno "系统内存可能不足，是否继续？" 8 50; then
            return 1
        fi
    fi
    
    # 磁盘检查
    local disk_check=$(df -P / | tail -1 | awk '{print $4}')
    if [ "$disk_check" -lt 5242880 ]; then  # 小于5GB
        echo -e "\n${RED_BOLD}警告: 磁盘空间不足!${NC}"
        echo -e "建议至少有5GB可用空间"
        if ! dialog --yesno "磁盘空间可能不足，是否继续？" 8 50; then
            return 1
        fi
    fi
    
    return 0
}

show_banner() {
    clear
    if command -v figlet &> /dev/null && command -v lolcat &> /dev/null; then
        figlet "Aether" | lolcat && figlet "Craft" | lolcat
    else
        echo -e "${GREEN_BOLD}=== Aether Craft ===${NC}"
    fi
    echo -e "版本: 3.4 | 作者: B站@爱做视频のJack_Eason"
    echo -e "系统: ${OS_INFO} | 内核: ${KERNEL_INFO}"
    echo -e "===================================="
    sleep 3
}

# 创建目录结构
init_directories() {
    mkdir -p "$VERSIONS_DIR" "$BACKUP_DIR" "$TEMP_DIR" "$LOG_DIR"
    
    # 设置权限
    chmod 755 "$ROOT_DIR" "$VERSIONS_DIR" "$BACKUP_DIR"
    chmod 700 "$TEMP_DIR"
    
    # 创建日志文件
    local log_file="${LOG_DIR}/AetherCraft_$(date +%Y%m%d).log"
    touch "$log_file"
    chmod 644 "$log_file"
}

# 日志记录函数
log() {
    local message="$1"
    local level="${2:-INFO}"
    local timestamp=$(date +"%Y-%m-%d %T")
    local log_file="${LOG_DIR}/AetherCraft_$(date +%Y%m%d).log"
    
    echo -e "[${timestamp}] [${level}] ${message}" >> "$log_file"
    
    case "$level" in
        "ERROR") echo -e "${RED}[${level}]${NC} ${message}" ;;
        "WARN") echo -e "${YELLOW}[${level}]${NC} ${message}" ;;
        "SUCCESS") echo -e "${GREEN}[${level}]${NC} ${message}" ;;
        *) echo -e "[${level}] ${message}" ;;
    esac
}

# 错误处理函数
error_exit() {
    local message="$1"
    local exit_code="${2:-1}"
    
    log "错误: ${message}" "ERROR"
    log "脚本终止，退出码: ${exit_code}" "ERROR"
    
    # 清理临时目录
    if [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"/*
    fi
    
    exit "$exit_code"
}

# 确认对话框
confirm_action() {
    local message="$1"
    dialog --yesno "$message" 8 50
    return $?
}

# 进度条显示
show_progress() {
    local title="$1"
    local total="$2"
    local current="$3"
    local message="$4"
    
    local percentage=$((current * 100 / total))
    echo "XXX"
    echo "$percentage"
    echo "$message"
    echo "XXX"
}

# 检查服务器运行状态
check_server_status() {
    local instance="$1"
    
    # Bedrock服务器检查
    if [[ "$instance" == *"Bedrock"* ]]; then
        if pgrep -f "bedrock_server" >/dev/null; then
            return 0  # 运行中
        else
            return 1  # 已停止
        fi
    fi
    
    # Java服务器检查
    if pgrep -f "java -jar ${VERSIONS_DIR}/${instance}/server.jar" >/dev/null; then
        return 0  # 运行中
    else
        return 1  # 已停止
    fi
}

# 获取实例列表
get_instance_list() {
    # 确保变量已加载
    [ -z "${VERSIONS_DIR:-}" ] && VERSIONS_DIR="/root/versions"
    
    # 检查目录是否存在
    if [ ! -d "$VERSIONS_DIR" ]; then
        log "错误: 目录 $VERSIONS_DIR 不存在" "ERROR"
        return 1
    fi

    local instances=()
    while IFS= read -r -d $'\0' dir; do
        instances+=("$(basename "$dir")")
    done < <(find "$VERSIONS_DIR" -maxdepth 1 -type d -name "*" -print0 2>/dev/null)

    echo "${instances[@]}"
}

# 验证版本号格式
validate_version() {
    local version="$1"
    [[ "$version" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]]
}

# 清理临时文件
cleanup_temp() {
    if [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"/*
        log "已清理临时文件" "INFO"
    fi
}

# 脚本退出时的清理
trap cleanup_temp EXIT

# 检查端口是否可用
check_port_available() {
    local port=$1
    ! (ss -tuln | grep -q ":${port} ")
}

# 获取服务器端口
get_server_port() {
    local instance="$1"
    local instance_dir="${VERSIONS_DIR}/${instance}"
    
    # Bedrock服务器默认端口
    if [[ "$instance" == *"Bedrock"* ]]; then
        if [ -f "${instance_dir}/server.properties" ]; then
            grep "^server-port=" "${instance_dir}/server.properties" | cut -d= -f2 || echo "19132"
        else
            echo "19132"
        fi
    else
        # Java服务器默认端口
        if [ -f "${instance_dir}/server.properties" ]; then
            grep "^server-port=" "${instance_dir}/server.properties" | cut -d= -f2 || echo "25565"
        else
            echo "25565"
        fi
    fi
}

# 获取实例版本
get_instance_version() {
    local instance=$1
    local instance_dir="${VERSIONS_DIR}/${instance}"
    
    if [ -f "${instance_dir}/instance.cfg" ]; then
        grep "^mc_version=" "${instance_dir}/instance.cfg" | cut -d= -f2
    else
        echo "未知"
    fi
}


# 停止服务器实例
stop_instance() {
    local instance="$1"
    local instance_dir="${VERSIONS_DIR}/${instance}"
    
    # Bedrock服务器特殊处理
    if [[ "$instance" == *"Bedrock"* ]]; then
        pkill -f "bedrock_server"
        sleep 3
        if pgrep -f "bedrock_server"; then
            return 1
        else
            return 0
        fi
    fi
    
    # Java服务器处理
    if ! check_server_status "$instance"; then
        return 0
    fi
    
    # 发送停止命令
    echo "stop" > "${instance_dir}/command_input"
    
    # 等待最多10秒
    local timeout=10
    while [ $timeout -gt 0 ]; do
        if ! check_server_status "$instance"; then
            return 0
        fi
        sleep 1
        ((timeout--))
    done
    
    # 如果仍然运行，强制终止
    if check_server_status "$instance"; then
        pkill -f "java -jar ${instance_dir}/server.jar"
        sleep 2
        if check_server_status "$instance"; then
            return 1
        fi
    fi
    
    return 0
}

# 重启服务器实例
restart_instance() {
    local instance="$1"
    
    if check_server_status "$instance"; then
        stop_instance "$instance" || return 1
    fi
    
    # 启动服务器
    (
        cd "${VERSIONS_DIR}/${instance}" || exit 1
        
        # Bedrock服务器特殊处理
        if [[ "$instance" == *"Bedrock"* ]]; then
            nohup ./bedrock_server &
        else
            bash start.sh
        fi
    )
    
    return $?
}
