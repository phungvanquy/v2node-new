#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}Error:${plain} This script must be run as root!\n" && exit 1

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
    echo -e "${red}Unable to detect the operating system. Please contact the script author!${plain}\n" && exit 1
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
    echo -e "${red}Unable to detect the architecture; using the default: ${arch}${plain}"
fi

if [ "$(getconf WORD_BIT)" != '32' ] && [ "$(getconf LONG_BIT)" != '64' ] ; then
    echo "This software does not support 32-bit systems (x86). Please use a 64-bit system (x86_64). Contact the author if detection is incorrect."
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
        echo -e "${red}Please use CentOS 7 or later!${plain}\n" && exit 1
    fi
    if [[ ${os_version} -eq 7 ]]; then
        echo -e "${red}Note: CentOS 7 does not support the Hysteria 1/2 protocols!${plain}\n"
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}Please use Ubuntu 16 or later!${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}Please use Debian 8 or later!${plain}\n" && exit 1
    fi
fi

confirm() {
    if [[ $# > 1 ]]; then
        echo && read -rp "$1 [default: $2]: " temp
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
    confirm "Restart v2node?" "y"
    if [[ $? == 0 ]]; then
        restart
    else
        show_menu
    fi
}

before_show_menu() {
    echo && echo -n -e "${yellow}Press Enter to return to the main menu: ${plain}" && read temp
    show_menu
}

install() {
    bash <(curl -Ls https://raw.githubusercontent.com/phungvanquy/v2node-new/main/script/install.sh)
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
        echo && echo -n -e "Enter a version (default: latest): " && read version
    else
        version=$2
    fi
    bash <(curl -Ls https://raw.githubusercontent.com/phungvanquy/v2node-new/main/script/install.sh) $version
    if [[ $? == 0 ]]; then
        echo -e "${green}Update complete. v2node has restarted automatically. Use v2node log to view the runtime logs.${plain}"
        exit
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

config() {
    echo "v2node will automatically attempt to restart after the configuration is edited"
    vi /etc/v2node/config.json
    sleep 2
    restart
    check_status
    case $? in
        0)
            echo -e "v2node status: ${green}Running${plain}"
            ;;
        1)
            echo -e "v2node is not started or failed to restart automatically. View the logs? [Y/n]" && echo
            read -e -rp "(default: y):" yn
            [[ -z ${yn} ]] && yn="y"
            if [[ ${yn} == [Yy] ]]; then
               show_log
            fi
            ;;
        2)
            echo -e "v2node status: ${red}Not installed${plain}"
    esac
}

uninstall() {
    confirm "Are you sure you want to uninstall v2node?" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    if [[ x"${release}" == x"alpine" ]]; then
        service v2node stop
        rc-update del v2node
        rm /etc/init.d/v2node -f
    else
        systemctl stop v2node
        systemctl disable v2node
        rm /etc/systemd/system/v2node.service -f
        systemctl daemon-reload
        systemctl reset-failed
    fi
    rm /etc/v2node/ -rf
    rm /usr/local/v2node/ -rf

    echo ""
    echo -e "Uninstalled successfully. To remove this script, exit and run ${green}rm /usr/bin/v2node -f${plain}"
    echo ""

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

start() {
    check_status
    if [[ $? == 0 ]]; then
        echo ""
        echo -e "${green}v2node is already running. Select restart if you want to restart it.${plain}"
    else
        if [[ x"${release}" == x"alpine" ]]; then
            service v2node start
        else
            systemctl start v2node
        fi
        sleep 2
        check_status
        if [[ $? == 0 ]]; then
            echo -e "${green}v2node started successfully. Use v2node log to view the runtime logs.${plain}"
        else
            echo -e "${red}v2node may have failed to start. Use v2node log to check the logs shortly.${plain}"
        fi
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

stop() {
    if [[ x"${release}" == x"alpine" ]]; then
        service v2node stop
    else
        systemctl stop v2node
    fi
    sleep 2
    check_status
    if [[ $? == 1 ]]; then
        echo -e "${green}v2node stopped successfully${plain}"
    else
        echo -e "${red}Failed to stop v2node. Shutdown may take longer than two seconds. Check the logs shortly.${plain}"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

restart() {
    if [[ x"${release}" == x"alpine" ]]; then
        service v2node restart
    else
        systemctl restart v2node
    fi
    sleep 2
    check_status
    if [[ $? == 0 ]]; then
        echo -e "${green}v2node restarted successfully. Use v2node log to view the runtime logs.${plain}"
    else
        echo -e "${red}v2node may have failed to start. Use v2node log to check the logs shortly.${plain}"
    fi
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

status() {
    if [[ x"${release}" == x"alpine" ]]; then
        service v2node status
    else
        systemctl status v2node --no-pager -l
    fi
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

enable() {
    if [[ x"${release}" == x"alpine" ]]; then
        rc-update add v2node
    else
        systemctl enable v2node
    fi
    if [[ $? == 0 ]]; then
        echo -e "${green}v2node enabled on boot successfully${plain}"
    else
        echo -e "${red}Failed to enable v2node on boot${plain}"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

disable() {
    if [[ x"${release}" == x"alpine" ]]; then
        rc-update del v2node
    else
        systemctl disable v2node
    fi
    if [[ $? == 0 ]]; then
        echo -e "${green}v2node disabled on boot successfully${plain}"
    else
        echo -e "${red}Failed to disable v2node on boot${plain}"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

show_log() {
    if [[ x"${release}" == x"alpine" ]]; then
        echo -e "${red}Log viewing is currently not supported on Alpine${plain}\n" && exit 1
    else
        journalctl -u v2node.service -e --no-pager -f
    fi
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

update_shell() {
    wget -O /usr/bin/v2node -N --no-check-certificate https://raw.githubusercontent.com/phungvanquy/v2node-new/main/script/v2node.sh
    if [[ $? != 0 ]]; then
        echo ""
        echo -e "${red}Failed to download the script. Check whether this machine can connect to GitHub.${plain}"
        before_show_menu
    else
        chmod +x /usr/bin/v2node
        echo -e "${green}Script updated successfully. Please run the script again.${plain}" && exit 0
    fi
}

# 0: running, 1: not running, 2: not installed
check_status() {
    if [[ ! -f /usr/local/v2node/v2node ]]; then
        return 2
    fi
    if [[ x"${release}" == x"alpine" ]]; then
        temp=$(service v2node status | awk '{print $3}')
        if [[ x"${temp}" == x"started" ]]; then
            return 0
        else
            return 1
        fi
    else
        temp=$(systemctl status v2node | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
        if [[ x"${temp}" == x"running" ]]; then
            return 0
        else
            return 1
        fi
    fi
}

check_enabled() {
    if [[ x"${release}" == x"alpine" ]]; then
        temp=$(rc-update show | grep v2node)
        if [[ x"${temp}" == x"" ]]; then
            return 1
        else
            return 0
        fi
    else
        temp=$(systemctl is-enabled v2node)
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
        echo -e "${red}v2node is already installed. Please do not install it again.${plain}"
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
        echo -e "${red}Please install v2node first${plain}"
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
            echo -e "v2node status: ${green}Running${plain}"
            show_enable_status
            ;;
        1)
            echo -e "v2node status: ${yellow}Not running${plain}"
            show_enable_status
            ;;
        2)
            echo -e "v2node status: ${red}Not installed${plain}"
    esac
}

show_enable_status() {
    check_enabled
    if [[ $? == 0 ]]; then
        echo -e "Enabled on boot: ${green}Yes${plain}"
    else
        echo -e "Enabled on boot: ${red}No${plain}"
    fi
}

show_v2node_version() {
    echo -n "v2node version:"
    /usr/local/v2node/v2node version
    echo ""
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

generate_v2node_config() {
        local api_host="$1"
        local node_id="$2"
        local api_key="$3"

        mkdir -p /etc/v2node >/dev/null 2>&1
        cat > /etc/v2node/config.json <<EOF
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
        echo -e "${green}v2node configuration generated. Restarting the service...${plain}"
        if [[ x"${release}" == x"alpine" ]]; then
            service v2node restart
        else
            systemctl restart v2node
        fi
        sleep 2
        check_status
        echo -e ""
        if [[ $? == 0 ]]; then
            echo -e "${green}v2node restarted successfully${plain}"
        else
            echo -e "${red}v2node may have failed to start. Use v2node log to view the logs.${plain}"
        fi
}


generate_config_file() {
    # Prompt for parameters with example default values
    read -rp "Panel API URL [format: https://example.com/]: " api_host
    api_host=${api_host:-https://example.com/}
    read -rp "Node ID: " node_id
    node_id=${node_id:-1}
    read -rp "Node API key: " api_key

    # Generate the configuration file, overwriting any template copied from the package
    generate_v2node_config "$api_host" "$node_id" "$api_key"
}

# Open firewall ports
open_ports() {
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
    echo -e "${green}All firewall ports opened successfully!${plain}"
}

show_usage() {
    echo "v2node Management script usage: "
    echo "------------------------------------------"
    echo "v2node              - Show the management menu (more options)"
    echo "v2node start        - Start v2node"
    echo "v2node stop         - Stop v2node"
    echo "v2node restart      - Restart v2node"
    echo "v2node status       - Show v2node status"
    echo "v2node enable       - Enable v2node on boot"
    echo "v2node disable      - Disable v2node on boot"
    echo "v2node log          - View v2node logs"
    echo "v2node x25519       - Generate an x25519 key"
    echo "v2node generate     - Generate the v2node configuration file"
    echo "v2node update       - Update v2node"
    echo "v2node update x.x.x - Install a specific v2node version"
    echo "v2node install      - Install v2node"
    echo "v2node uninstall    - Uninstall v2node"
    echo "v2node version      - Show the v2node version"
    echo "------------------------------------------"
}

show_menu() {
    echo -e "
  ${green}v2node backend management script, ${plain}${red}not for Docker${plain}
--- https://github.com/phungvanquy/v2node-new ---
  ${green}0.${plain} Edit configuration
————————————————
  ${green}1.${plain} Install v2node
  ${green}2.${plain} Update v2node
  ${green}3.${plain} Uninstall v2node
————————————————
  ${green}4.${plain} Start v2node
  ${green}5.${plain} Stop v2node
  ${green}6.${plain} Restart v2node
  ${green}7.${plain} Show v2node status
  ${green}8.${plain} View v2node logs
————————————————
  ${green}9.${plain} Enable v2node on boot
  ${green}10.${plain} Disable v2node on boot
————————————————
  ${green}11.${plain} Show the v2node version
  ${green}12.${plain} Update the v2node management script
  ${green}13.${plain} Generate the v2node configuration file
  ${green}14.${plain} Open all network ports on the VPS
  ${green}15.${plain} Exit the script
 "
 #Add future menu entries to the string above
    show_status
    echo && read -rp "Select an option [0-15]: " num

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
        11) check_install && show_v2node_version ;;
        12) update_shell ;;
        13) generate_config_file ;;
        14) open_ports ;;
        15) exit ;;
        *) echo -e "${red}Please enter a valid number [0-15]${plain}" ;;
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
        "version") check_install 0 && show_v2node_version 0 ;;
        "update_shell") update_shell ;;
        *) show_usage
    esac
else
    show_menu
fi