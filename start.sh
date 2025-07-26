#!/bin/bash
# AetherCraft - 启动模块
# 作者: B站@爱做视频のJack_Eason
# 版本: 3.4
# 日期: 2025-06-29

# 加载公共库
source <(curl -s https://gitee.com/jiangnan-qwq/AetherCraft_cn/raw/main/common.sh)

# 启动菜单
start_menu() {
    while true; do
        # 获取实例列表
        local instances=($(get_instance_list))
        
        if [ ${#instances[@]} -eq 0 ]; then
            dialog --msgbox "未找到任何服务器实例，请先安装！" 10 50
            return 1
        fi

        # 生成菜单项并显示状态
        local menu_items=()
        for instance in "${instances[@]}"; do
            local status="已停止"
            
            local version="未知"
            
            if check_server_status "$instance"; then
                status="运行中"
                
            fi
            
            # 获取版本信息
            local instance_dir="${VERSIONS_DIR}/${instance}"
            if [ -f "${instance_dir}/instance.cfg" ]; then
                source "${instance_dir}/instance.cfg"
                version="$mc_version"
            fi
            
            menu_items+=("$instance" "${status} | 版本: $version")
        done

        local choice=$(dialog --menu "选择要启动的实例" 20 70 15 \
            "${menu_items[@]}" 2>&1 >/dev/tty)
        
        [ -z "$choice" ] && return

        instance_control "$choice"
    done
}

# 实例控制
instance_control() {
    local instance=$1
    local instance_dir="${VERSIONS_DIR}/${instance}"
    
    if [ ! -d "$instance_dir" ]; then
        dialog --msgbox "实例目录不存在: ${instance_dir}" 10 50
        return 1
    fi

    # 检查状态
    local is_running=0
    check_server_status "$instance" && is_running=1

    # 操作菜单
    local options=()
    if [ $is_running -eq 1 ]; then
        options+=("stop" "停止服务器")
        options+=("restart" "重启服务器")
        options+=("console" "查看控制台")
        options+=("command" "发送命令")
    else
        options+=("start" "启动服务器")
    fi
    options+=("edit" "编辑配置")
    options+=("back" "返回上级菜单")

    while true; do
        local action=$(dialog --menu "实例操作: ${instance}" 15 60 8 \
            "${options[@]}" 2>&1 >/dev/tty)
        
        [ -z "$action" ] && return

        case "$action" in
            "start") start_instance "$instance" ;;
            "stop") stop_instance "$instance" ;;
            "restart") restart_instance "$instance" ;;
            "console") show_console "$instance" ;;
            "command") send_command "$instance" ;;
            "edit") edit_configs "$instance" ;;
            "back") return ;;
        esac
    done
}

# 启动服务器实例
start_instance() {
        # 验证实例目录
if [ ! -f "${instance_dir}/server.jar" ]; then
            
  if [[ "$instance" == *"Bedrock"* ]]; then
        if [ ! -f "${instance_dir}/bedrock_server" ]; then
            dialog --msgbox "bedrock_server 文件缺失！" 10 50
            return 1
        fi
        else
        if [[ "$instance" == *"Forge"* ]]; then
        if [ ! -f "${instance_dir}/run.sh" ]; then
            dialog --msgbox "run.sh 文件缺失！" 10 50
            return 1
        fi
        else
            dialog --msgbox "server.jar 文件缺失！" 10 50
            return 1
            fi
        fi
        fi

    # 检查是否已运行
    if check_server_status "$instance"; then
        dialog --msgbox "服务器已在运行中！" 8 40
        return 0
    fi

    # 检查端口占用
    local port=$(get_server_port "$instance")
    if ! check_port_available "$port"; then
        dialog --msgbox "端口 ${port} 已被占用！" 8 40
        return 1
    fi

    # 前台启动服务器
    (
        cd "${instance_dir}" || exit 1
        
        # 启动前提示
        dialog --msgbox "即将启动服务器 ${instance}\n\n输入'stop'停止服务器" 12 50
        
        # 启动服务器
        clear
        echo -e "${GREEN}=== 服务器控制台 (直接输入命令) ===${NC}"
        
        # Bedrock服务器特殊处理
        if [[ "$instance" == *"Bedrock"* ]]; then
            ./bedrock_server
        else
                  # forge服务器特殊处理
        if [[ "$instance" == *"Forge"* ]]; then
        bash run.sh
        else
            bash start.sh
        fi
        fi
        

        
        # 检查启动结果
        if [ $? -ne 0 ]; then
            dialog --msgbox "服务器启动失败！请检查日志" 10 50
            return 1
        fi
    )

    return 0
}

# 停止服务器实例
stop_instance() {
    local instance=$1
    
    if ! check_server_status "$instance"; then
        dialog --msgbox "服务器未在运行！" 8 40
        return 0
    fi

    # Bedrock服务器特殊处理
    if [[ "$instance" == *"Bedrock"* ]]; then
        pkill -f "bedrock_server"
        sleep 3
        if check_server_status "$instance"; then
            dialog --msgbox "无法停止Bedrock服务器！" 8 40
            return 1
        else
            dialog --msgbox "Bedrock服务器已停止" 8 40
            return 0
        fi
    fi

    # 发送停止命令
    (
        echo "stop" > "${VERSIONS_DIR}/${instance}/command_input"
        sleep 5
        
        # 检查是否停止成功
        if check_server_status "$instance"; then
            # 强制终止
            pkill -f "java -jar ${VERSIONS_DIR}/${instance}/server.jar"
        fi
    ) | dialog --gauge "正在停止服务器..." 8 50 0

    if check_server_status "$instance"; then
        dialog --msgbox "服务器停止失败！" 8 40
        return 1
    else
        dialog --msgbox "服务器已停止" 8 40
        return 0
    fi
}

