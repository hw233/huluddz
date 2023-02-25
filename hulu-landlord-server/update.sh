#!/bin/bash
#
#########################################################
# Function :openssh-9.0p1 update                        #
# Platform :Centos7.X                                   #
# Version  :2.0                                         #
# Date     :2022-05-01                                  #    
#########################################################

clear
export LANG="en_US.UTF-8"

#版本号
zlib_version="zlib-1.2.12"
openssl_version="openssl-1.1.1q"
openssh_version="openssh-9.0p1"

#安装包地址
file="/opt"

#默认编译路径
default="/usr/local"
date_time=`date +%Y-%m-%d—%H:%M`

#安装目录
file_install="$file/openssh_install"
file_backup="$file/openssh_backup"
file_log="$file/openssh_log"

#源码包链接
zlib_download="https://www.zlib.net/$zlib_version.tar.gz"
openssl_download="https://www.openssl.org/source/$openssl_version.tar.gz"
openssh_download="https://cdn.openbsd.org/pub/OpenBSD/OpenSSH/portable/$openssh_version.tar.gz"


Install_make()
{
# Check if user is root
    if [ $(id -u) != "0" ]; then
    echo -e "\033[33m--------------------------------------------------------------- \033[0m"
        echo -e " 当前用户为普通用户，必须使用root用户运行，脚本退出中......" "\033[31m Error\033[0m"
    echo -e "\033[33m--------------------------------------------------------------- \033[0m"
    echo ""
    sleep 4
    exit
    fi

#判断是否安装wget
echo -e "\033[33m 正在安装Wget...... \033[0m"
sleep 2
echo ""
    if ! type wget >/dev/null 2>&1; then
        yum install -y wget
    else
    echo -e "\033[33m--------------------------------------------------------------- \033[0m"
        echo -e " wget已经安装了：" "\033[32m Please continue\033[0m"
    echo -e "\033[33m--------------------------------------------------------------- \033[0m"
    echo ""
    fi

#判断是否安装tar
echo -e "\033[33m 正在安装TAR...... \033[0m"
sleep 2
echo ""
    if ! type tar >/dev/null 2>&1; then
        yum install -y tar
    else
    echo ""
    echo -e "\033[33m--------------------------------------------------------------- \033[0m"
        echo -e " tar已经安装了：" "\033[32m Please continue\033[0m"
    echo -e "\033[33m--------------------------------------------------------------- \033[0m"
    fi
    echo ""

#安装相关依赖包
echo -e "\033[33m 正在安装依赖包...... \033[0m"
sleep 3
echo ""
    yum install gcc gcc-c++ glibc make autoconf openssl openssl-devel pcre-devel pam-devel zlib-devel tcp_wrappers-devel tcp_wrappers
    if [ $? -eq 0 ];then
    echo ""
    echo -e "\033[33m--------------------------------------------------------------- \033[0m"
           echo -e " 安装软件依赖包成功 " "\033[32m Success\033[0m"
    echo -e "\033[33m--------------------------------------------------------------- \033[0m"
    else
       echo -e "\033[33m--------------------------------------------------------------- \033[0m"
           echo -e " 解压源码包失败，脚本退出中......" "\033[31m Error\033[0m"
    echo -e "\033[33m--------------------------------------------------------------- \033[0m"
    sleep 4
    exit
    fi
    echo ""
}


Install_backup()
{
#创建文件（可修改）
mkdir -p $file_install
mkdir -p $file_backup
mkdir -p $file_log
mkdir -p $file_backup/zlib
mkdir -p $file_backup/ssl
mkdir -p $file_backup/ssh
mkdir -p $file_log/zlib
mkdir -p $file_log/ssl
mkdir -p $file_log/ssh


#备份文件（可修改）
cp -rf /usr/bin/openssl  $file_backup/ssl/openssl_$date_time.bak > /dev/null
cp -rf /etc/init.d/sshd  $file_backup/ssh/sshd_$date_time.bak > /dev/null
cp -rf /etc/ssh  $file_backup/ssh/ssh_$date_time.bak > /dev/null
cp -rf /usr/lib/systemd/system/sshd.service  $file_backup/ssh/sshd_$date_time.service.bak > /dev/null
cp -rf /etc/pam.d/sshd.pam  $file_backup/ssh/sshd_$date_time.pam.bak > /dev/null
}

