#!/bin/bash
# AetherCraft - 备份模块
# 作者: B站@爱做视频のJack_Eason
# 版本: 3.4
# 日期: 2025-06-29

# 加载公共库
source <(curl -s https://gitee.com/jiangnan-qwq/AetherCraft_cn/raw/main/common.sh)

# 备份主菜单
backup_menu() {
    while true; do
        choice=$(dialog --menu "备份与恢复" 15 50 5 \
            "1" "备份服务器实例" \
            "2" "恢复服务器实例" \
            "3" "管理备份文件" \
            "4" "设置自动备份" \
            "5" "返回主菜单" 2>&1 >/dev/tty)
            
        case "$choice" in
            1) backup_instance ;;
            2) restore_instance ;;
            3) manage_backups ;;
            4) auto_backup_settings ;;
            5) return 0 ;;
            *) log "无效选项" "WARN";;
        esac
    done
}

# 备份服务器实例
backup_instance() {
    # 获取实例列表
    local instances=($(get_instance_list))
    
    if [ ${#instances[@]} -eq 0 ]; then
        dialog --msgbox "没有可备份的服务器实例" 8 40
        return
    fi
    
    # 生成菜单
    local menu_items=()
    for instance in "${instances[@]}"; do
        menu_items+=("$instance" "")
    done
    
    # 选择要备份的实例
    local selected=$(dialog --menu "选择要备份的实例" 15 60 8 \
        "${menu_items[@]}" 2>&1 >/dev/tty)
    [ -z "$selected" ] && return
    
    # 备份类型选择
    dialog --radiolist "选择备份类型" 10 40 3 \
        1 "完整备份 (所有文件)" on \
        2 "增量备份 (仅世界数据)" off 2>/tmp/backup_type
    local backup_type=$(</tmp/backup_type)
    
    # 压缩选项
    dialog --checklist "备份选项" 10 40 3 \
        "compress" "启用压缩 (推荐)" on \
        "checksum" "生成校验文件" on \
        "pause" "暂停服务器" off 2>/tmp/backup_opts
    local opts=($(</tmp/backup_opts))
    
    # 备份文件名
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local backup_name="${selected}-${timestamp}"
    local backup_path="${BACKUP_DIR}/${backup_name}"
    
    # 创建备份目录
    mkdir -p "${BACKUP_DIR}"
    
    # 开始备份流程
    (
        echo "5"
        echo "# 准备备份环境..."
        
        # 暂停服务器如果选择了该选项
        if [[ "${opts[@]}" =~ "pause" ]] && check_server_status "$selected"; then
            echo "10"
            echo "# 暂停服务器..."
            echo "save-off" > "${VERSIONS_DIR}/${selected}/command_input"
            echo "save-all" > "${VERSIONS_DIR}/${selected}/command_input"
            sleep 5
        fi
        
        # 完整备份
        if [ "$backup_type" -eq 1 ]; then
            echo "20"
            echo "# 正在备份整个实例目录..."
            cp -r "${VERSIONS_DIR}/${selected}" "${backup_path}"
        else
            # 增量备份仅世界数据
            echo "20"
            echo "# 正在备份世界数据..."
            mkdir -p "${backup_path}"
            local worlds=($(find "${VERSIONS_DIR}/${selected}" -maxdepth 1 -type d -name "world*"))
            for world in "${worlds[@]}"; do
                cp -r "$world" "${backup_path}/"
            done
            # 复制重要配置文件
            cp "${VERSIONS_DIR}/${selected}/server.properties" "${backup_path}/" 2>/dev/null
            cp "${VERSIONS_DIR}/${selected}/ops.json" "${backup_path}/" 2>/dev/null
            cp "${VERSIONS_DIR}/${selected}/whitelist.json" "${backup_path}/" 2>/dev/null
        fi
        
        # 压缩处理
        if [[ "${opts[@]}" =~ "compress" ]]; then
            echo "60"
            echo "# 正在压缩备份文件..."
            tar -czf "${backup_path}.tar.gz" -C "${BACKUP_DIR}" "${backup_name}"
            rm -rf "${backup_path}"
            backup_path="${backup_path}.tar.gz"
        fi
        
        # 生成校验文件
        if [[ "${opts[@]}" =~ "checksum" ]]; then
            echo "80"
            echo "# 正在生成校验文件..."
            sha256sum "${backup_path}" > "${backup_path}.sha256"
        fi
        
        # 恢复服务器运行
        if [[ "${opts[@]}" =~ "pause" ]] && check_server_status "$selected"; then
            echo "90"
            echo "# 恢复服务器运行..."
            echo "save-on" > "${VERSIONS_DIR}/${selected}/command_input"
        fi
        
        echo "100"
        echo "# 备份完成!"
    ) | dialog --gauge "正在备份实例 ${selected}" 8 70 0
    
    # 显示备份结果
    local backup_size=$(du -h "${backup_path}" | cut -f1)
    dialog --msgbox "备份成功完成！\n\n备份文件: ${backup_path}\n大小: ${backup_size}" 12 60
}

# 恢复服务器实例
restore_instance() {
    # 获取备份列表
    local backups=($(find "${BACKUP_DIR}" -maxdepth 1 -type f \( -name "*.tar.gz" -o -name "*.zip" -o -name "*.bak" \) -printf "%f\n" | sort -r))
    
    if [ ${#backups[@]} -eq 0 ]; then
        dialog --msgbox "没有找到任何备份文件" 8 40
        return
    fi
    
    # 生成菜单
    local menu_items=()
    for backup in "${backups[@]}"; do
        local size=$(du -h "${BACKUP_DIR}/${backup}" | cut -f1)
        local date=$(stat -c %y "${BACKUP_DIR}/${backup}" | cut -d' ' -f1)
        menu_items+=("$backup" "大小: $size | 日期: $date")
    done
    
    # 选择要恢复的备份
    local selected=$(dialog --menu "选择要恢复的备份" 20 70 12 \
        "${menu_items[@]}" 2>&1 >/dev/tty)
    [ -z "$selected" ] && return
    
    # 验证校验文件
    if [ -f "${BACKUP_DIR}/${selected}.sha256" ]; then
        (
            echo "20"
            echo "# 正在验证备份完整性..."
            pushd "${BACKUP_DIR}" >/dev/null
            if ! sha256sum -c "${selected}.sha256"; then
                dialog --msgbox "备份校验失败，文件可能损坏！" 8 50
                return 1
            fi
            popd >/dev/null
        ) | dialog --gauge "正在验证备份" 8 50 0 || return
    fi
    
    # 确定实例名称
    local instance_name=$(echo "$selected" | sed 's/\.tar\.gz$//;s/\.zip$//;s/\.bak$//' | cut -d'-' -f1-3)
    
    # 检查实例是否已存在
    if [ -d "${VERSIONS_DIR}/${instance_name}" ]; then
        dialog --yesno "实例 ${instance_name} 已存在，是否覆盖？" 8 50 || return
    fi
    
    # 开始恢复流程
    (
        echo "30"
        echo "# 正在停止相关服务器..."
        if check_server_status "$instance_name"; then
            echo "stop" > "${VERSIONS_DIR}/${instance_name}/command_input"
            sleep 5
        fi
        
        echo "50"
        echo "# 正在解压备份文件..."
        mkdir -p "${VERSIONS_DIR}/${instance_name}"
        
        case "$selected" in
            *.tar.gz)
                tar -xzf "${BACKUP_DIR}/${selected}" -C "${VERSIONS_DIR}"
                ;;
            *.zip)
                unzip -q "${BACKUP_DIR}/${selected}" -d "${VERSIONS_DIR}"
                ;;
            *)
                cp -r "${BACKUP_DIR}/${selected}" "${VERSIONS_DIR}/${instance_name}"
                ;;
        esac
        
        echo "80"
        echo "# 修复文件权限..."
        find "${VERSIONS_DIR}/${instance_name}" -type f -name "*.sh" -exec chmod +x {} \;
        
        echo "100"
        echo "# 恢复完成!"
    ) | dialog --gauge "正在恢复实例 ${instance_name}" 8 70 0
    
    dialog --msgbox "实例 ${instance_name} 已成功从备份恢复" 8 50
}

# 管理备份文件
manage_backups() {
    while true; do
        # 获取备份列表
        local backups=($(find "${BACKUP_DIR}" -maxdepth 1 -type f \( -name "*.tar.gz" -o -name "*.zip" -o -name "*.bak" \) -printf "%f\n" | sort -r))
        
        if [ ${#backups[@]} -eq 0 ]; then
            dialog --msgbox "没有找到任何备份文件" 8 40
            return
        fi
        
        # 生成菜单
        local menu_items=()
        for backup in "${backups[@]}"; do
            local size=$(du -h "${BACKUP_DIR}/${backup}" | cut -f1)
            local date=$(stat -c %y "${BACKUP_DIR}/${backup}" | cut -d' ' -f1)
            menu_items+=("$backup" "大小: $size | 日期: $date")
        done
        
        # 添加管理选项
        menu_items+=("cleanup" "清理旧备份")
        menu_items+=("back" "返回")
        
        # 选择备份文件
        local selected=$(dialog --menu "管理备份文件" 20 70 12 \
            "${menu_items[@]}" 2>&1 >/dev/tty)
        [ -z "$selected" ] && return
        
        case "$selected" in
            "cleanup") cleanup_backups ;;
            "back") return ;;
            *) 
                backup_actions "$selected"
                ;;
        esac
    done
}