# 重启服务器实例
restart_instance() {
    local instance=$1
    
    if check_server_status "$instance"; then
        stop_instance "$instance" || return 1
    fi
    
    start_instance "$instance"
}

# 显示控制台
show_console() {
    local instance=$1
    
    if ! check_server_status "$instance"; then
        dialog --msgbox "服务器未在运行！" 8 40
        return 1
    fi
    
    # 直接显示控制台输出
    clear
    echo -e "${GREEN}=== 服务器控制台 (输入Ctrl+C返回) ===${NC}"
    
    # Bedrock服务器特殊处理
    if [[ "$instance" == *"Bedrock"* ]]; then
        tail -f "${VERSIONS_DIR}/${instance}/logs/*.log"
    else
        tail -f "${VERSIONS_DIR}/${instance}/logs/latest.log"
    fi
}

# 发送命令到服务器
send_command() {
    local instance=$1
    
    if ! check_server_status "$instance"; then
        dialog --msgbox "服务器未在运行！" 8 40
        return 1
    fi
    
    # Bedrock服务器不支持命令输入
    if [[ "$instance" == *"Bedrock"* ]]; then
        dialog --msgbox "Bedrock服务器不支持通过此方式发送命令" 8 50
        return 1
    fi
    
    local command=$(dialog --inputbox "输入要发送的命令:" 10 50 2>&1 >/dev/tty)
    [ -z "$command" ] && return
    
    echo "$command" > "${VERSIONS_DIR}/${instance}/command_input"
    dialog --msgbox "命令已发送: ${command}" 8 40
}

# 编辑实例配置
edit_configs() {
    local instance=$1
    local instance_dir="${VERSIONS_DIR}/${instance}"
    
    # 配置文件列表
    local config_files=()
    
    # 根据服务器类型添加特定配置文件
    if [[ "$instance" == *"Bedrock"* ]]; then
        config_files=("server.properties")
    else
        config_files=("server.properties" "spigot.yml" "bukkit.yml" "start.sh" "instance.cfg")
        if [[ "$instance" == *"Fabric"* ]]; then
            config_files+=("fabric-server-launcher.properties")
        elif [[ "$instance" == *"Forge"* ]]; then
            config_files+=("forge-installer.jar.log")
        fi
    fi
    
    # 生成可编辑文件列表
    local editable_files=()
    for file in "${config_files[@]}"; do
        [ -f "${instance_dir}/${file}" ] && editable_files+=("$file" "")
    done
    
    [ ${#editable_files[@]} -eq 0 ] && {
        dialog --msgbox "没有找到可编辑的配置文件" 8 40
        return
    }
    
    local selected_file=$(dialog --menu "选择要编辑的文件" 15 50 8 \
        "${editable_files[@]}" 2>&1 >/dev/tty)
    [ -z "$selected_file" ] && return
    
    # 使用dialog的编辑框
    dialog --title "编辑 ${selected_file}" \
        --editbox "${instance_dir}/${selected_file}" 25 80 2> "${TEMP_DIR}/temp_edit"
    
    if [ $? -eq 0 ]; then
        cp "${TEMP_DIR}/temp_edit" "${instance_dir}/${selected_file}"
        dialog --msgbox "配置文件已更新" 8 40
    fi
    
    rm -f "${TEMP_DIR}/temp_edit"
}

# 获取实例版本
get_instance_version() {
    local instance=$1
    local instance_dir="${VERSIONS_DIR}/${instance}"
    
    if [ -f "${instance_dir}/instance.cfg" ]; then
        source "${instance_dir}/instance.cfg"
        echo "$mc_version"
    else
        echo "未知"
    fi
}

# 获取服务器端口
get_server_port() {
    local instance=$1
    local instance_dir="${VERSIONS_DIR}/${instance}"
    
    if [[ "$instance" == *"Bedrock"* ]]; then
        if [ -f "${instance_dir}/server.properties" ]; then
            grep "^server-port=" "${instance_dir}/server.properties" | cut -d= -f2
        else
            echo "19132"
        fi
    else
        if [ -f "${instance_dir}/server.properties" ]; then
            grep "^server-port=" "${instance_dir}/server.properties" | cut -d= -f2
        else
            echo "25565"
        fi
    fi
}

# 检查端口是否可用
check_port_available() {
    local port=$1
    ! (ss -tuln | grep -q ":${port} ")
}

# 检查服务器运行状态
check_server_status() {
    local instance=$1
    
    # Bedrock服务器检查
    if [[ "$instance" == *"Bedrock"* ]]; then
        if pgrep -f "bedrock_server" >/dev/null; then
            return 0
        else
            return 1
        fi
    fi
    
    # Java服务器检查
    if pgrep -f "java -jar ${VERSIONS_DIR}/${instance}/server.jar" >/dev/null; then
        return 0
    else
        return 1
    fi
}

# 获取实例列表
get_instance_list() {
    local instances=()
    while IFS= read -r -d $'\0' dir; do
        instances+=("$(basename "$dir")")
    done < <(find "$VERSIONS_DIR" -maxdepth 1 -type d -name "*" -print0)
    echo "${instances[@]}"
}

# 主入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    start_menu
fi
