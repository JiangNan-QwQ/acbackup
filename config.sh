#!/bin/bash
# AetherCraft - 配置模块
# 作者: B站@爱做视频のJack_Eason
# 版本: 3.4
# 日期: 2025-06-29

# 加载公共库
source <(curl -s https://gitee.com/jiangnan-qwq/AetherCraft_cn/raw/main/common.sh)

# 配置主菜单
config_menu() {
    while true; do
        # 获取实例列表
        local instances=($(get_instance_list))
        
        if [ ${#instances[@]} -eq 0 ]; then
            dialog --msgbox "未找到任何服务器实例，请先安装！" 10 50
            return 1
        fi

        # 生成菜单项
        local menu_items=()
        for instance in "${instances[@]}"; do
            local version=$(get_instance_version "$instance")
            local port=$(get_server_port "$instance")
            menu_items+=("$instance" "版本: $version | 端口: $port")
        done

        local choice=$(dialog --menu "选择要配置的实例" 20 70 15 \
            "${menu_items[@]}" 2>&1 >/dev/tty)
        
        [ -z "$choice" ] && return

        instance_config "$choice"
    done
}

# 实例配置
instance_config() {
    local instance=$1
    local instance_dir="${VERSIONS_DIR}/${instance}"
    local core_type=$(echo "$instance" | cut -d- -f1)
    
    while true; do
        # 获取当前配置
        local server_port=$(get_server_port "$instance")
        
        # 操作菜单
        local action=$(dialog --menu "配置实例: ${instance}" 22 70 12 \
            "basic" "基本服务器设置" \
            "network" "网络与连接设置" \
            "world" "世界生成设置" \
            "performance" "性能优化设置" \
            "ops" "管理员与权限设置" \
            "jvm" "JVM参数配置" \
            "back" "返回上级菜单" 2>&1 >/dev/tty)
        
        [ -z "$action" ] && return

        case "$action" in
            "basic") basic_settings "$instance" ;;
            "network") network_settings "$instance" ;;
            "world") world_settings "$instance" ;;
            "performance") performance_settings "$instance" ;;
            "ops") ops_settings "$instance" ;;
            "jvm") jvm_settings "$instance" ;;
            "back") return ;;
        esac
    done
}

# 基本设置
basic_settings() {
    local instance=$1
    local instance_dir="${VERSIONS_DIR}/${instance}"
    
    # Bedrock服务器特殊处理
    if [[ "$instance" == *"Bedrock"* ]]; then
        bedrock_basic_settings "$instance"
        return
    fi
    
    while true; do
        # 获取当前值
        local current_motd=$(grep "^motd=" "${instance_dir}/server.properties" | cut -d= -f2- | sed 's/\\//g')
        local current_max_players=$(grep "^max-players=" "${instance_dir}/server.properties" | cut -d= -f2)
        local current_difficulty=$(grep "^difficulty=" "${instance_dir}/server.properties" | cut -d= -f2)
        local current_gamemode=$(grep "^gamemode=" "${instance_dir}/server.properties" | cut -d= -f2)
        local current_pvp=$(grep "^pvp=" "${instance_dir}/server.properties" | cut -d= -f2)
        local current_spawn_protection=$(grep "^spawn-protection=" "${instance_dir}/server.properties" | cut -d= -f2)
        
        # 对话框
        local choice=$(dialog --menu "基本设置 - ${instance}" 18 60 12 \
            "motd" "服务器描述 (当前: ${current_motd:0:20}...)" \
            "max_players" "最大玩家数 (当前: ${current_max_players})" \
            "difficulty" "难度 (当前: ${current_difficulty})" \
            "gamemode" "默认游戏模式 (当前: ${current_gamemode})" \
            "pvp" "PVP设置 (当前: ${current_pvp})" \
            "spawn_protection" "出生点保护半径 (当前: ${current_spawn_protection})" \
            "back" "返回" 2>&1 >/dev/tty)
        
        [ -z "$choice" ] && return
        
        case "$choice" in
            "motd")
                local new_motd=$(dialog --inputbox "输入服务器描述 (MOTD):" 10 70 "$current_motd" 2>&1 >/dev/tty)
                [ -n "$new_motd" ] && sed -i "s/^motd=.*/motd=${new_motd//\//\\\/}/" "${instance_dir}/server.properties"
                ;;
                
            "max_players")
                local new_max=$(dialog --inputbox "输入最大玩家数 (1-1000):" 10 50 "$current_max_players" 2>&1 >/dev/tty)
                if [[ "$new_max" =~ ^[0-9]+$ ]] && [ "$new_max" -ge 1 ] && [ "$new_max" -le 1000 ]; then
                    sed -i "s/^max-players=.*/max-players=${new_max}/" "${instance_dir}/server.properties"
                else
                    dialog --msgbox "无效的玩家数量！" 8 40
                fi
                ;;
                
            "difficulty")
                local new_diff=$(dialog --menu "选择难度" 12 40 5 \
                    "peaceful" "和平" \
                    "easy" "简单" \
                    "normal" "普通" \
                    "hard" "困难" 2>&1 >/dev/tty)
                [ -n "$new_diff" ] && sed -i "s/^difficulty=.*/difficulty=${new_diff}/" "${instance_dir}/server.properties"
                ;;
                
            "gamemode")
                local new_gm=$(dialog --menu "选择默认游戏模式" 12 50 5 \
                    "survival" "生存模式" \
                    "creative" "创造模式" \
                    "adventure" "冒险模式" \
                    "spectator" "旁观模式" 2>&1 >/dev/tty)
                [ -n "$new_gm" ] && sed -i "s/^gamemode=.*/gamemode=${new_gm}/" "${instance_dir}/server.properties"
                ;;
                
            "pvp")
                local new_pvp=$(dialog --menu "PVP设置" 12 40 5 \
                    "true" "启用PVP" \
                    "false" "禁用PVP" 2>&1 >/dev/tty)
                [ -n "$new_pvp" ] && sed -i "s/^pvp=.*/pvp=${new_pvp}/" "${instance_dir}/server.properties"
                ;;
                
            "spawn_protection")
                local new_prot=$(dialog --inputbox "输入出生点保护半径 (0-100):" 10 50 "$current_spawn_protection" 2>&1 >/dev/tty)
                if [[ "$new_prot" =~ ^[0-9]+$ ]] && [ "$new_prot" -ge 0 ] && [ "$new_prot" -le 100 ]; then
                    sed -i "s/^spawn-protection=.*/spawn-protection=${new_prot}/" "${instance_dir}/server.properties"
                else
                    dialog --msgbox "无效的保护半径！" 8 40
                fi
                ;;
                
            "back") return ;;
        esac
    done
}