# 备份文件操作
backup_actions() {
    local backup=$1
    
    while true; do
        local action=$(dialog --menu "备份操作: ${backup}" 15 50 5 \
            "info" "查看备份信息" \
            "restore" "恢复此备份" \
            "delete" "删除此备份" \
            "back" "返回" 2>&1 >/dev/tty)
        
        [ -z "$action" ] && return
        
        case "$action" in
            "info")
                show_backup_info "$backup"
                ;;
            "restore")
                restore_backup "$backup"
                return
                ;;
            "delete")
                delete_backup "$backup"
                return
                ;;
            "back")
                return
                ;;
        esac
    done
}

# 显示备份信息
show_backup_info() {
    local backup=$1
    local info="备份文件: ${backup}\n"
    
    info+="大小: $(du -h "${BACKUP_DIR}/${backup}" | cut -f1)\n"
    info+="修改日期: $(stat -c %y "${BACKUP_DIR}/${backup}")\n"
    
    # 如果是压缩包，尝试获取内容信息
    if [[ "$backup" == *.tar.gz ]]; then
        info+="\n包含文件:\n"
        info+="$(tar -tzf "${BACKUP_DIR}/${backup}" | head -n 10 | sed 's/^/  /')\n"
        if [ $(tar -tzf "${BACKUP_DIR}/${backup}" | wc -l) -gt 10 ]; then
            info+="... (更多文件未显示)\n"
        fi
    fi
    
    # 显示校验信息
    if [ -f "${BACKUP_DIR}/${backup}.sha256" ]; then
        info+="\n校验值: $(cat "${BACKUP_DIR}/${backup}.sha256" | cut -d' ' -f1)\n"
        info+="校验状态: 有效"
    else
        info+="\n校验文件: 未找到"
    fi
    
    dialog --msgbox "$info" 16 70
}

