#!/usr/bin/env python3
# AetherCraft - 插件模块
# 作者: B站@爱做视频のJack_Eason
# 版本: 3.4
# 日期: 2025-06-29

import os
import sys
import json
import time
import shutil
import requests
import tempfile
import subprocess
from pathlib import Path
import dialog

# ==================== 全局配置 ====================
ROOT_DIR = str(Path.home())
VERSIONS_DIR = os.path.join(ROOT_DIR, "versions")
BACKUP_DIR = os.path.join(ROOT_DIR, "backups")
TEMP_DIR = os.path.join(ROOT_DIR, "temp")
LOG_DIR = os.path.join(ROOT_DIR, "logs")

# 插件源配置
PLUGIN_SOURCES = {
    "Geyser": [
        ("官方镜像", "https://download.geysermc.org/v2/projects/geyser/versions/latest/builds/latest/downloads/spigot"),
        ("GitHub", "https://github.com/GeyserMC/Geyser/releases/latest/download/Geyser-Spigot.jar")
    ],
    "Floodgate": [
        ("官方镜像", "https://download.geysermc.org/v2/projects/floodgate/versions/latest/builds/latest/downloads/spigot"),
        ("GitHub", "https://github.com/GeyserMC/Floodgate/releases/latest/download/floodgate-spigot.jar")
    ],
    "ViaVersion": [
        ("SpigotMC", "https://www.spigotmc.org/resources/viaversion.19254/download?version=476915"),
        ("GitHub", "https://github.com/ViaVersion/ViaVersion/releases/latest/download/ViaVersion-4.8.1.jar")
    ],
    "EssentialsX": [
        ("Jenkins", "https://ci.ender.zone/job/EssentialsX/job/EssentialsX/lastSuccessfulBuild/artifact/jars/EssentialsX-2.20.0.jar"),
        ("GitHub", "https://github.com/EssentialsX/Essentials/releases/latest/download/EssentialsX-2.20.0.jar")
    ],
    "LuckPerms": [
        ("Modrinth", "https://cdn.modrinth.com/data/1w4d5N5O/versions/5.4.87/LuckPerms-Bukkit-5.4.87.jar"),
        ("GitHub", "https://github.com/LuckPerms/LuckPerms/releases/latest/download/LuckPerms-Bukkit-5.4.87.jar")
    ]
}

PLUGIN_DESCRIPTIONS = {
    "Geyser": "基岩版互通组件",
    "Floodgate": "基岩版玩家支持",
    "ViaVersion": "跨版本兼容",
    "EssentialsX": "基础功能套件",
    "LuckPerms": "权限管理系统"
}

# ==================== 工具函数 ====================
def log(message, level="INFO"):
    """记录日志"""
    timestamp = time.strftime("%Y-%m-%d %H:%M:%S")
    print(f"[{timestamp}] [{level}] {message}")

def get_instance_list():
    """获取服务器实例列表"""
    if not os.path.exists(VERSIONS_DIR):
        return []
    return [d for d in os.listdir(VERSIONS_DIR) 
            if os.path.isdir(os.path.join(VERSIONS_DIR, d))]

def check_server_status(instance):
    """检查服务器运行状态"""
    instance_dir = os.path.join(VERSIONS_DIR, instance)
    pid_file = os.path.join(instance_dir, "server.pid")
    
    if os.path.exists(pid_file):
        with open(pid_file) as f:
            pid = f.read().strip()
        try:
            subprocess.check_output(["ps", "-p", pid])
            return True
        except:
            return False
    return False

def restart_instance(instance):
    """重启服务器实例"""
    instance_dir = os.path.join(VERSIONS_DIR, instance)
    stop_script = os.path.join(instance_dir, "stop.sh")
    start_script = os.path.join(instance_dir, "start.sh")
    
    if check_server_status(instance) and os.path.exists(stop_script):
        subprocess.run([stop_script], cwd=instance_dir)
        time.sleep(5)
    
    if os.path.exists(start_script):
        subprocess.Popen([start_script], cwd=instance_dir)
        return True
    return False

# ==================== 对话框工具 ====================
d = dialog.Dialog(dialog="dialog")
d.set_background_title("AetherCraft 插件管理")

