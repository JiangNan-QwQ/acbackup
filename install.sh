#!/bin/bash
# AetherCraft - 安装模块
# 作者: B站@爱做视频のJack_Eason
# 版本: 3.4
# 日期: 2025-06-29

# 加载公共库
source <(curl -s https://gitee.com/jiangnan-qwq/AetherCraft_cn/raw/main/common.sh)

# 安装菜单
install_menu() {
    while true; do
        choice=$(dialog --menu "服务器安装选项" 15 50 5 \
            "1" "安装新服务器实例" \
            "2" "查看已安装实例" \
            "3" "卸载服务器实例" \
            "4" "返回主菜单" 2>&1 >/dev/tty)
            
        case "$choice" in
            1) install_core ;;
            2) list_instances ;;
            3) uninstall_instance ;;
            4) return 0 ;;
            *) log "无效选项" "WARN";;
        esac
    done
}

# 卸载服务器实例
uninstall_instance() {
    # 获取实例列表
    local instances=($(get_instance_list))
    
    if [ ${#instances[@]} -eq 0 ]; then
        dialog --msgbox "没有找到已安装的服务器实例" 8 40
        return
    fi
    
    # 生成菜单项
    local menu_items=()
    for instance in "${instances[@]}"; do
        local install_dir="${VERSIONS_DIR}/${instance}"
        local size=$(du -sh "$install_dir" | cut -f1)
        menu_items+=("$instance" "大小: $size")
    done
    
    # 选择要卸载的实例
    local selected=$(dialog --menu "选择要卸载的实例" 20 70 15 \
        "${menu_items[@]}" 2>&1 >/dev/tty)
    [ -z "$selected" ] && return
    
    # 确认卸载
    dialog --yesno "确定要完全卸载实例 ${selected} 吗？此操作不可逆！" 10 50 || return
    
    # 停止运行中的实例
    if check_server_status "$selected"; then
        stop_instance "$selected" || {
            dialog --msgbox "无法停止服务器，卸载中止" 8 40
            return 1
        }
    fi
    
    # 执行卸载
    (
        echo "10"
        echo "# 正在删除实例文件..."
        rm -rf "${VERSIONS_DIR}/${selected}"
        
        echo "50"
        echo "# 清理备份文件..."
        find "${BACKUP_DIR}" -name "${selected}-*" -exec rm -f {} \;
        
        echo "100"
        echo "# 卸载完成!"
    ) | dialog --gauge "正在卸载实例 ${selected}" 8 70 0
    
    dialog --msgbox "实例 ${selected} 已成功卸载" 8 40
}

stop_instance() {
    local instance=$1
    local instance_dir="${VERSIONS_DIR}/${instance}"
    
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

# 安装核心服务器

install_core() {
    # 创建版本隔离目录
    mkdir -p "$VERSIONS_DIR" || {
        log "无法创建版本目录: $VERSIONS_DIR" "ERROR"
        return 1
    }

    # 核心类型选择
    local core_type=$(dialog --menu "选择服务器核心" 15 50 7 \
        "1" "Fabric (适合模组)" \
        "2" "Spigot (适合插件)" \
        "3" "Paper (手机Termux不可用)" \
        "4" "Forge (适合大型模组)" \
        "5" "Vanilla (官方原版)" \
        "6" "Bedrock (基岩版)" \
        2>&1 >/dev/tty) || return 0

    case $core_type in
        1) core_name="Fabric" ;;
        2) core_name="Spigot" ;;
        3) core_name="Paper" ;;
        4) core_name="Forge" ;;
        5) core_name="Vanilla" ;;
        6) core_name="Bedrock" ;;
        *) return ;;
    esac

    # 获取所有可用版本
    local versions=()
    case $core_name in
        "Fabric")
            log "正在获取Fabric版本列表..." "INFO"
            versions=($(curl -fsSL "https://meta.fabricmc.net/v2/versions/game" | \
                      jq -r '.[] | select(.stable == true) | .version' | sort -Vr | head -n 10)) || {
                dialog --msgbox "无法获取Fabric版本信息" 10 50
                return 1
            }
            ;;
        "Spigot")
            log "正在获取Spigot版本列表..." "INFO"
            versions=($(curl -fsSL "https://hub.spigotmc.org/versions/" | \
                      grep -Eo '[0-9]+\.[0-9]+(\.[0-9]+)?' | sort -Vr | uniq | head -n 10)) || {
                dialog --msgbox "无法获取Spigot版本信息" 10 50
                return 1
            }
            ;;
        "Paper")
            log "正在获取Paper版本列表..." "INFO"
            versions=($(curl -fsSL "https://papermc.io/api/v2/projects/paper" | \
                      jq -r '.versions[]' | sort -Vr | head -n 10)) || {
                dialog --msgbox "无法获取Paper版本信息" 10 50
                return 1
            }
            ;;
        "Forge")
            # Forge 版本由用户直接输入，不列出最新版本
            versions=("点我")  
            ;;
        "Vanilla")
            log "正在获取Vanilla版本列表..." "INFO"
            versions=($(curl -fsSL "https://launchermeta.mojang.com/mc/game/version_manifest.json" | \
                      jq -r '.versions[] | .id' | sort -Vr | head -n 10)) || {
                dialog --msgbox "无法获取Vanilla版本信息" 10 50
                return 1
            }
            ;;
        "Bedrock")
            versions=("latest")  # Bedrock通常只有一个最新版本
            ;;
    esac

    [ ${#versions[@]} -eq 0 ] && {
        dialog --msgbox "没有找到可用版本" 10 50
        return 1
    }

    # 生成dialog菜单选项（添加自定义选项）
    local menu_options=()
    for ((i=0; i<${#versions[@]}; i++)); do
        menu_options+=("$((i+1))" "${versions[$i]}")
    done
    menu_options+=("$(( ${#versions[@]} + 1 ))" "自定义输入版本号")

    # 显示版本选择菜单
    local version_choice=$(dialog --menu "选择版本 (最新10个)" 20 60 12 \
        "${menu_options[@]}" 2>&1 >/dev/tty) || return 0
    
    local selected_version
    if [ "$version_choice" -eq $(( ${#versions[@]} + 1 )) ]; then
        # 自定义版本输入
        selected_version=$(dialog --inputbox "请输入要安装的${core_name}版本号\n(例如: 1.20.1)" 10 50 2>&1 >/dev/tty) || return 0
        
        # 检查版本是否存在
        case $core_name in
            "Fabric")
                if ! curl -fsSL "https://meta.fabricmc.net/v2/versions/game" | jq -r '.[].version' | grep -q "^${selected_version}$"; then
                    dialog --msgbox "错误：Fabric ${selected_version} 版本不存在！" 10 50
                    return 1
                fi
                ;;
            "Spigot")
                if ! curl -fsSL "https://hub.spigotmc.org/versions/" | grep -qE "${selected_version//./\\.}"; then
                    dialog --msgbox "错误：Spigot ${selected_version} 版本不存在！" 10 50
                    return 1
                fi
                ;;
            "Paper")
                if ! curl -fsSL "https://papermc.io/api/v2/projects/paper" | jq -r '.versions[]' | grep -q "^${selected_version}$"; then
                    dialog --msgbox "错误：Paper ${selected_version} 版本不存在！" 10 50
                    return 1
                fi
                ;;
            "Vanilla")
                if ! curl -fsSL "https://launchermeta.mojang.com/mc/game/version_manifest.json" | jq -r '.versions[] | .id' | grep -q "^${selected_version}$"; then
                    dialog --msgbox "错误：Vanilla ${selected_version} 版本不存在！" 10 50
                    return 1
                fi
                ;;
            "Bedrock")
                selected_version="latest"  # Bedrock只支持最新版
                ;;
        esac
        
        dialog --msgbox "正在准备安装 ${core_name} ${selected_version}..." 10 50
    else
        selected_version="${versions[$((version_choice-1))]}"
    fi

    # 获取实例名称
    local instance_name=$(dialog --inputbox "输入实例名称\n(仅字母数字和短横线)" 8 40 2>&1 >/dev/tty) || return 0
    # 验证实例名称
    if [[ ! "$instance_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        dialog --msgbox "实例名称只能包含字母、数字、下划线和短横线" 8 40
        return 1
    fi

    # 修改Forge实例命名逻辑
    if [[ "$core_name" == "Forge" ]]; then
        # 让用户输入完整的Forge版本号（格式如：1.20.1-47.1.0）
        local forge_version=$(dialog --inputbox "输入完整的Forge版本号 (格式: MC版本-Forge版本，例如1.20.1-47.1.0):" 10 50 2>&1 >/dev/tty)
        [ -z "$forge_version" ] && return 1
        
        # 提取MC版本部分用于实例命名
        local mc_version_part=$(echo "$forge_version" | cut -d'-' -f1)
        local install_dir="${VERSIONS_DIR}/Forge-${mc_version_part}-${instance_name}"
    else
        local install_dir="${VERSIONS_DIR}/${core_name}-${selected_version}-${instance_name}"
    fi

    if [ -d "$install_dir" ]; then
        dialog --yesno "实例目录已存在，是否覆盖？\n${install_dir}" 10 50 || return 0
        rm -rf "$install_dir"
    fi
    mkdir -p "$install_dir" || return 1

    # 下载核心
    case $core_name in
        "Fabric")
            download_fabric "$selected_version" "$install_dir" || {
                rm -rf "$install_dir"
                return 1
            }
            ;;
        "Spigot")
            download_spigot "$selected_version" "$install_dir" || {
                rm -rf "$install_dir"
                return 1
            }
            ;;
        "Paper")
            download_paper "$selected_version" "$install_dir" || {
                rm -rf "$install_dir"
                return 1
            }
            ;;
        "Forge")
            download_forge "$forge_version" "$install_dir" || {
                rm -rf "$install_dir"
                return 1
            }
            ;;
        "Vanilla")
            download_vanilla "$selected_version" "$install_dir" || {
                rm -rf "$install_dir"
                return 1
            }
            ;;
        "Bedrock")
            download_bedrock "$selected_version" "$install_dir" || {
                rm -rf "$install_dir"
                return 1
            }
            ;;
    esac

    # 生成启动脚本
    generate_start_script "$install_dir" "$core_name"

    # 自动同意EULA
    echo "eula=true" > "${install_dir}/eula.txt"

    # 生成默认配置文件
    generate_server_properties "$install_dir" "$core_name"

    # 生成实例配置文件
    generate_instance_config "$core_name" "$selected_version" "$instance_name" "$install_dir"

    dialog --msgbox "${core_name}服务器安装完成！\n路径: ${install_dir}" 12 50
    log "成功安装 ${core_name} ${selected_version} 实例: ${instance_name}" "SUCCESS"
    return 0
}