Remove_openssh()
{
##并卸载原有的openssh（可修改）
rpm -e --nodeps `rpm -qa | grep openssh`
}

Install_tar()
{
#zlib
echo -e "\033[33m 正在下载Zlib软件包...... \033[0m"
sleep 3
echo ""
    if [ -e $file/$zlib_version.tar.gz ] ;then
        echo -e " 下载软件源码包已存在  " "\033[32m  Please continue\033[0m"
    else
        echo -e "\033[33m 未发现zlib本地源码包，链接检查获取中........... \033[0m "
    sleep 1
    echo ""
    cd $file
    wget --no-check-certificate  $zlib_download
    echo ""
    fi
#openssl
echo -e "\033[33m 正在下载Openssl软件包...... \033[0m"
sleep 3
echo ""
    if  [ -e $file/$openssl_version.tar.gz ]  ;then
        echo -e " 下载软件源码包已存在  " "\033[32m  Please continue\033[0m"
    else
        echo -e "\033[33m 未发现openssl本地源码包，链接检查获取中........... \033[0m "
    echo ""
    sleep 1
    cd $file
    wget --no-check-certificate  $openssl_download
    echo ""
    fi
#openssh
echo -e "\033[33m 正在下载Openssh软件包...... \033[0m"
sleep 3
echo ""
    if [ -e /$file/$openssh_version.tar.gz ];then
        echo -e " 下载软件源码包已存在  " "\033[32m  Please continue\033[0m"
    else
        echo -e "\033[33m 未发现openssh本地源码包，链接检查获取中........... \033[0m "
    echo ""
    sleep 1
    cd $file
    wget --no-check-certificate  $openssh_download
    fi
}

echo ""
echo ""
#安装zlib
Install_zlib(){
echo -e "\033[33m 1.1-正在解压Zlib软件包...... \033[0m"
sleep 3
echo ""
    cd $file && mkdir -p $file_install && tar -xzf zlib*.tar.gz -C $file_install > /dev/null
    if [ -d $file_install/$zilb_version ];then
    echo -e "\033[33m--------------------------------------------------------------- \033[0m"
                   echo -e "  zilb解压源码包成功" "\033[32m Success\033[0m"
    echo -e "\033[33m--------------------------------------------------------------- \033[0m"
    echo ""
           else
    echo -e "\033[33m--------------------------------------------------------------- \033[0m"
                   echo -e "  zilb解压源码包失败，脚本退出中......" "\033[31m Error\033[0m"
    echo -e "\033[33m--------------------------------------------------------------- \033[0m"
    echo ""
    sleep 4
    exit
    fi
echo -e "\033[33m 1.2-正在编译安装Zlib服务.............. \033[0m"
sleep 3
echo ""
    cd $file_install/zlib*
    ./configure --prefix=$default/$zlib_version > $file_log/zlib/zlib_configure_$date_time.txt  #> /dev/null 2>&1
    if [ $? -eq 0 ];then
    echo -e "\033[33m make... \033[0m"
        make > /dev/null 2>&1
    echo $?
    echo -e "\033[33m make test... \033[0m"
        make test > /dev/null 2>&1
    echo $?
    echo -e "\033[33m make install... \033[0m"
        make install > /dev/null 2>&1
    echo $?
    else
    echo -e "\033[33m--------------------------------------------------------------- \033[0m"
        echo -e "  编译安装压缩库失败，脚本退出中..." "\033[31m Error\033[0m"
    echo -e "\033[33m--------------------------------------------------------------- \033[0m"
    echo ""
    sleep 4
    exit
    fi

    if [ -e $default/$zlib_version/lib/libz.so ];then
    sed -i '/zlib/'d /etc/ld.so.conf
    echo "$default/$zlib_version/lib" >> /etc/ld.so.conf
    echo "$default/$zlib_version/lib" >> /etc/ld.so.conf.d/zlib.conf
    ldconfig -v > $file_log/zlib/zlib_ldconfig_$date_time.txt > /dev/null 2>&1
    /sbin/ldconfig
    fi
}