# Bedrock服务器基本设置
bedrock_basic_settings() {
    local instance=$1
    local instance_dir="${VERSIONS_DIR}/${instance}"
    
    while true; do
        # 获取当前值
        local current_server_name=$(grep "^server-name=" "${instance_dir}/server.properties" | cut -d= -f2)
        local current_gamemode=$(grep "^gamemode=" "${instance_dir}/server.properties" | cut -d= -f2)
        local current_difficulty=$(grep "^difficulty=" "${instance_dir}/server.properties" | cut -d= -f2)
        local current_max_players=$(grep "^max-players=" "${instance_dir}/server.properties" | cut -d= -f2)
        local current_allow_cheats=$(grep "^allow-cheats=" "${instance_dir}/server.properties" | cut -d= -f2)
        
        # 对话框
        local choice=$(dialog --menu "Bedrock基本设置 - ${instance}" 18 60 12 \
            "server_name" "服务器名称 (当前: ${current_server_name:0:20}...)" \
            "gamemode" "游戏模式 (当前: ${current_gamemode})" \
            "difficulty" "难度 (当前: ${current_difficulty})" \
            "max_players" "最大玩家数 (当前: ${current_max_players})" \
            "allow_cheats" "允许作弊 (当前: ${current_allow_cheats})" \
            "back" "返回" 2>&1 >/dev/tty)
        
        [ -z "$choice" ] && return
        
        case "$choice" in
            "server_name")
                local new_name=$(dialog --inputbox "输入服务器名称:" 10 50 "$current_server_name" 2>&1 >/dev/tty)
                [ -n "$new_name" ] && sed -i "s/^server-name=.*/server-name=${new_name}/" "${instance_dir}/server.properties"
                ;;
                
            "gamemode")
                local new_gm=$(dialog --menu "选择游戏模式" 12 40 3 \
                    "survival" "生存模式" \
                    "creative" "创造模式" \
                    "adventure" "冒险模式" 2>&1 >/dev/tty)
                [ -n "$new_gm" ] && sed -i "s/^gamemode=.*/gamemode=${new_gm}/" "${instance_dir}/server.properties"
                ;;
                
            "difficulty")
                local new_diff=$(dialog --menu "选择难度" 12 40 4 \
                    "peaceful" "和平" \
                    "easy" "简单" \
                    "normal" "普通" \
                    "hard" "困难" 2>&1 >/dev/tty)
                [ -n "$new_diff" ] && sed -i "s/^difficulty=.*/difficulty=${new_diff}/" "${instance_dir}/server.properties"
                ;;
                
            "max_players")
                local new_max=$(dialog --inputbox "输入最大玩家数 (1-30):" 10 50 "$current_max_players" 2>&1 >/dev/tty)
                if [[ "$new_max" =~ ^[0-9]+$ ]] && [ "$new_max" -ge 1 ] && [ "$new_max" -le 30 ]; then
                    sed -i "s/^max-players=.*/max-players=${new_max}/" "${instance_dir}/server.properties"
                else
                    dialog --msgbox "无效的玩家数量！" 8 40
                fi
                ;;
                
            "allow_cheats")
                local new_cheats=$(dialog --menu "允许作弊" 12 40 2 \
                    "true" "启用" \
                    "false" "禁用" 2>&1 >/dev/tty)
                [ -n "$new_cheats" ] && sed -i "s/^allow-cheats=.*/allow-cheats=${new_cheats}/" "${instance_dir}/server.properties"
                ;;
                
            "back") return ;;
        esac
    done
}