# 下载Fabric核心
download_fabric() {
    local version=$1
    local install_dir=$2

    log "正在下载Fabric ${version}..." "INFO"
    
    # 获取Loader和Installer版本
    local loader_version=$(curl -fsSL "https://meta.fabricmc.net/v2/versions/loader" | jq -r '.[0].version')
    local installer_version=$(curl -fsSL "https://meta.fabricmc.net/v2/versions/installer" | jq -r '.[0].version')
    
    # 下载服务器jar
    local download_url="https://meta.fabricmc.net/v2/versions/loader/${version}/${loader_version}/${installer_version}/server/jar"
    
    if ! wget --show-progress --progress=bar:force -q -O "${install_dir}/server.jar" "$download_url"; then
        log "Fabric核心下载失败: ${download_url}" "ERROR"
        return 1
    fi

    log "Fabric ${version} 下载成功" "SUCCESS"
    return 0
}

# 下载Spigot核心
download_spigot() {
    local version=$1
    local install_dir=$2

    log "正在获取Spigot ${version}下载链接..." "INFO"
    
    # 创建临时目录
    mkdir -p "$TEMP_DIR"
    
    # 尝试从cdn.getbukkit.org直接下载
    local direct_url="https://cdn.getbukkit.org/spigot/spigot-${version}.jar"
    log "尝试直接下载: ${direct_url}" "INFO"
    
    if wget --show-progress -q -O "${TEMP_DIR}/spigot-${version}.jar" "$direct_url"; then
        # 验证文件大小
        if [ $(stat -c%s "${TEMP_DIR}/spigot-${version}.jar") -gt 1000000 ]; then
            log "直接下载成功！" "SUCCESS"
            mv "${TEMP_DIR}/spigot-${version}.jar" "${install_dir}/server.jar"
            
            # 记录版本信息
            save_download_info "$version" "$direct_url" "cdn.getbukkit.org" "$install_dir"
            return 0
        fi
    fi
    
    # 直接下载失败，尝试通过getbukkit.org获取动态链接
    log "直接下载失败，尝试获取动态链接..." "WARN"
    
    local download_page
    if ! download_page=$(curl -s "https://getbukkit.org/download/spigot"); then
        log "无法访问getbukkit.org" "ERROR"
        return 1
    fi
    
    # 提取动态下载链接
    local dynamic_url=$(echo "$download_page" | grep -oP "href=\"https://getbukkit.org/get/[^\"]+\"" | grep -oP "https://[^\"]+" | head -1)
    
    if [ -z "$dynamic_url" ]; then
        log "无法找到动态下载链接" "ERROR"
        return 1
    fi
    
    log "获取到动态链接: ${dynamic_url}" "INFO"
    
    # 从动态链接获取实际下载URL
    local redirect_page
    if ! redirect_page=$(curl -s "$dynamic_url"); then
        log "无法访问动态下载页面" "ERROR"
        return 1
    fi
    
    local actual_url=$(echo "$redirect_page" | grep -oP "href=\"https://cdn.getbukkit.org/spigot/spigot-${version}.jar\"" | grep -oP "https://[^\"]+")
    
    if [ -z "$actual_url" ]; then
        log "无法从动态页面解析实际下载链接" "ERROR"
        return 1
    fi
    
    log "实际下载URL: ${actual_url}" "INFO"
    
    # 下载文件
    if ! wget --show-progress -q -O "${TEMP_DIR}/spigot-${version}.jar" "$actual_url"; then
        log "Spigot下载失败！" "ERROR"
        return 1
    fi
    
    # 验证文件大小
    if [ $(stat -c%s "${TEMP_DIR}/spigot-${version}.jar") -lt 1000000 ]; then
        log "下载的文件过小，可能下载失败" "ERROR"
        return 1
    fi
    
    # 移动文件到目标位置
    mv "${TEMP_DIR}/spigot-${version}.jar" "${install_dir}/server.jar"
    
    # 记录版本信息
    save_download_info "$version" "$actual_url" "getbukkit.org" "$install_dir"

    log "Spigot ${version} 下载完成！" "SUCCESS"
    return 0
}