# 恢复特定备份
restore_backup() {
    local backup=$1
    dialog --yesno "确定要恢复备份 ${backup} 吗？" 8 50 || return
    
    # 确定实例名称
    local instance_name=$(echo "$backup" | sed 's/\.tar\.gz$//;s/\.zip$//;s/\.bak$//' | cut -d'-' -f1-3)
    
    # 开始恢复流程
    (
        echo "30"
        echo "# 正在停止相关服务器..."
        if check_server_status "$instance_name"; then
            echo "stop" > "${VERSIONS_DIR}/${instance_name}/command_input"
            sleep 5
        fi
        
        echo "50"
        echo "# 正在解压备份文件..."
        rm -rf "${VERSIONS_DIR}/${instance_name}"
        mkdir -p "${VERSIONS_DIR}/${instance_name}"
        
        case "$backup" in
            *.tar.gz)
                tar -xzf "${BACKUP_DIR}/${backup}" -C "${VERSIONS_DIR}"
                ;;
            *.zip)
                unzip -q "${BACKUP_DIR}/${backup}" -d "${VERSIONS_DIR}"
                ;;
            *)
                cp -r "${BACKUP_DIR}/${backup}" "${VERSIONS_DIR}/${instance_name}"
                ;;
        esac
        
        echo "80"
        echo "# 修复文件权限..."
        find "${VERSIONS_DIR}/${instance_name}" -type f -name "*.sh" -exec chmod +x {} \;
        
        echo "100"
        echo "# 恢复完成!"
    ) | dialog --gauge "正在恢复实例 ${instance_name}" 8 70 0
    
    dialog --msgbox "实例 ${instance_name} 已成功从备份恢复" 8 50
}