# 网络设置
network_settings() {
    local instance=$1
    local instance_dir="${VERSIONS_DIR}/${instance}"
    
    # Bedrock服务器特殊处理
    if [[ "$instance" == *"Bedrock"* ]]; then
        bedrock_network_settings "$instance"
        return
    fi
    
    while true; do
        # 获取当前值
        local current_port=$(get_server_port "$instance")
        local current_online_mode=$(grep "^online-mode=" "${instance_dir}/server.properties" | cut -d= -f2)
        local current_whitelist=$(grep "^white-list=" "${instance_dir}/server.properties" | cut -d= -f2)
        local current_enforce_whitelist=$(grep "^enforce-whitelist=" "${instance_dir}/server.properties" | cut -d= -f2)
        
        # 对话框
        local choice=$(dialog --menu "网络设置 - ${instance}" 18 60 12 \
            "port" "服务器端口 (当前: ${current_port})" \
            "online_mode" "正版验证 (当前: ${current_online_mode})" \
            "whitelist" "白名单设置 (当前: ${current_whitelist})" \
            "back" "返回" 2>&1 >/dev/tty)
        
        [ -z "$choice" ] && return
        
        case "$choice" in
            "port")
                local new_port=$(dialog --inputbox "输入服务器端口 (1-65535):" 10 50 "$current_port" 2>&1 >/dev/tty)
                if [[ "$new_port" =~ ^[0-9]+$ ]] && [ "$new_port" -ge 1 ] && [ "$new_port" -le 65535 ]; then
                    sed -i "s/^server-port=.*/server-port=${new_port}/" "${instance_dir}/server.properties"
                    dialog --msgbox "端口已修改为 ${new_port}" 8 40
                else
                    dialog --msgbox "无效的端口号！" 8 40
                fi
                ;;
                
            "online_mode")
                local new_om=$(dialog --menu "正版验证设置" 12 50 5 \
                    "true" "启用 (仅正版玩家)" \
                    "false" "禁用 (离线模式)" 2>&1 >/dev/tty)
                [ -n "$new_om" ] && {
                    sed -i "s/^online-mode=.*/online-mode=${new_om}/" "${instance_dir}/server.properties"
                    dialog --msgbox "正版验证已${new_om}" 8 40
                }
                ;;
                
            "whitelist")
                local new_wl=$(dialog --menu "白名单设置" 15 60 5 \
                    "enable" "启用白名单" \
                    "disable" "禁用白名单" \
                    "add" "添加玩家到白名单" \
                    "remove" "从白名单移除玩家" \
                    "list" "查看白名单" 2>&1 >/dev/tty)
                
                case "$new_wl" in
                    "enable")
                        sed -i "s/^white-list=.*/white-list=true/" "${instance_dir}/server.properties"
                        sed -i "s/^enforce-whitelist=.*/enforce-whitelist=true/" "${instance_dir}/server.properties"
                        dialog --msgbox "白名单已启用" 8 40
                        ;;
                        
                    "disable")
                        sed -i "s/^white-list=.*/white-list=false/" "${instance_dir}/server.properties"
                        sed -i "s/^enforce-whitelist=.*/enforce-whitelist=false/" "${instance_dir}/server.properties"
                        dialog --msgbox "白名单已禁用" 8 40
                        ;;
                        
                    "add")
                        local player=$(dialog --inputbox "输入要添加到白名单的玩家名:" 10 50 2>&1 >/dev/tty)
                        if [ -n "$player" ]; then
                            echo "whitelist add $player" > "${instance_dir}/command_input"
                            dialog --msgbox "已添加 ${player} 到白名单" 8 40
                        fi
                        ;;
                        
                    "remove")
                        local players=($(grep -v "^#" "${instance_dir}/whitelist.json" 2>/dev/null | jq -r '.[].name' 2>/dev/null || echo "无"))
                        if [ ${#players[@]} -eq 0 ]; then
                            dialog --msgbox "白名单为空！" 8 40
                            continue
                        fi
                        
                        local player=$(dialog --menu "选择要移除的玩家" 15 60 8 \
                            $(for p in "${players[@]}"; do echo "$p" ""; done) 2>&1 >/dev/tty)
                        if [ -n "$player" ]; then
                            echo "whitelist remove $player" > "${instance_dir}/command_input"
                            dialog --msgbox "已从白名单移除 ${player}" 8 40
                        fi
                        ;;
                        
                    "list")
                        local players=($(grep -v "^#" "${instance_dir}/whitelist.json" 2>/dev/null | jq -r '.[].name' 2>/dev/null || echo "无"))
                        dialog --msgbox "白名单玩家:\n\n${players[*]}" 12 60
                        ;;
                esac
                ;;
                
            "back") return ;;
        esac
    done
}