def show_msg(title, text, height=10, width=60):
    """显示消息对话框"""
    d.msgbox(text, title=title, height=height, width=width)

def show_error(text):
    """显示错误消息"""
    d.msgbox(text, title="错误", colors=True, ok_label="返回")

def show_yesno(title, text):
    """显示确认对话框"""
    return d.yesno(text, title=title) == d.OK

def show_menu(title, choices, height=15, width=60):
    """显示选择菜单"""
    code, choice = d.menu(title, choices=choices, height=height, width=width)
    return choice if code == d.OK else None

# ==================== 插件操作 ====================
def download_plugin(plugin, instance, plugins_dir):
    """下载插件 (无进度条版本)"""
    sources = PLUGIN_SOURCES.get(plugin, [])
    if not sources:
        show_error(f"插件 {plugin} 无可用下载源")
        return
    
    # 选择下载源
    source = show_menu(
        f"选择 {plugin} 下载源",
        [(src[0], "") for src in sources] + [("取消", "")]
    )
    if not source or source == "取消":
        return
    
    url = next(src[1] for src in sources if src[0] == source)
    temp_file = os.path.join(TEMP_DIR, f"{plugin}.tmp")
    os.makedirs(TEMP_DIR, exist_ok=True)
    
    try:
        show_msg("下载插件", f"回车下载 {plugin}...\n来源: {source}\nURL: {url}")
        
        # 直接下载文件
        response = requests.get(url, stream=True, timeout=30)
        response.raise_for_status()
        
        with open(temp_file, 'wb') as f:
            for chunk in response.iter_content(chunk_size=8192):
                f.write(chunk)
        
        # 验证文件
        if os.path.getsize(temp_file) < 10240:  # 至少10KB
            raise ValueError("下载文件过小，可能损坏")
        
        # 安装到插件目录
        target = os.path.join(plugins_dir, f"{plugin}.jar")
        if os.path.exists(target):
            os.remove(target)
        shutil.move(temp_file, target)
        
        # 记录安装日志
        with open(os.path.join(plugins_dir, "install.log"), "a") as f:
            f.write(json.dumps({
                "plugin": plugin,
                "url": url,
                "time": time.strftime("%Y-%m-%d %H:%M:%S")
            }) + "\n")
        
        show_msg("成功", f"插件 {plugin} 安装成功！")
        
        # 提示重启
        if check_server_status(instance) and show_yesno("提示", "需要重启服务器使插件生效。立即重启吗？"):
            restart_instance(instance)
            
    except Exception as e:
        show_error(f"下载失败: {str(e)}")
    finally:
        if os.path.exists(temp_file):
            os.remove(temp_file)

def toggle_plugin(plugin, plugins_dir, instance):
    """启用/禁用插件"""
    src = os.path.join(plugins_dir, plugin["file"])
    dst = src.replace(".disabled", "") if plugin["file"].endswith(".disabled") else src + ".disabled"
    
    try:
        os.rename(src, dst)
        action = "启用" if plugin["file"].endswith(".disabled") else "禁用"
        show_msg("成功", f"已{action}插件 {plugin['name']}")
        
        if check_server_status(instance) and show_yesno("提示", "需要重启服务器使更改生效。立即重启吗？"):
            restart_instance(instance)
    except Exception as e:
        show_error(f"操作失败: {str(e)}")

def delete_plugin(plugin, plugins_dir, instance):
    """删除插件"""
    if not show_yesno("警告", f"确定要永久删除插件 {plugin['name']} 吗？"):
        return
    
    try:
        os.remove(os.path.join(plugins_dir, plugin["file"]))
        show_msg("成功", f"插件 {plugin['name']} 已删除")
        
        if check_server_status(instance) and show_yesno("提示", "需要重启服务器使更改生效。立即重启吗？"):
            restart_instance(instance)
    except Exception as e:
        show_error(f"删除失败: {str(e)}")

# ==================== 菜单系统 ====================
def plugin_market():
    """插件市场 (开发中)"""
    show_msg("插件市场", "该功能正在开发中...")

def update_plugins():
    """插件更新 (开发中)"""
    show_msg("插件更新", "该功能正在开发中...")

