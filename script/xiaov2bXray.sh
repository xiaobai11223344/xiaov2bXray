#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}错误�?{plain} 必须使用root用户运行此脚本！\n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "alpine"; then
    release="alpine"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat|rocky|alma|oracle linux"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat|rocky|alma|oracle linux"; then
    release="centos"
elif cat /proc/version | grep -Eqi "arch"; then
    release="arch"
else
    echo -e "${red}未检测到系统版本，请联系脚本作者！${plain}\n" && exit 1
fi

arch=$(uname -m)

if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
    arch="64"
elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
    arch="arm64-v8a"
elif [[ $arch == "s390x" ]]; then
    arch="s390x"
else
    arch="64"
    echo -e "${red}检测架构失败，使用默认架构: ${arch}${plain}"
fi

if [ "$(getconf WORD_BIT)" != '32' ] && [ "$(getconf LONG_BIT)" != '64' ] ; then
    echo "本软件不支持 32 位系�?x86)，请使用 64 位系�?x86_64)，如果检测有误，请联系作�?
    exit 2
fi

# os version
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        echo -e "${red}请使�?CentOS 7 或更高版本的系统�?{plain}\n" && exit 1
    fi
    if [[ ${os_version} -eq 7 ]]; then
        echo -e "${red}注意�?CentOS 7 无法使用hysteria1/2协议�?{plain}\n"
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}请使�?Ubuntu 16 或更高版本的系统�?{plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}请使�?Debian 8 或更高版本的系统�?{plain}\n" && exit 1
    fi
fi