# Bedrock网络设置
bedrock_network_settings() {
    local instance=$1
    local instance_dir="${VERSIONS_DIR}/${instance}"
    
    while true; do
        # 获取当前值
        local current_port=$(get_server_port "$instance")
        local current_online_mode=$(grep "^online-mode=" "${instance_dir}/server.properties" | cut -d= -f2)
        local current_ipv6_port=$(grep "^server-portv6=" "${instance_dir}/server.properties" | cut -d= -f2)
        
        # 对话框
        local choice=$(dialog --menu "Bedrock网络设置 - ${instance}" 18 60 12 \
            "port" "服务器端口 (当前: ${current_port})" \
            "ipv6_port" "IPv6端口 (当前: ${current_ipv6_port})" \
            "online_mode" "正版验证 (当前: ${current_online_mode})" \
            "back" "返回" 2>&1 >/dev/tty)
        
        [ -z "$choice" ] && return
        
        case "$choice" in
            "port")
                local new_port=$(dialog --inputbox "输入服务器端口 (1-65535):" 10 50 "$current_port" 2>&1 >/dev/tty)
                if [[ "$new_port" =~ ^[0-9]+$ ]] && [ "$new_port" -ge 1 ] && [ "$new_port" -le 65535 ]; then
                    sed -i "s/^server-port=.*/server-port=${new_port}/" "${instance_dir}/server.properties"
                    dialog --msgbox "端口已修改为 ${new_port}" 8 40
                else
                    dialog --msgbox "无效的端口号！" 8 40
                fi
                ;;
                
            "ipv6_port")
                local new_port=$(dialog --inputbox "输入IPv6端口 (1-65535):" 10 50 "$current_ipv6_port" 2>&1 >/dev/tty)
                if [[ "$new_port" =~ ^[0-9]+$ ]] && [ "$new_port" -ge 1 ] && [ "$new_port" -le 65535 ]; then
                    sed -i "s/^server-portv6=.*/server-portv6=${new_port}/" "${instance_dir}/server.properties"
                    dialog --msgbox "IPv6端口已修改为 ${new_port}" 8 40
                else
                    dialog --msgbox "无效的端口号！" 8 40
                fi
                ;;
                
            "online_mode")
                local new_om=$(dialog --menu "正版验证设置" 12 50 2 \
                    "true" "启用 (仅正版玩家)" \
                    "false" "禁用 (离线模式)" 2>&1 >/dev/tty)
                [ -n "$new_om" ] && {
                    sed -i "s/^online-mode=.*/online-mode=${new_om}/" "${instance_dir}/server.properties"
                    dialog --msgbox "正版验证已${new_om}" 8 40
                }
                ;;
                
            "back") return ;;
        esac
    done
}

# 世界设置
world_settings() {
    local instance=$1
    local instance_dir="${VERSIONS_DIR}/${instance}"
    
    # Bedrock服务器特殊处理
    if [[ "$instance" == *"Bedrock"* ]]; then
        bedrock_world_settings "$instance"
        return
    fi
    
    while true; do
        # 获取当前值
        local current_level_name=$(grep "^level-name=" "${instance_dir}/server.properties" | cut -d= -f2)
        local current_level_type=$(grep "^level-type=" "${instance_dir}/server.properties" | cut -d= -f2)
        local current_seed=$(grep "^level-seed=" "${instance_dir}/server.properties" | cut -d= -f2)
        local current_generate_structures=$(grep "^generate-structures=" "${instance_dir}/server.properties" | cut -d= -f2)
        local current_view_distance=$(grep "^view-distance=" "${instance_dir}/server.properties" | cut -d= -f2)
        
        # 对话框
        local choice=$(dialog --menu "世界设置 - ${instance}" 18 60 12 \
            "level_name" "世界名称 (当前: ${current_level_name})" \
            "level_type" "世界类型 (当前: ${current_level_type})" \
            "seed" "世界种子 (当前: ${current_seed})" \
            "structures" "生成结构 (当前: ${current_generate_structures})" \
            "view_distance" "视距 (当前: ${current_view_distance})" \
            "back" "返回" 2>&1 >/dev/tty)
        
        [ -z "$choice" ] && return
        
        case "$choice" in
            "level_name")
                local new_name=$(dialog --inputbox "输入世界名称:" 10 50 "$current_level_name" 2>&1 >/dev/tty)
                [ -n "$new_name" ] && sed -i "s/^level-name=.*/level-name=${new_name}/" "${instance_dir}/server.properties"
                ;;
                
            "level_type")
                local new_type=$(dialog --menu "选择世界类型" 15 50 5 \
                    "default" "默认 (普通世界)" \
                    "flat" "超平坦" \
                    "largebiomes" "巨型生物群系" \
                    "amplified" "放大化" \
                    "buffet" "自定义" 2>&1 >/dev/tty)
                [ -n "$new_type" ] && sed -i "s/^level-type=.*/level-type=${new_type}/" "${instance_dir}/server.properties"
                ;;
                
            "seed")
                local new_seed=$(dialog --inputbox "输入世界种子 (留空随机):" 10 50 "$current_seed" 2>&1 >/dev/tty)
                sed -i "s/^level-seed=.*/level-seed=${new_seed}/" "${instance_dir}/server.properties"
                ;;
                
            "structures")
                local new_struct=$(dialog --menu "生成结构设置" 12 50 5 \
                    "true" "生成结构 (村庄、神殿等)" \
                    "false" "不生成结构" 2>&1 >/dev/tty)
                [ -n "$new_struct" ] && sed -i "s/^generate-structures=.*/generate-structures=${new_struct}/" "${instance_dir}/server.properties"
                ;;
                
            "view_distance")
                local new_vd=$(dialog --inputbox "输入视距 (3-32):" 10 50 "$current_view_distance" 2>&1 >/dev/tty)
                if [[ "$new_vd" =~ ^[0-9]+$ ]] && [ "$new_vd" -ge 3 ] && [ "$new_vd" -le 32 ]; then
                    sed -i "s/^view-distance=.*/view-distance=${new_vd}/" "${instance_dir}/server.properties"
                else
                    dialog --msgbox "无效的视距值！" 8 40
                fi
                ;;
                
            "back") return ;;
        esac
    done
}