# 下载Paper核心
download_paper() {
    local version=$1
    local install_dir=$2

    log "正在下载PaperMC ${version}..." "INFO"
    
    # 获取最新构建版本号
    local build_info=$(curl -fsSL "https://papermc.io/api/v2/projects/paper/versions/${version}")
    local latest_build=$(echo "$build_info" | jq -r '.builds[-1]')
    
    if [ -z "$latest_build" ]; then
        log "无法获取PaperMC ${version}的最新构建版本" "ERROR"
        return 1
    fi
    
    local download_url="https://papermc.io/api/v2/projects/paper/versions/${version}/builds/${latest_build}/downloads/paper-${version}-${latest_build}.jar"
    
    if ! wget --show-progress --progress=bar:force -q -O "${install_dir}/server.jar" "$download_url"; then
        log "PaperMC下载失败: ${download_url}" "ERROR"
        return 1
    fi

    # 验证文件大小
    if [ $(stat -c%s "${install_dir}/server.jar") -lt 1000000 ]; then
        log "下载的PaperMC文件过小，可能损坏" "ERROR"
        return 1
    fi

    # 记录版本信息
    save_download_info "${version}-${latest_build}" "$download_url" "papermc.io" "$install_dir"
    
    log "PaperMC ${version} 构建#${latest_build} 下载成功" "SUCCESS"
    return 0
}

