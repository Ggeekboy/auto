#! /bin/bash
#
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'
version=`grep -oE  "[0-9.]+" /etc/redhat-release |cut -d "." -f 1`
ip=`ip addr | grep 'state UP' -A2 | tail -n1 | awk '{print $2}' | awk -F"/" '{print $1}'`
[[ $EUID -ne 0 ]] && echo -e "[${red}Error${plain}] This script must be run as root!" && exit 1
[ -f .install ] && echo -e "[${red}Zabbix-server${plain}] installed" && exit 1
mysql_dir=/etc/my.cnf.d/server.cnf
zabbix_dir=/etc/zabbix/zabbix_server.conf
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
yum -y install httpd php php-mysql mariadb-server
rpm -i http://repo.zabbix.com/zabbix/3.4/rhel/7/x86_64/zabbix-release-3.4-2.el7.noarch.rpm
yum -y install zabbix-server-mysql zabbix-web-mysql zabbix-agent
}
mysql_conf(){
sed -i '/mysqld-5.5/a\collation-server=utf8_unicode_ci' $mysql_dir &>/dev/null
sed -i '/mysqld-5.5/acharacter-set-server=utf8' $mysql_dir	&>/dev/null
sed -i "/mysqld-5.5/ainit_connect='SET NAMES utf8'" $mysql_dir	&>/dev/null
sed -i "/mysqld-5.5/a\init_connect='SET collation_connection = utf8_unicode_ci'" $mysql_dir	&>/dev/null
sed -i '/mysqld-5.5/ainnodb_file_per_table=1' $mysql_dir &>/dev/null
}
mysql_secure()
{
if [ ! -e /usr/bin/expect ]
 then  yum install expect -y
fi
echo '#!/usr/bin/expect
set timeout 60
set password [lindex $argv 0]
spawn mysql_secure_installation
expect {
"(enter for none):" { send "\r";exp_continue}
"Set root password" { send "n\r";exp_continue}
"Remove anonymous users" { send "Y\r";exp_continue}
"Disallow root login remotely" { send "n\r";exp_continue}
"Remove test database and access to it" { send "Y\r";exp_continue}
"Reload privilege" { send "Y\r";exp_continue}
}' > mysql_secure_installation.exp
chmod +x mysql_secure_installation.exp
./mysql_secure_installation.exp        
rm -rf mysql_secure_installation.exp      
}
init_mysql(){
systemctl enable mariadb &>/dev/null
systemctl restart mariadb
echo "now let's begin mysql_secure_installation "
mysql_secure
}
create_db(){
mysql -e "create database zabbix character set utf8 collate utf8_bin;"
mysql -e "grant all privileges on zabbix.* to zabbix@localhost identified by '123456';"
mysql -e "flush privileges;"
}
zabbix_conf(){
zcat /usr/share/doc/zabbix-server-mysql-3.4.10/create.sql.gz | mysql -uzabbix -p123456 --database zabbix
sed -i "/# DBHost=localhost/aDBHost=localhost" $zabbix_dir &>/dev/null
sed -i "s@^DBName.*@DBName=zabbix@gi" $zabbix_dir	&>/dev/null
sed -i "s@^DBUser.*@DBUser=zabbix@gi" $zabbix_dir	&>/dev/null
sed -i "/# DBPa.*/aDBPassword=123456" $zabbix_dir	&>/dev/null
sed -i "s@# php_value date.timezone.*@php_value date.timezone Asia/Shanghai@gi" /etc/httpd/conf.d/zabbix.conf	&>/dev/null
}
start_http_zabbix(){
if [ $version -eq 7 ];then
systemctl eanble httpd	&>/dev/null
systemctl restart httpd
systemctl enable zabbix-server	&>/dev/null
systemctl restart zabbix-server

else
   chkconfig httpd on
   service httpd restart 
   chkconfig zabbix-server on
   service zabbix-server restart 
fi
}
disable_firewalld
#关闭Selinux
disable_selinux
#安装依赖
install_apt
mysql_conf
init_mysql
create_db
zabbix_conf
start_http_zabbix
[ $? -eq 0 ] && touch .install  && echo -e "[${red}Zabbix-Server${plain}] Installation Complete"|| exit 1
echo -e "${red}DBName=zabbix"
echo -e "DBUser=zabbix"
echo -e "DBPassword=123456"
echo -e "http://${ip}/zabbix/${plain}"