# Bedrock世界设置
bedrock_world_settings() {
    local instance=$1
    local instance_dir="${VERSIONS_DIR}/${instance}"
    
    while true; do
        # 获取当前值
        local current_level_name=$(grep "^level-name=" "${instance_dir}/server.properties" | cut -d= -f2)
        local current_level_seed=$(grep "^level-seed=" "${instance_dir}/server.properties" | cut -d= -f2)
        local current_view_distance=$(grep "^view-distance=" "${instance_dir}/server.properties" | cut -d= -f2)
        local current_tick_distance=$(grep "^tick-distance=" "${instance_dir}/server.properties" | cut -d= -f2)
        
        # 对话框
        local choice=$(dialog --menu "Bedrock世界设置 - ${instance}" 18 60 12 \
            "level_name" "世界名称 (当前: ${current_level_name})" \
            "level_seed" "世界种子 (当前: ${current_level_seed})" \
            "view_distance" "视距 (当前: ${current_view_distance})" \
            "tick_distance" "Tick距离 (当前: ${current_tick_distance})" \
            "back" "返回" 2>&1 >/dev/tty)
        
        [ -z "$choice" ] && return
        
        case "$choice" in
            "level_name")
                local new_name=$(dialog --inputbox "输入世界名称:" 10 50 "$current_level_name" 2>&1 >/dev/tty)
                [ -n "$new_name" ] && sed -i "s/^level-name=.*/level-name=${new_name}/" "${instance_dir}/server.properties"
                ;;
                
            "level_seed")
                local new_seed=$(dialog --inputbox "输入世界种子 (留空随机):" 10 50 "$current_level_seed" 2>&1 >/dev/tty)
                sed -i "s/^level-seed=.*/level-seed=${new_seed}/" "${instance_dir}/server.properties"
                ;;
                
            "view_distance")
                local new_vd=$(dialog --inputbox "输入视距 (4-64):" 10 50 "$current_view_distance" 2>&1 >/dev/tty)
                if [[ "$new_vd" =~ ^[0-9]+$ ]] && [ "$new_vd" -ge 4 ] && [ "$new_vd" -le 64 ]; then
                    sed -i "s/^view-distance=.*/view-distance=${new_vd}/" "${instance_dir}/server.properties"
                else
                    dialog --msgbox "无效的视距值！" 8 40
                fi
                ;;
                
            "tick_distance")
                local new_td=$(dialog --inputbox "输入Tick距离 (4-12):" 10 50 "$current_tick_distance" 2>&1 >/dev/tty)
                if [[ "$new_td" =~ ^[0-9]+$ ]] && [ "$new_td" -ge 4 ] && [ "$new_td" -le 12 ]; then
                    sed -i "s/^tick-distance=.*/tick-distance=${new_td}/" "${instance_dir}/server.properties"
                else
                    dialog --msgbox "无效的Tick距离！" 8 40
                fi
                ;;
                
            "back") return ;;
        esac
    done
}