# 下载Forge核心
download_forge() {
    local version=$1
    local install_dir=$2

    log "正在下载 Forge 服务端..." "INFO"
    


    # 构建下载URL
    local filename="forge-${forge_version}"
    local download_url="https://maven.minecraftforge.net/net/minecraftforge/forge/${forge_version}/${filename}-installer.jar"

    # 下载安装器
    log "正在下载 Forge 安装器 (${forge_version})..." "INFO"
    if ! wget --show-progress -q -O "${TEMP_DIR}/forge-installer.jar" "$download_url"; then
        log "Forge 安装器下载失败" "ERROR"
        return 1
    fi

    # 安装服务端
    log "正在安装 Forge 服务端..." "INFO"
    (
        cd "$install_dir" || exit 1
        java -jar "${TEMP_DIR}/forge-installer.jar" --installServer
        rm -f "${TEMP_DIR}/forge-installer.jar"

        local forge_jar=$(ls "${install_dir}" | grep -E "forge-.*\.jar")
        if [ -z "$forge_jar" ]; then
            log "Forge 服务端安装失败" "ERROR"
            return 1
        fi
    )

    log "Forge ${forge_version} 安装成功" "SUCCESS"
    return 0
}

# 下载Vanilla核心
download_vanilla() {
    local version=$1
    local install_dir=$2

    log "正在下载Vanilla ${version}..." "INFO"
    
    local manifest=$(curl -fsSL "https://launchermeta.mojang.com/mc/game/version_manifest.json")
    local version_url=$(echo "$manifest" | jq -r ".versions[] | select(.id == \"${version}\") | .url")
    
    if [ -z "$version_url" ]; then
        dialog --msgbox "无法找到Vanilla ${version}版本" 10 50
        return 1
    fi
    
    local download_url=$(curl -fsSL "$version_url" | jq -r ".downloads.server.url")
    
    if ! wget --show-progress -q -O "${install_dir}/server.jar" "$download_url"; then
        log "Vanilla核心下载失败" "ERROR"
        return 1
    fi
    
    log "Vanilla ${version} 下载完成" "SUCCESS"
    return 0
}