def install_plugins_menu():
    """插件安装菜单"""
    instances = get_instance_list()
    if not instances:
        show_error("没有可用的服务器实例！")
        return
    
    instance = show_menu("选择目标实例", [(i, "") for i in instances] + [("返回", "")])
    if not instance or instance == "返回":
        return
    
    # 确定插件目录
    core_type = instance.split("-")[0]
    plugins_dir = os.path.join(VERSIONS_DIR, instance, "mods" if core_type in ["Fabric", "Forge"] else "plugins")
    os.makedirs(plugins_dir, exist_ok=True)
    
    # 选择插件
    plugin = show_menu(
        "选择插件",
        [(p, PLUGIN_DESCRIPTIONS.get(p, "")) for p in PLUGIN_SOURCES.keys()] + [("返回", "")]
    )
    if not plugin or plugin == "返回":
        return
    
    download_plugin(plugin, instance, plugins_dir)

def manage_plugins_menu():
    """插件管理菜单"""
    instances = get_instance_list()
    if not instances:
        show_error("没有可用的服务器实例！")
        return
    
    instance = show_menu("选择实例", [(i, "") for i in instances] + [("返回", "")])
    if not instance or instance == "返回":
        return
    
    # 获取插件列表
    core_type = instance.split("-")[0]
    plugins_dir = os.path.join(VERSIONS_DIR, instance, "mods" if core_type in ["Fabric", "Forge"] else "plugins")
    if not os.path.exists(plugins_dir):
        show_error("该实例没有插件目录！")
        return
    
    plugins = []
    for f in os.listdir(plugins_dir):
        if f.endswith((".jar", ".jar.disabled")):
            name = os.path.splitext(f)[0]
            if name.endswith(".jar"):
                name = os.path.splitext(name)[0]
            plugins.append({
                "name": name,
                "file": f,
                "enabled": not f.endswith(".disabled")
            })
    
    if not plugins:
        show_error("没有找到插件！")
        return
    
    # 插件操作循环
    while True:
        plugin = show_menu(
            f"管理插件 - {instance}",
            [(f"{p['name']} [{'启用' if p['enabled'] else '禁用'}]", "") for p in plugins] + [("返回", "")]
        )
        if not plugin or plugin == "返回":
            break
        
        # 找到选中的插件
        plugin_data = next(p for p in plugins if p["name"] in plugin)
        
        while True:
            action = show_menu(
                f"插件操作 - {plugin_data['name']}",
                [
                    ("查看信息", ""),
                    ("启用" if not plugin_data["enabled"] else "禁用", ""),
                    ("删除", ""),
                    ("返回", "")
                ]
            )
            if not action or action == "返回":
                break
            
            if action == "查看信息":
                info = f"插件名称: {plugin_data['name']}\n"
                info += f"文件大小: {os.path.getsize(os.path.join(plugins_dir, plugin_data['file'])) // 1024} KB\n"
                info += f"状态: {'启用' if plugin_data['enabled'] else '禁用'}"
                show_msg("插件信息", info)
            elif "启用" in action or "禁用" in action:
                toggle_plugin(plugin_data, plugins_dir, instance)
                break  # 刷新列表
            elif action == "删除":
                delete_plugin(plugin_data, plugins_dir, instance)
                break  # 刷新列表

def main_menu():
    """主菜单"""
    while True:
        choice = show_menu(
            "AetherCraft 插件管理",
            [
                ("1", "安装插件"),
                ("2", "管理插件"),
                ("3", "插件市场"),
                ("4", "更新插件"),
                ("5", "退出")
            ]
        )
        if not choice:
            break
            
        if choice == "1":
            install_plugins_menu()
        elif choice == "2":
            manage_plugins_menu()
        elif choice == "3":
            plugin_market()
        elif choice == "4":
            update_plugins()
        elif choice == "5":
            break

# ==================== 主程序 ====================
if __name__ == "__main__":
    # 初始化目录
    os.makedirs(VERSIONS_DIR, exist_ok=True)
    os.makedirs(BACKUP_DIR, exist_ok=True)
    os.makedirs(TEMP_DIR, exist_ok=True)
    os.makedirs(LOG_DIR, exist_ok=True)
    
    try:
        main_menu()
    except Exception as e:
        show_error(f"程序发生错误:\n{str(e)}")
    finally:
        d.clear()
        sys.exit(0)
