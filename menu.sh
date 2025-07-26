#!/bin/bash
# 主入口脚本

# 加载公共库
source <(curl -s https://gitee.com/jiangnan-qwq/AetherCraft_cn/raw/main/common.sh)

# 检查依赖
check_deps
check_java

# 卸载整个管理系统
uninstall_system() {
    dialog --yesno "确定要完全卸载Aether Craft管理系统吗？\n\n这将删除所有服务器实例、备份和配置文件！" 12 50 || return
    
    # 停止所有运行中的实例
    local instances=($(get_instance_list))
    for instance in "${instances[@]}"; do
        if check_server_status "$instance"; then
            stop_instance "$instance"
        fi
    done
    
    # 删除所有文件和目录
    (
        echo "20"
        echo "# 删除服务器实例..."
        rm -rf "$VERSIONS_DIR"
        
        echo "40"
        echo "# 删除备份文件..."
        rm -rf "$BACKUP_DIR"
        
        echo "60"
        echo "# 删除临时文件..."
        rm -rf "$TEMP_DIR"
        
        echo "80"
        echo "# 删除日志文件..."
        rm -rf "$LOG_DIR"
        
        echo "100"
        echo "# 卸载完成!"
    ) | dialog --gauge "正在卸载Aether Craft管理系统" 8 70 0
    
    dialog --msgbox "Aether Craft管理系统已完全卸载" 8 40
    exit 0
}

# 主菜单
main_menu() {
    while true; do
        choice=$(dialog --menu "Aether Craft 服务器管理脚本" 15 50 5 \
            "1" "安装/卸载服务器" \
            "2" "启动服务器" \
            "3" "配置服务器" \
            "4" "备份/恢复" \
            "5" "插件管理" \
            "6" "卸载整个管理系统" \
            "7" "退出" 2>&1 >/dev/tty)
            
        case "$choice" in
            1) source <(curl -s https://gitee.com/jiangnan-qwq/AetherCraft_cn/raw/main/install.sh); install_menu ;;
            2) source <(curl -s https://gitee.com/jiangnan-qwq/AetherCraft_cn/raw/main/start.sh); start_menu ;;
            3) source <(curl -s https://gitee.com/jiangnan-qwq/AetherCraft_cn/raw/main/config.sh); config_menu ;;
            4) source <(curl -s https://gitee.com/jiangnan-qwq/AetherCraft_cn/raw/main/backup.sh); backup_menu ;;
            5) pip install requests pyyaml pythondialog || error_exit "Python 依赖安装失败" $?
   python <(curl -s https://gitee.com/jiangnan-qwq/AetherCraft_cn/raw/main/plugins.py) ;;
            6) uninstall_system ;;
            7) exit 0 ;;
            *) echo "无效选项";;
        esac
    done
}

# 初始化
clear
echo "$(curl -L https://gitee.com/jiangnan-qwq/AetherCraft_cn/raw/main/公告.txt)"
sleep 1.5
clear
show_banner
init_directories
check_resources || error_exit "系统资源检查失败" 1
check_deps || error_exit "依赖检查失败" 1
check_java || error_exit "Java安装失败" 1
sleep 3
log "公共库初始化完成" "INFO"
main_menu