# 性能设置
performance_settings() {
    local instance=$1
    local instance_dir="${VERSIONS_DIR}/${instance}"
    
    # Bedrock服务器特殊处理
    if [[ "$instance" == *"Bedrock"* ]]; then
        bedrock_performance_settings "$instance"
        return
    fi
    
    while true; do
        # 获取当前值
        local current_max_tick_time=$(grep "^max-tick-time=" "${instance_dir}/server.properties" | cut -d= -f2)
        local current_sync_chunk_writes=$(grep "^sync-chunk-writes=" "${instance_dir}/server.properties" | cut -d= -f2)
        local current_entity_broadcast_range=$(grep "^entity-broadcast-range-percentage=" "${instance_dir}/server.properties" | cut -d= -f2)
        
        # 对话框
        local choice=$(dialog --menu "性能设置 - ${instance}" 18 60 12 \
            "tick_time" "最大tick时间 (当前: ${current_max_tick_time}ms)" \
            "chunk_writes" "区块写入同步 (当前: ${current_sync_chunk_writes})" \
            "entity_range" "实体广播范围 (当前: ${current_entity_broadcast_range}%)" \
            "back" "返回" 2>&1 >/dev/tty)
        
        [ -z "$choice" ] && return
        
        case "$choice" in
            "tick_time")
                local new_tt=$(dialog --inputbox "输入最大tick时间 (单位ms):" 10 50 "$current_max_tick_time" 2>&1 >/dev/tty)
                if [[ "$new_tt" =~ ^[0-9]+$ ]] && [ "$new_tt" -ge 1000 ]; then
                    sed -i "s/^max-tick-time=.*/max-tick-time=${new_tt}/" "${instance_dir}/server.properties"
                else
                    dialog --msgbox "无效的值 (最小1000ms)！" 8 40
                fi
                ;;
                
            "chunk_writes")
                local new_cw=$(dialog --menu "区块写入同步设置" 12 50 5 \
                    "true" "启用 (安全但较慢)" \
                    "false" "禁用 (较快但有风险)" 2>&1 >/dev/tty)
                [ -n "$new_cw" ] && sed -i "s/^sync-chunk-writes=.*/sync-chunk-writes=${new_cw}/" "${instance_dir}/server.properties"
                ;;
                
            "entity_range")
                local new_er=$(dialog --inputbox "输入实体广播范围百分比 (10-100):" 10 50 "$current_entity_broadcast_range" 2>&1 >/dev/tty)
                if [[ "$new_er" =~ ^[0-9]+$ ]] && [ "$new_er" -ge 10 ] && [ "$new_er" -le 100 ]; then
                    sed -i "s/^entity-broadcast-range-percentage=.*/entity-broadcast-range-percentage=${new_er}/" "${instance_dir}/server.properties"
                else
                    dialog --msgbox "无效的范围值！" 8 40
                fi
                ;;
                
            "back") return ;;
        esac
    done
}

# Bedrock性能设置
bedrock_performance_settings() {
    local instance=$1
    local instance_dir="${VERSIONS_DIR}/${instance}"
    
    while true; do
        # 获取当前值
        local current_max_threads=$(grep "^max-threads=" "${instance_dir}/server.properties" | cut -d= -f2)
        local current_player_idle_timeout=$(grep "^player-idle-timeout=" "${instance_dir}/server.properties" | cut -d= -f2)
        
        # 对话框
        local choice=$(dialog --menu "Bedrock性能设置 - ${instance}" 18 60 12 \
            "max_threads" "最大线程数 (当前: ${current_max_threads})" \
            "player_idle_timeout" "玩家空闲超时 (当前: ${current_player_idle_timeout})" \
            "back" "返回" 2>&1 >/dev/tty)
        
        [ -z "$choice" ] && return
        
        case "$choice" in
            "max_threads")
                local new_mt=$(dialog --inputbox "输入最大线程数 (1-16):" 10 50 "$current_max_threads" 2>&1 >/dev/tty)
                if [[ "$new_mt" =~ ^[0-9]+$ ]] && [ "$new_mt" -ge 1 ] && [ "$new_mt" -le 16 ]; then
                    sed -i "s/^max-threads=.*/max-threads=${new_mt}/" "${instance_dir}/server.properties"
                else
                    dialog --msgbox "无效的线程数！" 8 40
                fi
                ;;
                
            "player_idle_timeout")
                local new_pit=$(dialog --inputbox "输入玩家空闲超时 (分钟):" 10 50 "$current_player_idle_timeout" 2>&1 >/dev/tty)
                if [[ "$new_pit" =~ ^[0-9]+$ ]]; then
                    sed -i "s/^player-idle-timeout=.*/player-idle-timeout=${new_pit}/" "${instance_dir}/server.properties"
                else
                    dialog --msgbox "无效的超时值！" 8 40
                fi
                ;;
                
            "back") return ;;
        esac
    done
}

