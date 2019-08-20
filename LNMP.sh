#!/bin/bash

# 安装基础包及关闭防火墙
yum -y install vim wget lrzsz net-tools bind-utils
sed -i '/^SELINUX=/s/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config
systemctl stop firewalld
systemctl disable firewalld
IP=$(ifconfig eth0 | awk '/inet /{print $2}')
cat > /etc/sysconfig/network-scripts/ifcfg-eth0 << EOF
TYPE="Ethernet"
BOOTPROTO="static"
NAME="eth0"
DEVICE="eth0"
ONBOOT="yes"
IPADDR="$IP"
NETMASK="255.255.255.0"
GATEWAY="192.168.50.1"
DNS1="8.8.8.8"
EOF
# nginx安装
cd /root/
wget 192.168.50.79/resources/nginx-1.12.2.tar.gz
useradd -s /sbin/nologin nginx
tar xf nginx-1.12.2.tar.gz
cd nginx-1.12.2
yum -y install gcc gcc-c++ pcre-devel openssl-devel
./configure --prefix=/home/nginx --user=nginx --group=nginx --with-pcre --with-http_v2_module --with-http_ssl_module --with-http_realip_module --with-http_addition_module --with-http_sub_module --with-http_dav_module --with-http_flv_module --with-http_mp4_module --with-http_gunzip_module --with-http_gzip_static_module --with-http_random_index_module --with-http_secure_link_module --with-http_stub_status_module --with-http_auth_request_module --with-mail --with-mail_ssl_module --with-file-aio --with-http_v2_module --with-threads --with-stream --with-stream_ssl_module

make && make install

sed -i '$a export PATH=$PATH:/home/nginx/sbin' /etc/profile

cat > /home/nginx/conf/nginx.conf <<EOF
user  nginx;
worker_processes  auto;

events {
    worker_connections  1024;
}

http {
    include       mime.types;
    default_type  application/octet-stream;
    sendfile        on;
    keepalive_timeout  65;

    server {
        listen       80;
        server_name  localhost;
        root   html;
        index  index.html index.htm;

        error_page   500 502 503 504  /50x.html;
        location = /50x.html {
            root   html;
        }

        location ~ \.php$ {
            fastcgi_pass   127.0.0.1:9000;
            fastcgi_index  index.php;
            include        fastcgi.conf;
        }

    }
    #server {
    #    listen       443 ssl;
    #    server_name  localhost;

    #    ssl_certificate      cert.pem;
    #    ssl_certificate_key  cert.key;

    #    ssl_session_cache    shared:SSL:1m;
    #    ssl_session_timeout  5m;

    #    ssl_ciphers  HIGH:!aNULL:!MD5;
    #    ssl_prefer_server_ciphers  on;

    #    location / {
    #        root   html;
    #        index  index.html index.htm;
    #    }
    #}
}
EOF
source /etc/profile
nginx


# mysql安装
cd /root
useradd -s /sbin/nologin mysql
rpm -qa | grep mariadb > mariadb.txt
rpm -e --nodeps $(cat mariadb.txt)
rm -rf mariadb.txt
wget 192.168.50.79/resources/mysql-5.7.25-linux-glibc2.12-x86_64.tar.gz
tar xvf mysql-5.7.25-linux-glibc2.12-x86_64.tar.gz
mv mysql-5.7.25-linux-glibc2.12-x86_64 /usr/local/mysql
cd /usr/local/mysql
mkdir data binlog log
chown -R mysql:mysql /usr/local/mysql
sed -i '$a export PATH=$PATH:/usr/local/mysql/bin' /etc/profile
source /etc/profile

cat > /etc/my.cnf <<EOF
[client]
default-character-set=utf8
socket=/usr/local/mysql/data/mysql.sock
[mysql]
port= 3306
socket = /usr/local/mysql/data/mysql.sock
[mysqld]
max_connections = 300
log_timestamps = SYSTEM
# GENERAL #
user = mysql
port= 3306
character_set_server = utf8
collation-server=utf8_general_ci
default_storage_engine = InnoDB
basedir = /usr/local/mysql/
datadir = /usr/local/mysql/data
pid_file = /usr/local/mysql/data/mysqld.pid
socket = /usr/local/mysql/data/mysql.sock
sql_mode='NO_ENGINE_SUBSTITUTION'
# LOGGING #
log-error = /usr/local/mysql/log/err.log
slow_query_log_file = /usr/local/mysql/log/slow.log
# INNODB #
innodb_flush_method = O_DIRECT
innodb_log_file_size = 48M
innodb_buffer_pool_size = 4096M
innodb_buffer_pool_dump_at_shutdown = 1
innodb_buffer_pool_load_at_startup  = 1
# BINARY LOGGING #
log_bin = /usr/local/mysql/binlog/master
server_id = 144
binlog_format = row
binlog_row_image = MINIMAL
binlog_rows_query_log_events = ON
log_bin_trust_function_creators = TRUE
expire_logs_days = 7
max_binlog_size = 1G
# SLOW LOG #
slow_query_log = 1
long_query_time = 1
# SECURITY #
sync_binlog = 1
innodb_flush_log_at_trx_commit = 1
master_info_repository = TABLE
relay_log_info_repository = TABLE
relay_log_recovery = ON
log_slave_updates = ON
wait_timeout=31536000
interactive_timeout=31536000
EOF
mysqld --initialize-insecure --user=mysql --datadir=/usr/local/mysql/data --basedir=/usr/local/mysql
mv /usr/local/mysql/support-files/mysql.server /etc/init.d/mysqld
service mysqld start

# php安装
yum -y install php php-fpm php-mysql
systemctl start php-fpm
reboot