# 删除备份文件
delete_backup() {
    local backup=$1
    dialog --yesno "确定要永久删除备份 ${backup} 吗？" 8 50 || return
    
    rm -f "${BACKUP_DIR}/${backup}" "${BACKUP_DIR}/${backup}.sha256" 2>/dev/null
    dialog --msgbox "备份 ${backup} 已删除" 8 40
}

# 清理旧备份
cleanup_backups() {
    dialog --radiolist "选择清理方式" 12 50 5 \
        1 "按时间清理 (保留最近N天)" on \
        2 "按数量清理 (保留最近N个)" off \
        3 "按大小清理 (最大总大小)" off 2>/tmp/cleanup_method
    
    local method=$(</tmp/cleanup_method)
    
    case "$method" in
        1)
            local days=$(dialog --inputbox "输入要保留的天数:" 10 50 "7" 2>&1 >/dev/tty)
            [ -z "$days" ] && return
            
            (
                echo "10"
                echo "# 正在查找旧备份..."
                local old_backups=($(find "${BACKUP_DIR}" -type f -name "*.tar.gz" -mtime +$days -printf "%f\n"))
                
                if [ ${#old_backups[@]} -eq 0 ]; then
                    echo "100"
                    echo "# 没有找到符合条件的备份"
                    sleep 1
                    return
                fi
                
                echo "30"
                echo "# 正在删除旧备份..."
                for backup in "${old_backups[@]}"; do
                    echo "50"
                    echo "# 正在删除 ${backup}..."
                    rm -f "${BACKUP_DIR}/${backup}" "${BACKUP_DIR}/${backup}.sha256"
                done
                
                echo "100"
                echo "# 清理完成!"
            ) | dialog --gauge "正在清理超过${days}天的备份" 8 70 0
            ;;
            
        2)
            local keep=$(dialog --inputbox "输入要保留的备份数量:" 10 50 "5" 2>&1 >/dev/tty)
            [ -z "$keep" ] && return
            
            (
                echo "10"
                echo "# 正在计算备份数量..."
                local all_backups=($(find "${BACKUP_DIR}" -type f -name "*.tar.gz" -printf "%T@ %f\n" | sort -rn | cut -d' ' -f2))
                
                if [ ${#all_backups[@]} -le $keep ]; then
                    echo "100"
                    echo "# 备份数量未超过限制"
                    sleep 1
                    return
                fi
                
                echo "30"
                echo "# 正在删除多余备份..."
                for ((i=keep; i<${#all_backups[@]}; i++)); do
                    echo "50"
                    echo "# 正在删除 ${all_backups[$i]}..."
                    rm -f "${BACKUP_DIR}/${all_backups[$i]}" "${BACKUP_DIR}/${all_backups[$i]}.sha256"
                done
                
                echo "100"
                echo "# 清理完成!"
            ) | dialog --gauge "正在保留最近${keep}个备份" 8 70 0
            ;;
            
        3)
            local max_size=$(dialog --inputbox "输入最大总大小 (如 10G, 500M):" 10 50 "10G" 2>&1 >/dev/tty)
            [ -z "$max_size" ] && return
            
            (
                echo "10"
                echo "# 正在计算当前备份大小..."
                local total_size=$(du -sc "${BACKUP_DIR}"/*.tar.gz | grep total | cut -f1)
                local max_size_bytes=$(numfmt --from=auto "$max_size")
                
                if [ "$total_size" -le "$max_size_bytes" ]; then
                    echo "100"
                    echo "# 备份总大小未超过限制"
                    sleep 1
                    return
                fi
                
                echo "30"
                echo "# 正在查找最旧的备份..."
                local old_backups=($(find "${BACKUP_DIR}" -type f -name "*.tar.gz" -printf "%T@ %f %s\n" | sort -n | cut -d' ' -f2-))
                
                echo "50"
                echo "# 正在清理备份..."
                local freed=0
                for backup in "${old_backups[@]}"; do
                    local backup_name=$(echo "$backup" | cut -d' ' -f1)
                    local backup_size=$(echo "$backup" | cut -d' ' -f2)
                    
                    rm -f "${BACKUP_DIR}/${backup_name}" "${BACKUP_DIR}/${backup_name}.sha256"
                    freed=$((freed + backup_size))
                    
                    echo "70"
                    echo "# 已释放: $(numfmt --to=iec $freed)"
                    
                    if [ "$((total_size - freed))" -lt "$max_size_bytes" ]; then
                        break
                    fi
                done
                
                echo "100"
                echo "# 清理完成!"
            ) | dialog --gauge "正在将备份总大小限制为${max_size}" 8 70 0
            ;;
    esac
}

# 自动备份设置
auto_backup_settings() {
    # 检查是否已配置cron
    local current_cron=$(crontab -l 2>/dev/null | grep "mc-backup")
    
    while true; do
        local status="已禁用"
        if [ -n "$current_cron" ]; then
            status="已启用"
        fi
        
        local choice=$(dialog --menu "自动备份设置 (当前状态: ${status})" 15 50 5 \
            "enable" "启用自动备份" \
            "disable" "禁用自动备份" \
            "config" "配置备份计划" \
            "back" "返回" 2>&1 >/dev/tty)
        
        [ -z "$choice" ] && return
        
        case "$choice" in
            "enable")
                enable_auto_backup
                current_cron=$(crontab -l 2>/dev/null | grep "mc-backup")
                ;;
                
            "disable")
                disable_auto_backup
                current_cron=""
                ;;
                
            "config")
                config_backup_schedule
                current_cron=$(crontab -l 2>/dev/null | grep "mc-backup")
                ;;
                
            "back")
                return
                ;;
        esac
    done
}

# 启用自动备份
enable_auto_backup() {
    if [ ! -f "${ROOT_DIR}/backup.cfg" ]; then
        cat > "${ROOT_DIR}/backup.cfg" <<EOF
# 自动备份配置
BACKUP_HOUR=3
BACKUP_MINUTE=0
BACKUP_DAYS="*"
BACKUP_TYPE="full"
EOF
    fi
    
    # 添加cron任务
    (
        crontab -l 2>/dev/null | grep -v "mc-backup"
        echo "0 3 * * * /bin/bash ${ROOT_DIR}/AetherCraft/lib/backup.sh --auto"
    ) | crontab -
    
    dialog --msgbox "已启用每日3:00的自动备份" 8 50
}

# 禁用自动备份
disable_auto_backup() {
    (
        crontab -l 2>/dev/null | grep -v "mc-backup"
    ) | crontab -
    
    dialog --msgbox "已禁用自动备份" 8 40
}

# 配置备份计划
config_backup_schedule() {
    # 读取当前配置
    if [ -f "${ROOT_DIR}/backup.cfg" ]; then
        source "${ROOT_DIR}/backup.cfg"
    else
        BACKUP_HOUR=3
        BACKUP_MINUTE=0
        BACKUP_DAYS="*"
        BACKUP_TYPE="full"
    fi
    
    # 时间选择
    local hour=$(dialog --inputbox "输入备份小时 (0-23):" 10 50 "$BACKUP_HOUR" 2>&1 >/dev/tty)
    [[ "$hour" =~ ^[0-9]+$ ]] && [ "$hour" -ge 0 ] && [ "$hour" -le 23 ] || {
        dialog --msgbox "无效的小时数！" 8 40
        return
    }
    
    local minute=$(dialog --inputbox "输入备份分钟 (0-59):" 10 50 "$BACKUP_MINUTE" 2>&1 >/dev/tty)
    [[ "$minute" =~ ^[0-9]+$ ]] && [ "$minute" -ge 0 ] && [ "$minute" -le 59 ] || {
        dialog --msgbox "无效的分钟数！" 8 40
        return
    }
    
    # 日期选择
    local days=$(dialog --inputbox "输入备份日期 (1-31 或 * 表示每天):" 10 50 "$BACKUP_DAYS" 2>&1 >/dev/tty)
    [[ "$days" =~ ^([1-9]|[12][0-9]|3[01]|\*)(,([1-9]|[12][0-9]|3[01]|\*))*$ ]] || {
        dialog --msgbox "无效的日期格式！" 8 40
        return
    }
    
    # 备份类型
    dialog --radiolist "选择备份类型" 10 40 3 \
        "full" "完整备份" $( [ "$BACKUP_TYPE" = "full" ] && echo on || echo off ) \
        "incremental" "增量备份" $( [ "$BACKUP_TYPE" = "incremental" ] && echo on || echo off ) 2>/tmp/backup_type
    local type=$(</tmp/backup_type)
    
    # 保存配置
    cat > "${ROOT_DIR}/backup.cfg" <<EOF
# 自动备份配置
BACKUP_HOUR=$hour
BACKUP_MINUTE=$minute
BACKUP_DAYS="$days"
BACKUP_TYPE="$type"
EOF
    
    # 更新cron任务
    (
        crontab -l 2>/dev/null | grep -v "mc-backup"
        echo "$minute $hour $days * * /bin/bash ${ROOT_DIR}/AetherCraft/lib/backup.sh --auto"
    ) | crontab -
    
    dialog --msgbox "自动备份计划已更新\n\n时间: 每天 $hour:$minute\n类型: $type" 10 50
}

# 自动备份执行
auto_backup() {
    # 读取配置
    if [ ! -f "${ROOT_DIR}/backup.cfg" ]; then
        log "自动备份失败: 未找到配置文件" "ERROR"
        return 1
    fi
    
    source "${ROOT_DIR}/backup.cfg"
    
    # 获取实例列表
    local instances=($(get_instance_list))
    
    if [ ${#instances[@]} -eq 0 ]; then
        log "自动备份: 没有可备份的实例" "WARN"
        return 0
    fi
    
    # 备份每个实例
    for instance in "${instances[@]}"; do
        local timestamp=$(date +%Y%m%d-%H%M%S)
        local backup_name="${instance}-auto-${timestamp}"
        local backup_path="${BACKUP_DIR}/${backup_name}"
        
        log "开始自动备份实例: ${instance}" "INFO"
        
        # 暂停服务器
        if check_server_status "$instance"; then
            echo "save-off" > "${VERSIONS_DIR}/${instance}/command_input"
            echo "save-all" > "${VERSIONS_DIR}/${instance}/command_input"
            sleep 5
        fi
        
        # 执行备份
        if [ "$BACKUP_TYPE" = "full" ]; then
            tar -czf "${backup_path}.tar.gz" -C "${VERSIONS_DIR}" "${instance}"
        else
            # 增量备份仅世界数据
            mkdir -p "${backup_path}"
            local worlds=($(find "${VERSIONS_DIR}/${instance}" -maxdepth 1 -type d -name "world*"))
            for world in "${worlds[@]}"; do
                cp -r "$world" "${backup_path}/"
            done
            # 复制重要配置文件
            cp "${VERSIONS_DIR}/${instance}/server.properties" "${backup_path}/" 2>/dev/null
            cp "${VERSIONS_DIR}/${instance}/ops.json" "${backup_path}/" 2>/dev/null
            cp "${VERSIONS_DIR}/${instance}/whitelist.json" "${backup_path}/" 2>/dev/null
            # 打包
 tar -czf "${backup_path.tar.gz}" -C "${BACKUP_DIR}" "${backup_name}"
rm -rf "${backup_path}"
fi

    # 生成校验文件
    sha256sum "${backup_path}.tar.gz" > "${backup_path}.tar.gz.sha256"
    
    # 恢复服务器
    if check_server_status "$instance"; then
        echo "save-on" > "${VERSIONS_DIR}/${instance}/command_input"
    fi
    
    log "实例 ${instance} 自动备份完成: ${backup_path}.tar.gz" "INFO"
done

# 清理旧备份
find "${BACKUP_DIR}" -name "*-auto-*.tar.gz" -mtime +7 -exec rm -f {} \;
find "${BACKUP_DIR}" -name "*-auto-*.sha256" -mtime +7 -exec rm -f {} \;

log "自动备份任务完成" "SUCCESS"

}

#获取实例列表

get_instance_list() {
local instances=()
while IFS= read -r -d  '\0' dir; do
instances+=(" (basename " dir")")
done < <(find " VERSIONS_DIR" -maxdepth 1 -type d -name "*" -print0)
echo "${instances[@]}"
}

#检查服务器运行状态

check_server_status() {
local instance="$1"

if pgrep -f "java -jar ${VERSIONS_DIR}/${instance}/server.jar" >/dev/null; then
    return 0  # 运行中
else
    return 1  # 已停止
fi
}

#主入口

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
   if [ "$1" = "--auto" ]; then
     auto_backup
   else
     backup_menu
   fi
fi