confirm() {
    if [[ $# > 1 ]]; then
        echo && read -rp "$1 [默认$2]: " temp
        if [[ x"${temp}" == x"" ]]; then
            temp=$2
        fi
    else
        read -rp "$1 [y/n]: " temp
    fi
    if [[ x"${temp}" == x"y" || x"${temp}" == x"Y" ]]; then
        return 0
    else
        return 1
    fi
}

confirm_restart() {
    confirm "是否重启xiaov2bXray" "y"
    if [[ $? == 0 ]]; then
        restart
    else
        show_menu
    fi
}

before_show_menu() {
    echo && echo -n -e "${yellow}按回车返回主菜单: ${plain}" && read temp
    show_menu
}

install() {
    bash <(curl -Ls https://raw.githubusercontent.com/wyx2685/xiaov2bXray/master/script/install.sh)
    if [[ $? == 0 ]]; then
        if [[ $# == 0 ]]; then
            start
        else
            start 0
        fi
    fi
}

update() {
    if [[ $# == 0 ]]; then
        echo && echo -n -e "输入指定版本(默认最新版): " && read version
    else
        version=$2
    fi
    bash <(curl -Ls https://raw.githubusercontent.com/wyx2685/xiaov2bXray/master/script/install.sh) $version
    if [[ $? == 0 ]]; then
        echo -e "${green}更新完成，已自动重启 xiaov2bXray，请使用 xiaov2bXray log 查看运行日志${plain}"
        exit
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

config() {
    echo "xiaov2bXray在修改配置后会自动尝试重�?
    vi /etc/xiaov2bXray/config.json
    sleep 2
    restart
    check_status
    case $? in
        0)
            echo -e "xiaov2bXray状�? ${green}已运�?{plain}"
            ;;
        1)
            echo -e "检测到您未启动xiaov2bXray或v2node自动重启失败，是否查看日志？[Y/n]" && echo
            read -e -rp "(默认: y):" yn
            [[ -z ${yn} ]] && yn="y"
            if [[ ${yn} == [Yy] ]]; then
               show_log
            fi
            ;;
        2)
            echo -e "xiaov2bXray状�? ${red}未安�?{plain}"
    esac
}

uninstall() {
    confirm "确定要卸�?xiaov2bXray �?" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    if [[ x"${release}" == x"alpine" ]]; then
        service xiaov2bXray stop
        rc-update del xiaov2bXray
        rm /etc/init.d/xiaov2bXray -f
    else
        systemctl stop xiaov2bXray
        systemctl disable xiaov2bXray
        rm /etc/systemd/system/xiaov2bXray.service -f
        systemctl daemon-reload
        systemctl reset-failed
    fi
    rm /etc/xiaov2bXray/ -rf
    rm /usr/local/xiaov2bXray/ -rf

    echo ""
    echo -e "卸载成功，如果你想删除此脚本，则退出脚本后运行 ${green}rm /usr/bin/xiaov2bXray -f${plain} 进行删除"
    echo ""

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

start() {
    check_status
    if [[ $? == 0 ]]; then
        echo ""
        echo -e "${green}xiaov2bXray已运行，无需再次启动，如需重启请选择重启${plain}"
    else
        if [[ x"${release}" == x"alpine" ]]; then
            service xiaov2bXray start
        else
            systemctl start xiaov2bXray
        fi
        sleep 2
        check_status
        if [[ $? == 0 ]]; then
            echo -e "${green}xiaov2bXray 启动成功，请使用 xiaov2bXray log 查看运行日志${plain}"
        else
            echo -e "${red}xiaov2bXray可能启动失败，请稍后使用 xiaov2bXray log 查看日志信息${plain}"
        fi
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

stop() {
    if [[ x"${release}" == x"alpine" ]]; then
        service xiaov2bXray stop
    else
        systemctl stop xiaov2bXray
    fi
    sleep 2
    check_status
    if [[ $? == 1 ]]; then
        echo -e "${green}xiaov2bXray 停止成功${plain}"
    else
        echo -e "${red}xiaov2bXray停止失败，可能是因为停止时间超过了两秒，请稍后查看日志信�?{plain}"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

restart() {
    if [[ x"${release}" == x"alpine" ]]; then
        service xiaov2bXray restart
    else
        systemctl restart xiaov2bXray
    fi
    sleep 2
    check_status
    if [[ $? == 0 ]]; then
        echo -e "${green}xiaov2bXray 重启成功，请使用 xiaov2bXray log 查看运行日志${plain}"
    else
        echo -e "${red}xiaov2bXray可能启动失败，请稍后使用 xiaov2bXray log 查看日志信息${plain}"
    fi
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

status() {
    if [[ x"${release}" == x"alpine" ]]; then
        service xiaov2bXray status
    else
        systemctl status xiaov2bXray --no-pager -l
    fi
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

enable() {
    if [[ x"${release}" == x"alpine" ]]; then
        rc-update add xiaov2bXray
    else
        systemctl enable xiaov2bXray
    fi
    if [[ $? == 0 ]]; then
        echo -e "${green}xiaov2bXray 设置开机自启成�?{plain}"
    else
        echo -e "${red}xiaov2bXray 设置开机自启失�?{plain}"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

disable() {
    if [[ x"${release}" == x"alpine" ]]; then
        rc-update del xiaov2bXray
    else
        systemctl disable xiaov2bXray
    fi
    if [[ $? == 0 ]]; then
        echo -e "${green}xiaov2bXray 取消开机自启成�?{plain}"
    else
        echo -e "${red}xiaov2bXray 取消开机自启失�?{plain}"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

show_log() {
    if [[ x"${release}" == x"alpine" ]]; then
        echo -e "${red}alpine系统暂不支持日志查看${plain}\n" && exit 1
    else
        journalctl -u xiaov2bXray.service -e --no-pager -f
    fi
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

update_shell() {
    wget -O /usr/bin/xiaov2bXray -N --no-check-certificate https://raw.githubusercontent.com/wyx2685/xiaov2bXray/master/script/xiaov2bXray.sh
    if [[ $? != 0 ]]; then
        echo ""
        echo -e "${red}下载脚本失败，请检查本机能否连�?Github${plain}"
        before_show_menu
    else
        chmod +x /usr/bin/xiaov2bXray
        echo -e "${green}升级脚本成功，请重新运行脚本${plain}" && exit 0
    fi
}

# 0: running, 1: not running, 2: not installed
check_status() {
    if [[ ! -f /usr/local/xiaov2bXray/xiaov2bXray ]]; then
        return 2
    fi
    if [[ x"${release}" == x"alpine" ]]; then
        temp=$(service xiaov2bXray status | awk '{print $3}')
        if [[ x"${temp}" == x"started" ]]; then
            return 0
        else
            return 1
        fi
    else
        temp=$(systemctl status xiaov2bXray | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
        if [[ x"${temp}" == x"running" ]]; then
            return 0
        else
            return 1
        fi
    fi
}

check_enabled() {
    if [[ x"${release}" == x"alpine" ]]; then
        temp=$(rc-update show | grep xiaov2bXray)
        if [[ x"${temp}" == x"" ]]; then
            return 1
        else
            return 0
        fi
    else
        temp=$(systemctl is-enabled xiaov2bXray)
        if [[ x"${temp}" == x"enabled" ]]; then
            return 0
        else
            return 1;
        fi
    fi
}

check_uninstall() {
    check_status
    if [[ $? != 2 ]]; then
        echo ""
        echo -e "${red}xiaov2bXray已安装，请不要重复安�?{plain}"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

check_install() {
    check_status
    if [[ $? == 2 ]]; then
        echo ""
        echo -e "${red}请先安装xiaov2bXray${plain}"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

show_status() {
    check_status
    case $? in
        0)
            echo -e "xiaov2bXray状�? ${green}已运�?{plain}"
            show_enable_status
            ;;
        1)
            echo -e "xiaov2bXray状�? ${yellow}未运�?{plain}"
            show_enable_status
            ;;
        2)
            echo -e "xiaov2bXray状�? ${red}未安�?{plain}"
    esac
}

show_enable_status() {
    check_enabled
    if [[ $? == 0 ]]; then
        echo -e "是否开机自�? ${green}�?{plain}"
    else
        echo -e "是否开机自�? ${red}�?{plain}"
    fi
}

show_xiaov2bXray_version() {
    echo -n "xiaov2bXray 版本�?
    /usr/local/xiaov2bXray/xiaov2bXray version
    echo ""
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

generate_xiaov2bXray_config() {
        local api_host="$1"
        local node_id="$2"
        local api_key="$3"

        mkdir -p /etc/xiaov2bXray >/dev/null 2>&1
        cat > /etc/xiaov2bXray/config.json <<EOF
{
    "Log": {
        "Level": "warning",
        "Output": "",
        "Access": "none"
    },
    "Nodes": [
        {
            "ApiHost": "${api_host}",
            "NodeID": ${node_id},
            "ApiKey": "${api_key}",
            "Timeout": 15
        }
    ]
}
EOF
        echo -e "${green}xiaov2bXray 配置文件生成完成,正在重新启动服务${plain}"
        if [[ x"${release}" == x"alpine" ]]; then
            service xiaov2bXray restart
        else
            systemctl restart xiaov2bXray
        fi
        sleep 2
        check_status
        echo -e ""
        if [[ $? == 0 ]]; then
            echo -e "${green}xiaov2bXray 重启成功${plain}"
        else
            echo -e "${red}xiaov2bXray 可能启动失败，请使用 xiaov2bXray log 查看日志信息${plain}"
        fi
}


generate_config_file() {
    # 交互式收集参数，提供示例默认�?    read -rp "面板API地址[格式: https://example.com/]: " api_host
    api_host=${api_host:-https://example.com/}
    read -rp "节点ID: " node_id
    node_id=${node_id:-1}
    read -rp "节点通讯密钥: " api_key

    # 生成配置文件（覆盖可能从包中复制的模板）
    generate_xiaov2bXray_config "$api_host" "$node_id" "$api_key"
}

# 放开防火墙端�?open_ports() {
    systemctl stop firewalld.service 2>/dev/null
    systemctl disable firewalld.service 2>/dev/null
    setenforce 0 2>/dev/null
    ufw disable 2>/dev/null
    iptables -P INPUT ACCEPT 2>/dev/null
    iptables -P FORWARD ACCEPT 2>/dev/null
    iptables -P OUTPUT ACCEPT 2>/dev/null
    iptables -t nat -F 2>/dev/null
    iptables -t mangle -F 2>/dev/null
    iptables -F 2>/dev/null
    iptables -X 2>/dev/null
    netfilter-persistent save 2>/dev/null
    echo -e "${green}放开防火墙端口成功！${plain}"
}

show_usage() {
    echo "xiaov2bXray 管理脚本使用方法: "
    echo "------------------------------------------"
    echo "xiaov2bXray              - 显示管理菜单 (功能更多)"
    echo "xiaov2bXray start        - 启动 xiaov2bXray"
    echo "xiaov2bXray stop         - 停止 xiaov2bXray"
    echo "xiaov2bXray restart      - 重启 xiaov2bXray"
    echo "xiaov2bXray status       - 查看 xiaov2bXray 状�?
    echo "xiaov2bXray enable       - 设置 xiaov2bXray 开机自�?
    echo "xiaov2bXray disable      - 取消 xiaov2bXray 开机自�?
    echo "xiaov2bXray log          - 查看 xiaov2bXray 日志"
    echo "xiaov2bXray x25519       - 生成 x25519 密钥"
    echo "xiaov2bXray generate     - 生成 xiaov2bXray 配置文件"
    echo "xiaov2bXray update       - 更新 xiaov2bXray"
    echo "xiaov2bXray update x.x.x - 安装 xiaov2bXray 指定版本"
    echo "xiaov2bXray install      - 安装 xiaov2bXray"
    echo "xiaov2bXray uninstall    - 卸载 xiaov2bXray"
    echo "xiaov2bXray version      - 查看 xiaov2bXray 版本"
    echo "------------------------------------------"
}

show_menu() {
    echo -e "
  ${green}xiaov2bXray 后端管理脚本�?{plain}${red}不适用于docker${plain}
--- https://github.com/wyx2685/xiaov2bXray ---
  ${green}0.${plain} 修改配置
———————————————�?  ${green}1.${plain} 安装 xiaov2bXray
  ${green}2.${plain} 更新 xiaov2bXray
  ${green}3.${plain} 卸载 xiaov2bXray
———————————————�?  ${green}4.${plain} 启动 xiaov2bXray
  ${green}5.${plain} 停止 xiaov2bXray
  ${green}6.${plain} 重启 xiaov2bXray
  ${green}7.${plain} 查看 xiaov2bXray 状�?  ${green}8.${plain} 查看 xiaov2bXray 日志
———————————————�?  ${green}9.${plain} 设置 xiaov2bXray 开机自�?  ${green}10.${plain} 取消 xiaov2bXray 开机自�?———————————————�?  ${green}11.${plain} 查看 xiaov2bXray 版本
  ${green}12.${plain} 升级 xiaov2bXray 维护脚本
  ${green}13.${plain} 生成 xiaov2bXray 配置文件
  ${green}14.${plain} 放行 VPS 的所有网络端�?  ${green}15.${plain} 退出脚�? "
 #后续更新可加入上方字符串�?    show_status
    echo && read -rp "请输入选择 [0-15]: " num

    case "${num}" in
        0) config ;;
        1) check_uninstall && install ;;
        2) check_install && update ;;
        3) check_install && uninstall ;;
        4) check_install && start ;;
        5) check_install && stop ;;
        6) check_install && restart ;;
        7) check_install && status ;;
        8) check_install && show_log ;;
        9) check_install && enable ;;
        10) check_install && disable ;;
        11) check_install && show_xiaov2bXray_version ;;
        12) update_shell ;;
        13) generate_config_file ;;
        14) open_ports ;;
        15) exit ;;
        *) echo -e "${red}请输入正确的数字 [0-15]${plain}" ;;
    esac
}


if [[ $# > 0 ]]; then
    case $1 in
        "start") check_install 0 && start 0 ;;
        "stop") check_install 0 && stop 0 ;;
        "restart") check_install 0 && restart 0 ;;
        "status") check_install 0 && status 0 ;;
        "enable") check_install 0 && enable 0 ;;
        "disable") check_install 0 && disable 0 ;;
        "log") check_install 0 && show_log 0 ;;
        "update") check_install 0 && update 0 $2 ;;
        "config") config $* ;;
        "generate") generate_config_file ;;
        "install") check_uninstall 0 && install 0 ;;
        "uninstall") check_install 0 && uninstall 0 ;;
        "version") check_install 0 && show_xiaov2bXray_version 0 ;;
        "update_shell") update_shell ;;
        *) show_usage
    esac
else
    show_menu
fi