# 下载Bedrock核心
download_bedrock() {
    local version=$1
    local install_dir=$2

    log "正在下载Bedrock Server ${version}..." "INFO"
    
    # 获取最新Bedrock服务器下载链接
    local download_page=$(curl -fsSL "https://www.minecraft.net/zh-hans/download/server/bedrock")
    local download_url=$(echo "$download_page" | grep -oP "https://[^\"]+/bin-linux/[^\"]+")
    
    if [ -z "$download_url" ]; then
        dialog --msgbox "无法获取Bedrock服务器下载链接" 10 50
        return 1
    fi
    
    # 下载并解压
    if ! wget --show-progress -q -O "${TEMP_DIR}/bedrock.zip" "$download_url"; then
        log "Bedrock服务器下载失败" "ERROR"
        return 1
    fi
    
    unzip -q "${TEMP_DIR}/bedrock.zip" -d "$install_dir"
    rm -f "${TEMP_DIR}/bedrock.zip"
    
    # 确保可执行权限
    chmod +x "${install_dir}/bedrock_server"
    
    log "Bedrock服务器安装完成" "SUCCESS"
    return 0
}

# 生成启动脚本
generate_start_script() {
    local install_dir=$1
    local core_name=$2
    
    # Bedrock服务器使用不同的启动脚本
    if [[ "$core_name" == "Bedrock" ]]; then
        cat > "${install_dir}/start.sh" <<EOF
#!/bin/bash
# Bedrock服务器启动脚本
# 自动生成于 $(date)

# 启动服务器
./bedrock_server
EOF
    else
        cat > "${install_dir}/start.sh" <<EOF
#!/bin/bash
# Minecraft服务器启动脚本
# 自动生成于 $(date)

# 基本JVM参数
JAVA_ARGS="-Xms2G -Xmx4G -XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 -XX:+UnlockExperimentalVMOptions"
JAVA_ARGS="\${JAVA_ARGS} -XX:+DisableExplicitGC -XX:+AlwaysPreTouch -XX:G1HeapWastePercent=5 -XX:G1MixedGCCountTarget=4"
JAVA_ARGS="\${JAVA_ARGS} -XX:G1MixedGCLiveThresholdPercent=90 -XX:G1RSetUpdatingPauseTimePercent=5 -XX:SurvivorRatio=32"
JAVA_ARGS="\${JAVA_ARGS} -XX:+PerfDisableSharedMem -XX:MaxTenuringThreshold=1 -XX:G1NewSizePercent=30 -XX:G1MaxNewSizePercent=40"
JAVA_ARGS="\${JAVA_ARGS} -XX:InitiatingHeapOccupancyPercent=15 -XX:G1HeapRegionSize=8M -XX:G1ReservePercent=20"
JAVA_ARGS="\${JAVA_ARGS} -Dusing.aikars.flags=https://mcflags.emc.gs"

# 启动服务器
java \$JAVA_ARGS -jar server.jar nogui
EOF
    fi

    chmod +x "${install_dir}/start.sh"
}

