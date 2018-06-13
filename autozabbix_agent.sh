#! /bin/bash
#
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'
Hostname=`hostname`
version=`grep -oE  "[0-9.]+" /etc/redhat-release |cut -d "." -f 1`
[[ $EUID -ne 0 ]] && echo -e "[${red}Error${plain}] This script must be run as root!" && exit 1
[ -f .install ] && echo -e "[${red}Zabbix-agent${plain}] installed" && exit 1
zabbix_dir=/etc/zabbix/zabbix_agentd.conf
disable_selinux(){
    if [ -s /etc/selinux/config ] && grep 'SELINUX=enforcing' /etc/selinux/config &>/dev/null; then
        sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config &>/dev/null
        setenforce 0
    fi
}
disable_firewalld()
{
	if [ $version -eq 7 ];then
		systemctl disable firewalld &>/dev/null
		systemctl stop firewalld
	else
		chkconfig iptables off
		service iptables stop
	fi
	
}

install_apt(){
	rpm -i http://repo.zabbix.com/zabbix/3.4/rhel/7/x86_64/zabbix-release-3.4-2.el7.noarch.rpm
	yum -y install zabbix-agent
}
zabbix_conf(){
	sed -i "s@Server=.*@Server=172.17.99.200@gi" $zabbix_dir &>/dev/null
	sed -i "s@ServerActive=.*@ServerActive=172.17.99.200@gi" $zabbix_dir &>/dev/null
	sed -i "s@Hostname=.*@Hostname=$Hostname@gi" $zabbix_dir &>/dev/null
	sed -i "s@# EnableRemoteCommands=0@EnableRemoteCommands=1@gi" $zabbix_dir &>/dev/null
	sed -i "s@# LogRemoteCommands=0@LogRemoteCommands=1@gi" $zabbix_dir &>/dev/null
}

start_agent(){
if [ $version -eq 7 ];then
systemctl enable zabbix-agent	&>/dev/null
systemctl restart zabbix-agent
else
   chkconfig zabbix-agent on
   service zabbix-agent restart 
fi
}
disable_firewalld
#关闭Selinux
disable_selinux
#安装依赖
install_apt
zabbix_conf
start_agent
[ $? -eq 0 ] && touch .install && echo -e "[${red}Zabbix-agent${plain}] Installation Complete" || exit 0 