# 管理员设置
ops_settings() {
    local instance=$1
    local instance_dir="${VERSIONS_DIR}/${instance}"
    
    # Bedrock服务器特殊处理
    if [[ "$instance" == *"Bedrock"* ]]; then
        bedrock_ops_settings "$instance"
        return
    fi
    
    while true; do
        # 获取当前OP列表
        local ops=($(grep -v "^#" "${instance_dir}/ops.json" 2>/dev/null | jq -r '.[].name' 2>/dev/null || echo "无"))
        
        # 对话框
        local choice=$(dialog --menu "管理员设置 - ${instance}" 18 60 12 \
            "add" "添加管理员" \
            "remove" "移除管理员" \
            "list" "查看管理员列表" \
            "level" "设置管理员等级" \
            "back" "返回" 2>&1 >/dev/tty)
        
        [ -z "$choice" ] && return
        
        case "$choice" in
            "add")
                local player=$(dialog --inputbox "输入要设置为管理员的玩家名:" 10 50 2>&1 >/dev/tty)
                if [ -n "$player" ]; then
                    echo "op $player" > "${instance_dir}/command_input"
                    dialog --msgbox "已添加 ${player} 为管理员" 8 40
                fi
                ;;
                
            "remove")
                if [ ${#ops[@]} -eq 0 ]; then
                    dialog --msgbox "管理员列表为空！" 8 40
                    continue
                fi
                
                local player=$(dialog --menu "选择要移除的管理员" 15 60 8 \
                    $(for p in "${ops[@]}"; do echo "$p" ""; done) 2>&1 >/dev/tty)
                if [ -n "$player" ]; then
                    echo "deop $player" > "${instance_dir}/command_input"
                    dialog --msgbox "已移除 ${player} 的管理员权限" 8 40
                fi
                ;;
                
            "list")
                dialog --msgbox "管理员列表:\n\n${ops[*]}" 12 60
                ;;
                
            "level")
                if [ ${#ops[@]} -eq 0 ]; then
                    dialog --msgbox "管理员列表为空！" 8 40
                    continue
                fi
                
                local player=$(dialog --menu "选择要设置等级的管理员" 15 60 8 \
                    $(for p in "${ops[@]}"; do echo "$p" ""; done) 2>&1 >/dev/tty)
                if [ -n "$player" ]; then
                    local level=$(dialog --menu "选择管理员等级" 12 50 5 \
                        "1" "最低权限 (仅基本命令)" \
                        "2" "普通权限" \
                        "3" "高级权限" \
                        "4" "最高权限 (等同于OP)" 2>&1 >/dev/tty)
                    if [ -n "$level" ]; then
                        echo "op $player $level" > "${instance_dir}/command_input"
                        dialog --msgbox "已设置 ${player} 的管理员等级为 ${level}" 8 40
                    fi
                fi
                ;;
                
            "back") return ;;
        esac
    done
}

# Bedrock管理员设置
bedrock_ops_settings() {
    local instance=$1
    local instance_dir="${VERSIONS_DIR}/${instance}"
    
    while true; do
        # 获取当前权限列表
        local permissions=($(grep -v "^#" "${instance_dir}/permissions.json" 2>/dev/null | jq -r '.[].name' 2>/dev/null || echo "无"))
        
        # 对话框
        local choice=$(dialog --menu "Bedrock权限设置 - ${instance}" 18 60 12 \
            "add" "添加权限" \
            "remove" "移除权限" \
            "list" "查看权限列表" \
            "back" "返回" 2>&1 >/dev/tty)
        
        [ -z "$choice" ] && return
        
        case "$choice" in
            "add")
                local player=$(dialog --inputbox "输入要设置权限的玩家名:" 10 50 2>&1 >/dev/tty)
                if [ -n "$player" ]; then
                    local perm_level=$(dialog --menu "选择权限等级" 12 50 3 \
                        "member" "普通成员" \
                        "operator" "操作员" \
                        "custom" "自定义" 2>&1 >/dev/tty)
                    
                    if [ -n "$perm_level" ]; then
                        echo "permission set $player $perm_level" > "${instance_dir}/command_input"
                        dialog --msgbox "已设置 ${player} 的权限等级为 ${perm_level}" 8 40
                    fi
                fi
                ;;
                
            "remove")
                if [ ${#permissions[@]} -eq 0 ]; then
                    dialog --msgbox "权限列表为空！" 8 40
                    continue
                fi
                
                local player=$(dialog --menu "选择要移除权限的玩家" 15 60 8 \
                    $(for p in "${permissions[@]}"; do echo "$p" ""; done) 2>&1 >/dev/tty)
                if [ -n "$player" ]; then
                    echo "permission remove $player" > "${instance_dir}/command_input"
                    dialog --msgbox "已移除 ${player} 的权限" 8 40
                fi
                ;;
                
            "list")
                dialog --msgbox "权限列表:\n\n${permissions[*]}" 12 60
                ;;
                
            "back") return ;;
        esac
    done
}