# 生成服务器配置文件
generate_server_properties() {
    local install_dir=$1
    local core_name=$2
    
    # Bedrock服务器使用不同的配置文件
    if [[ "$core_name" == "Bedrock" ]]; then
        if [ ! -f "${install_dir}/server.properties" ]; then
            cat > "${install_dir}/server.properties" <<EOF
# Bedrock服务器配置
server-name=Dedicated Server
gamemode=survival
difficulty=easy
allow-cheats=false
max-players=10
online-mode=true
white-list=false
server-port=19132
server-portv6=19133
view-distance=10
tick-distance=4
player-idle-timeout=30
max-threads=8
level-name=Bedrock level
level-seed=
default-player-permission-level=member
texturepack-required=false
content-log-file-enabled=false
EOF
        fi
        return
    fi
    
    # 首次运行生成默认配置
    if [ ! -f "${install_dir}/server.properties" ]; then
        (
            cd "${install_dir}"
            timeout 10s java -jar server.jar --nogui >/dev/null 2>&1 || true
        )
    fi

    # 确保server.properties存在
    if [ ! -f "${install_dir}/server.properties" ]; then
        cat > "${install_dir}/server.properties" <<EOF
#Minecraft server properties
#$(date)
enable-jmx-monitoring=false
rcon.port=25575
level-seed=
gamemode=survival
enable-command-block=false
enable-query=false
generator-settings={}
level-name=world
motd=A Minecraft Server
query.port=25565
pvp=true
generate-structures=true
difficulty=easy
network-compression-threshold=256
max-tick-time=60000
require-resource-pack=false
use-native-transport=true
max-players=20
online-mode=false
enable-status=true
allow-flight=false
broadcast-rcon-to-ops=true
view-distance=10
server-ip=
resource-pack-prompt=
allow-nether=true
server-port=25565
enable-rcon=false
sync-chunk-writes=true
op-permission-level=4
prevent-proxy-connections=false
hide-online-players=false
resource-pack=
entity-broadcast-range-percentage=100
simulation-distance=10
rcon.password=
player-idle-timeout=0
debug=false
force-gamemode=false
rate-limit=0
hardcore=false
white-list=false
broadcast-console-to-ops=true
spawn-npcs=true
spawn-animals=true
function-permission-level=2
level-type=default
text-filtering-config=
spawn-monsters=true
enforce-whitelist=false
spawn-protection=16
resource-pack-sha1=
max-world-size=29999984
EOF
else
# 确保关闭正版验证
sed -i 's/^online-mode=.*/online-mode=false/' "${install_dir}/server.properties"
fi
}

#生成实例配置文件

generate_instance_config() {
local core_type=$1
local version=$2
local instance_name=$3
local install_dir=$4

cat > "${install_dir}/instance.cfg" <<EOF

Minecraft实例配置

生成于 $(date)

core_type=${core_type}
mc_version=${version}
instance_name=${instance_name}
java_version=${JAVA_REQUIRED}
install_time=$(date +%FT%T%z)
last_updated=$(date +%FT%T%z)

启动参数

min_ram=2G
max_ram=4G
jvm_args="-XX:+UseG1GC -XX:+ParallelRefProcEnabled"

网络设置

server_port=25565
online_mode=false
max_players=20

其他设置

auto_restart=false
backup_enabled=true
EOF
}

#保存下载信息

save_download_info() {
local version=$1
local url=$2
local source=$3
local install_dir=$4

cat > "${install_dir}/download_info.json" <<EOF

{
"version": "${version}",
"source": "${source}",
"download_url": "${url}",
"download_time": "$(date +%FT%T%z)",
"file_size": "$(du -h "${install_dir}/server.jar" | cut -f1)",
"sha256": "$(sha256sum "${install_dir}/server.jar" | cut -d' ' -f1)"
}
EOF
}

#列出已安装实例

list_instances() {
local instances=($(get_instance_list))

if [ ${#instances[@]} -eq 0 ]; then
    dialog --msgbox "没有找到已安装的服务器实例" 8 40
    return
fi

local instance_info=()
for instance in "${instances[@]}"; do
    local install_dir="${VERSIONS_DIR}/${instance}"
    if [ -f "${install_dir}/instance.cfg" ]; then
        source "${install_dir}/instance.cfg"
        instance_info+=("$instance" "版本: $mc_version | 端口: $server_port")
    else
        instance_info+=("$instance" "信息缺失")
    fi
done

dialog --menu "已安装的服务器实例" 20 60 12 "${instance_info[@]}" 2>&1 >/dev/tty

}



#主入口

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
install_menu
fi