echo ""
echo ""
Install_openssl(){
echo -e "\033[33m 2.1-正在解压Openssl...... \033[0m"
sleep 3
echo ""
    cd $file  &&  tar -xvzf openssl*.tar.gz -C $file_install > /dev/null
    if [ -d $file_install/$openssl_version ];then
    echo -e "\033[33m--------------------------------------------------------------- \033[0m"
                   echo -e "  OpenSSL解压源码包成功" "\033[32m Success\033[0m"
    echo -e "\033[33m--------------------------------------------------------------- \033[0m"
           else
    echo -e "\033[33m--------------------------------------------------------------- \033[0m"
                   echo -e "  OpenSSL解压源码包失败，脚本退出中......" "\033[31m Error\033[0m"
    echo -e "\033[33m--------------------------------------------------------------- \033[0m"
    echo ""
    sleep 4
    exit
    fi
    echo ""
echo -e "\033[33m 2.2-正在编译安装Openssl服务...... \033[0m"
sleep 3
echo ""
    cd $file_install/$openssl_version
        ./config shared zlib --prefix=$default/$openssl_version >  $file_log/ssl/ssl_config_$date_time.txt  #> /dev/null 2>&1
    if [ $? -eq 0 ];then
    echo -e "\033[33m make clean... \033[0m"
        make clean > /dev/null 2>&1
    echo $?
    echo -e "\033[33m make -j 4... \033[0m"
        make -j 4 > /dev/null 2>&1
    echo $?
    echo -e "\033[33m make install... \033[0m"
        make install > /dev/null 2>&1
    echo $?
    else
    echo -e "\033[33m--------------------------------------------------------------- \033[0m"
        echo -e "  编译安装OpenSSL失败，脚本退出中..." "\033[31m Error\033[0m"
    echo -e "\033[33m--------------------------------------------------------------- \033[0m"
    echo ""
    sleep 4
    exit
    fi

    mv /usr/bin/openssl /usr/bin/openssl_$date_time.bak    #先备份
    if [ -e $default/$openssl_version/bin/openssl ];then
    sed -i '/openssl/'d /etc/ld.so.conf
    echo "$default/$openssl_version/lib" >> /etc/ld.so.conf
    ln -s $default/$openssl_version/bin/openssl /usr/bin/openssl
    ln -s $default/$openssl_version/lib/libssl.so.1.1 /usr/lib64/libssl.so.1.1
    ln -s $default/$openssl_version/lib/libcrypto.so.1.1 /usr/lib64/libcrypto.so.1.1
    ldconfig -v > $file_log/ssl/ssl_ldconfig_$date_time.txt > /dev/null 2>&1
    /sbin/ldconfig
    echo -e "\033[33m--------------------------------------------------------------- \033[0m"
        echo -e " 编译安装OpenSSL " "\033[32m Success\033[0m"
    echo -e "\033[33m--------------------------------------------------------------- \033[0m"
    echo ""
echo -e "\033[33m 2.3-正在输出 OpenSSL 版本状态.............. \033[0m"
sleep 3
echo ""
    echo -e "\033[32m====================== OpenSSL veriosn =====================  \033[0m"
    echo ""
        openssl version -a
    echo ""
    echo -e "\033[32m=======================================================  \033[0m"
    sleep 2
    else
    echo ""
    echo -e "\033[33m--------------------------------------------------------------- \033[0m"
        echo -e " OpenSSL软连接失败，脚本退出中..." "\033[31m  Error\033[0m"
    echo -e "\033[33m--------------------------------------------------------------- \033[0m"
    fi
}
echo ""
echo ""
Install_openssh(){
echo -e "\033[33m 3.1-正在解压OpenSSH...... \033[0m"
sleep 3
echo ""
    cd $file && tar -xvzf openssh*.tar.gz -C $file_install > /dev/null
    if [ -d $file_install/$openssh_version ];then
    echo -e "\033[33m--------------------------------------------------------------- \033[0m"
         echo -e "  OpenSSh解压源码包成功" "\033[32m Success\033[0m"
    echo -e "\033[33m--------------------------------------------------------------- \033[0m"
           else
    echo -e "\033[33m--------------------------------------------------------------- \033[0m"
         echo -e "  OpenSSh解压源码包失败，脚本退出中......" "\033[31m Error\033[0m"
    echo -e "\033[33m--------------------------------------------------------------- \033[0m"
    echo ""
    sleep 4
    exit
    fi
    echo ""
echo -e "\033[33m 3.2-正在编译安装OpenSSH服务...... \033[0m"
sleep 3
echo ""
    mv /etc/ssh /etc/ssh_$date_time.bak     #先备份
    cd $file_install/$openssh_version
    ./configure --prefix=$default/$openssh_version --sysconfdir=/etc/ssh --with-pam --with-ssl-dir=$default/$openssl_version --with-zlib=$default/$zlib_version >  $file_log/ssh/ssh_configure_$date_time.txt   #> /dev/null 2>&1
    if [ $? -eq 0 ];then
    echo -e "\033[33m make -j 4... \033[0m"
        make -j 4 > /dev/null 2>&1
    echo $?
    echo -e "\033[33m make install... \033[0m"
        make install > /dev/null 2>&1
    echo $?
    else
    echo -e "\033[33m--------------------------------------------------------------- \033[0m"
        echo -e " 编译安装OpenSSH失败，脚本退出中......" "\033[31m Error\033[0m"
    echo -e "\033[33m--------------------------------------------------------------- \033[0m"
    echo ""
    sleep 4
    exit
    fi
   
    echo ""
    echo -e "\033[33m--------------------------------------------------------------- \033[0m"
        echo -e " 编译安装OpenSSH " "\033[32m Success\033[0m"
    echo -e "\033[33m--------------------------------------------------------------- \033[0m"
    echo ""
    sleep 2
    echo -e "\033[32m==================== OpenSSH—file veriosn =================== \033[0m"
    echo ""
        /usr/local/$openssh_version/bin/ssh -V
    echo ""
    echo -e "\033[32m======================================================= \033[0m"
    sleep 3
    echo ""

echo -e "\033[33m 3.3-正在迁移OpenSSH配置文件...... \033[0m"
sleep 3
echo ""
#迁移sshd
    if [ -f  "/etc/init.d/sshd" ];then
        mv /etc/init.d/sshd /etc/init.d/sshd_$date_time.bak
    else
        echo -e " /etc/init.d/sshd不存在 " "\033[31m Not backed up(可忽略)\033[0m"
    fi
    cp -rf $file_install/$openssh_version/contrib/redhat/sshd.init /etc/init.d/sshd;

    chmod u+x /etc/init.d/sshd;
    chkconfig --add sshd      ##自启动
    chkconfig --list |grep sshd;
    chkconfig sshd on
#备份启动脚本,不一定有
    if [ -f  "/usr/lib/systemd/system/sshd.service" ];then
        mv /usr/lib/systemd/system/sshd.service /usr/lib/systemd/system/sshd.service_bak
    else
        echo -e " sshd.service不存在" "\033[31m Not backed up(可忽略)\033[0m"
    fi
#备份复制sshd.pam文件
    if [ -f "/etc/pam.d/sshd.pam" ];then
        mv /etc/pam.d/sshd.pam /etc/pam.d/sshd.pam_$date_time.bak
    else
        echo -e " sshd.pam不存在" "\033[31m Not backed up(可忽略)\033[0m"
    fi
    cp -rf $file_install/$openssh_version/contrib/redhat/sshd.pam /etc/pam.d/sshd.pam
#迁移ssh_config  
    cp -rf $file_install/$openssh_version/sshd_config /etc/ssh/sshd_config
    sed -i 's/Subsystem/#Subsystem/g' /etc/ssh/sshd_config
    echo 'Subsystem sftp $default/$openssh_version/libexec/sftp-server'>> /etc/ssh/sshd_config
    cp -rf $default/$openssh_version/sbin/sshd /usr/sbin/sshd
    cp -rf /$default/$openssh_version/bin/ssh /usr/bin/ssh
    cp -rf $default/$openssh_version/bin/ssh-keygen /usr/bin/ssh-keygen
    sed -i 's/#PasswordAuthentication\ yes/PasswordAuthentication\ yes/g' /etc/ssh/sshd_config
    #grep -v "[[:space:]]*#" /etc/ssh/sshd_config  |grep "PubkeyAuthentication yes"
    echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config

#重启sshd
    service sshd start > /dev/null 2>&1
    if [ $? -eq 0 ];then
    echo -e "\033[33m--------------------------------------------------------------- \033[0m"
        echo -e " 启动OpenSSH服务成功" "\033[32m Success\033[0m"
    echo -e "\033[33m--------------------------------------------------------------- \033[0m"
    echo ""
    sleep 2
    #删除源码包（可修改）
    rm -rf $file/*$zlib_version.tar.gz
    rm -rf $file/*$openssl_version.tar.gz
    rm -rf $file/*$openssh_version.tar.gz
    #rm -rf $file_install
echo -e "\033[33m 3.4-正在输出 OpenSSH 版本...... \033[0m"
sleep 3
echo ""
    echo -e "\033[32m==================== OpenSSH veriosn =================== \033[0m"
    echo ""
        ssh -V
    echo ""
    echo -e "\033[32m======================================================== \033[0m"
    else
    echo -e "\033[33m--------------------------------------------------------------- \033[0m"
        echo -e " 启动OpenSSH服务失败，脚本退出中......" "\033[31m Error\033[0m"
    echo -e "\033[33m--------------------------------------------------------------- \033[0m"
    sleep 4
    exit
    fi
    echo ""
}

End_install()
{

##sshd状态
    echo ""
    echo -e "\033[33m 输出sshd服务状态： \033[33m"
    sleep 2
    echo ""
    systemctl status sshd.service
    echo ""
    echo ""
    echo ""
    sleep 1
   
echo -e "\033[33m==================== OpenSSH file =================== \033[0m"
echo ""
    echo -e " Openssh升级安装目录请前往:  "
    cd  $file_install && pwd
    cd ~
    echo ""
    echo -e " Openssh升级备份目录请前往:  "
    cd  $file_backup && pwd
    cd ~
    echo ""
    echo -e " Openssh升级日志目录请前往:  "
    cd  $file_log && pwd
    cd ~
    echo ""
    echo -e " 如果FTP登不上  "
    echo -e " vim /etc/ssh/sshd_config  "
    echo -e " 倒数第二行改为 Subsystem  sftp /usr/local/openssh-9.0p1/libexec/sftp-server  "
   
    echo -e " 重启 systemctl restart sshd  "
    echo -e " 如果openfiles变成了1024  "
    echo -e " vim /etc/ssh/sshd_config  "
    echo -e " 增加一行 UsePAM yes  "
    echo -e " systemctl restart sshd  "
        echo -e " 注意先测试一下可否正常连接到服务器重启"
    echo -e " 如果还不行，百度《openssh升级后openfiles变成了1024》  "
        echo -e " 参考【https://www.cnblogs.com/clement-jiao/p/9651406.html】"
    echo ""
echo -e "\033[33m======================================================= \033[0m"
}


Install_make
Install_backup
Remove_openssh
Install_tar
Install_zlib
Install_openssl
Install_openssh
End_install