# JVM参数配置
jvm_settings() {
    local instance=$1
    local instance_dir="${VERSIONS_DIR}/${instance}"
    
    # Bedrock服务器不需要JVM设置
    if [[ "$instance" == *"Bedrock"* ]]; then
        dialog --msgbox "Bedrock服务器不使用JVM参数" 8 40
        return
    fi
    
    while true; do
        # 获取当前JVM参数
        local current_args=$(grep "^JAVA_ARGS=" "${instance_dir}/start.sh" | cut -d= -f2- | sed "s/\"//g")
        
        # 对话框
        local choice=$(dialog --menu "JVM参数配置 - ${instance}" 15 70 12 \
            "edit" "编辑JVM参数 (当前: ${current_args:0:30}...)" \
            "preset" "预设配置" \
            "back" "返回" 2>&1 >/dev/tty)
        
        [ -z "$choice" ] && return
        
        case "$choice" in
            "edit")
                local new_args=$(dialog --inputbox "输入JVM参数:" 10 100 "$current_args" 2>&1 >/dev/tty)
                if [ -n "$new_args" ]; then
                    sed -i "s|^JAVA_ARGS=.*|JAVA_ARGS=\"${new_args}\"|" "${instance_dir}/start.sh"
                    dialog --msgbox "JVM参数已更新" 8 40
                fi
                ;;
                
            "preset")
                local preset=$(dialog --menu "选择JVM预设" 15 70 5 \
                    "default" "默认配置 (2-4GB)" \
                    "optimized" "优化配置 (Aikar推荐)" \
                    "large" "大内存配置 (8GB+)" \
                    "custom" "自定义" 2>&1 >/dev/tty)
                
                case "$preset" in
                    "default")
                        local new_args="-Xms2G -Xmx4G -XX:+UseG1GC"
                        sed -i "s|^JAVA_ARGS=.*|JAVA_ARGS=\"${new_args}\"|" "${instance_dir}/start.sh"
                        ;;
                        
                    "optimized")
                        local new_args="-Xms2G -Xmx4G -XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200"
                        new_args="${new_args} -XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC -XX:+AlwaysPreTouch"
                        new_args="${new_args} -XX:G1HeapWastePercent=5 -XX:G1MixedGCCountTarget=4 -XX:G1MixedGCLiveThresholdPercent=90"
                        new_args="${new_args} -XX:G1RSetUpdatingPauseTimePercent=5 -XX:SurvivorRatio=32 -XX:+PerfDisableSharedMem"
                        new_args="${new_args} -XX:MaxTenuringThreshold=1 -XX:G1NewSizePercent=30 -XX:G1MaxNewSizePercent=40"
                        new_args="${new_args} -XX:InitiatingHeapOccupancyPercent=15 -XX:G1HeapRegionSize=8M -XX:G1ReservePercent=20"
                        new_args="${new_args} -Dusing.aikars.flags=https://mcflags.emc.gs"
                        sed -i "s|^JAVA_ARGS=.*|JAVA_ARGS=\"${new_args}\"|" "${instance_dir}/start.sh"
                        ;;
                        
                    "large")
                        local new_args="-Xms6G -Xmx8G -XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=150"
                        new_args="${new_args} -XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC -XX:+AlwaysPreTouch"
                        new_args="${new_args} -XX:G1HeapWastePercent=5 -XX:G1MixedGCCountTarget=4 -XX:G1MixedGCLiveThresholdPercent=90"
                        new_args="${new_args} -XX:G1RSetUpdatingPauseTimePercent=5 -XX:SurvivorRatio=32 -XX:+PerfDisableSharedMem"
                        new_args="${new_args} -XX:MaxTenuringThreshold=1 -XX:G1NewSizePercent=40 -XX:G1MaxNewSizePercent=50"
                        new_args="${new_args} -XX:InitiatingHeapOccupancyPercent=15 -XX:G1HeapRegionSize=16M -XX:G1ReservePercent=15"
                        new_args="${new_args} -Dusing.aikars.flags=https://mcflags.emc.gs"
                        sed -i "s|^JAVA_ARGS=.*|JAVA_ARGS=\"${new_args}\"|" "${instance_dir}/start.sh"
                        ;;
                esac

                if [ -n "$preset" ]; then
                    dialog --msgbox "已应用 ${preset} JVM预设" 8 40
                fi
                ;;
                
            "back") return ;;
        esac
    done
}

# 获取实例版本
get_instance_version() {
    local instance="$1"
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
    local instance="$1"
    local instance_dir="${VERSIONS_DIR}/${instance}"
    
    if [[ "$instance" == *"Bedrock"* ]]; then
        if [ -f "${instance_dir}/server.properties" ]; then
            grep "^server-port=" "${instance_dir}/server.properties" | cut -d= -f2 || echo "19132"
        else
            echo "19132"
        fi
    else
        if [ -f "${instance_dir}/server.properties" ]; then
            grep "^server-port=" "${instance_dir}/server.properties" | cut -d= -f2 || echo "25565"
        else
            echo "25565"
        fi
    fi
}

# 检查服务器运行状态
check_server_status() {
    local instance="$1"  
    if [[ "$instance" == *"Bedrock"* ]]; then
        if pgrep -f "bedrock_server" >/dev/null; then
            return 0
        else
            return 1
        fi
    fi
    
    if pgrep -f "java -jar ${VERSIONS_DIR}/${instance}/server.jar" >/dev/null; then
        return 0
    else
        return 1
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

# 主入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    config_menu
fi
