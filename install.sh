#!/bin/sh
_TMPDIR="/usr/tmp"
_PATH="https://raw.githubusercontent.com/huyn03/fastinstall/master"

function installNotExists(){
	$(rpm -q "$packages" | grep -e "not installed" | awk 'BEGIN { FS = " " } ; { printf $2" "}' > list.txt)
	install=$(cat list.txt)
	grep -q '[^[:space:]]' < list.txt
	EMPTY_FILE=$?
	if [[ $EMPTY_FILE -eq 1 ]]; then
			echo "Nothing to do"
	else
		yum install -y $install
	fi
}

packages="epel-release"
installNotExists $packages
packages="wget"
installNotExists $packages
packages="unzip"
installNotExists $packages

function nginx_php(){
	tmpdir=$_TMPDIR/nginx-php
	dpath=$_PATH/nginx-php
	rootdir="/home/www"
	packages="nginx"
	installNotExists $packages

	default="7"
	read -p "Cai tren centos ($default or 8) : " _version
	: ${_version:=$default}

	function centos(){
		wget -nc $dpath/index.php -P $tmpdir
	}

	function centos7(){
		dpath=$_PATH/nginx-php/centos7
		yum install http://rpms.remirepo.net/enterprise/remi-release-7.rpm -y
		yum-config-manager --enable remi-php73 -y
		yum --enablerepo=remi,remi-php73 install php-fpm php-common -y
		yum --enablerepo=remi,remi-php73 install php-cli php-pdo php-mysqlnd php-gd php-mbstring php-mcrypt php-xml php-zip -y
		
		wget -nc $dpath/php.ini -P $tmpdir
		wget -nc $dpath/www.conf -P $tmpdir
		wget -nc $dpath/your-domain.conf -P $tmpdir
		wget -nc $dpath/nginx.conf -P $tmpdir

		cp -r $tmpdir/php.ini /etc/php.ini
		cp -r $tmpdir/www.conf /etc/php-fpm.d/www.conf
		cp -r $tmpdir/your-domain.conf /etc/nginx/conf.d/your-domain.conf
		cp -r $tmpdir/nginx.conf /etc/nginx/nginx.conf
	}

	function centos8(){
		dpath=$_PATH/nginx-php/centos8
		dnf install dnf-utils http://rpms.remirepo.net/enterprise/remi-release-8.rpm -y
		dnf module reset php -y
		dnf module enable php:remi-7.4 -y
		dnf install php-fpm php-common -y
		dnf install php-cli php-pdo php-mysqlnd php-gd php-mbstring php-mcrypt php-xml php-zip -y

		wget -nc $dpath/www.conf -P $tmpdir
		wget -nc $dpath/your-domain.conf -P $tmpdir
		wget -nc $dpath/nginx.conf -P $tmpdir

		cp -r $tmpdir/www.conf /etc/php-fpm.d/www.conf
		cp -r $tmpdir/your-domain.conf /etc/nginx/conf.d/your-domain.conf
		cp -r $tmpdir/nginx.conf /etc/nginx/nginx.conf
	}
	
	centos
	centos$_version
	# packages="php-fpm php-common php-cli php-pdo php-mysqlnd php-gd php-mbstring php-mcrypt php-xml php-zip"
	# installNotExists $packages

	systemctl start nginx
	systemctl enable nginx
	systemctl start php-fpm
	systemctl enable php-fpm

	mkdir -p $rootdir/your-domain
	cp -r $tmpdir/index.php $rootdir/your-domain
	chown nginx:nginx -R $rootdir/your-domain
	chown -R nginx:nginx /var/lib/php/session/
	chcon -Rt httpd_sys_content_t $rootdir/your-domain
	chcon -Rt httpd_sys_rw_content_t $rootdir/your-domain
	setsebool httpd_can_network_connect 1
}

#install mariadb
function mariadb(){
	tmpdir=$_TMPDIR/mariadb
	dpath=$_PATH/mariadb
	packages="mariadb-server"
	installNotExists $packages
	wget -nc $dpath/my.cnf -P $tmpdir
	cp -r $tmpdir/my.cnf /etc/my.cnf
	systemctl start mariadb
	systemctl enable mariadb
	mysql_secure_installation
}

function vltkm(){
	tmpdir=$_TMPDIR/vltkm
	dpath=$_PATH/vltkm
	rootdir="/home/vltkm"
	pPackages=""

	default=`wget -qO - icanhazip.com`
	read -p "Ip may chu ($default): " vpsip
	: ${vpsip:=$default}
	default=123456
	read -p "Mat khau database ($default): " dbpassword
	: ${dbpassword:=$default}
	default=127.0.0.1
	read -p "Gateway Ip ($default): " gatewayip
	: ${gatewayip:=$default}
	default=11002
	read -p "Gateway Port ($default): " gatewayport
	: ${gatewayport:=$default}

	function lib(){
		wget -nc $dpath/libstdc++.so.6.zip -P $tmpdir
		unzip -o $tmpdir/libstdc++.so.6.zip -d $rootdir
		cp $rootdir/libstdc++.so.6.20 /lib64
		rm -f /lib64/libstdc++.so.6
		ln -s /lib64/libstdc++.so.6.20 /lib64/libstdc++.so.6
		ldconfig
	}

	function gateway(){
		wget -nc $dpath/Gateway.zip -P $tmpdir
		unzip -o $tmpdir/Gateway.zip -d $rootdir/Gateway

		sed -i "s/VPSIP/$vpsip/g" $rootdir/Gateway/gateway.ini
		sed -i "s/DBPASSWORD/$dbpassword/g" $rootdir/Gateway/gateway.ini
		sed -i "s/GATEPORT/$gatewayport/g" $rootdir/Gateway/gateway.ini
		sed -i "s/DBPASSWORD/$dbpassword/g" $rootdir/Gateway/GoJxHttpSetting/go-jxhttp.json
		sed -i "s/DBPASSWORD/$dbpassword/g" $rootdir/Gateway/GoJxHttpSetting/go-jxhttp_idip.json
		sed -i "s/DBPASSWORD/$dbpassword/g" $rootdir/Gateway/RankServer.json
	}

	function webapi(){
		default="/home/www/your-domain"
		read -p "Thu muc chay web ($default) : " webdir
		: ${webdir:=$default}
		wget -nc https://octobercms.com/download -O octobercms.zip
		wget -nc $dpath/web.zip -P $webdir
		unzip -o octobercms.zip -d $webdir
		rm -f octobercms.zip
		mv $webdir/install-master/* $webdir
		chown nginx:nginx -R $webdir
	}

	function serverPackages(){
		default=$dpath/Package.zip
		if [ "$pPackages" == "" ]
		then
			read -p "Duong dan download Package.zip(package.idx, package0.dat): " pPackages
			: ${pPackages:=$default}
		fi
		wget -nc $dpath/ServerLibs.zip -P $tmpdir
		wget -nc $dpath/Server.zip -P $tmpdir
		wget -nc $pPackages -P $tmpdir
	}

	function zone(){
		numsv=00
		serverPackages
		wget -nc $dpath/StartZone.zip -P $tmpdir

		sdir="$rootdir/Zone"

		unzip -o $tmpdir/ServerLibs.zip -d $sdir
		unzip -o $tmpdir/Server.zip -d $sdir
		unzip -o $tmpdir/Package.zip -d $sdir
		unzip -o $tmpdir/StartZone.zip -d $sdir

		sed -i "s/NUMSV/$numsv/g" $sdir/world_server.ini
		sed -i "s/VPSIP/$vpsip/g" $sdir/world_server.ini
		sed -i "s/DBPASSWORD/$dbpassword/g" $sdir/world_server.ini
		sed -i "s/GATEIP/$gatewayip/g" $sdir/world_server.ini
		sed -i "s/GATEPORT/$gatewayport/g" $sdir/world_server.ini

		sed -i "s/NUMSV/$numsv/g" $sdir/FileServer.ini
		sed -i "s/DBPASSWORD/$dbpassword/g" $sdir/FileServer.ini

		mv $sdir/FileServer $sdir/ZoneFileServer
		mv $sdir/Server $sdir/ZoneServer
	}

	function server(){
		serverPackages
		wget -nc $dpath/StartSV.zip -P $tmpdir

		default=01
		read -p "Nhap ten server (vd: $default): " numsv
		: ${numsv:=$default}

		sdir="$rootdir/Server_$numsv"

		unzip -o $tmpdir/ServerLibs.zip -d $sdir
		unzip -o $tmpdir/Server.zip -d $sdir
		unzip -o $tmpdir/Package.zip -d $sdir
		unzip -o $tmpdir/StartSV.zip -d $sdir

		sed -i "s/NUMSV/$numsv/g" $sdir/world_server.ini
		sed -i "s/VPSIP/$vpsip/g" $sdir/world_server.ini
		sed -i "s/DBPASSWORD/$dbpassword/g" $sdir/world_server.ini
		sed -i "s/GATEIP/$gatewayip/g" $sdir/world_server.ini
		sed -i "s/GATEPORT/$gatewayport/g" $sdir/world_server.ini

		sed -i "s/NUMSV/$numsv/g" $sdir/FileServer.ini
		sed -i "s/DBPASSWORD/$dbpassword/g" $sdir/FileServer.ini

		sed -i "s/NUMSV/$numsv/g" $sdir/start.sh
		sed -i "s/NUMSV/$numsv/g" $sdir/world_server.sh

		sed -i "s/NUMSV/$numsv/g" $sdir/stop.sh

		mv $sdir/FileServer $sdir/FileServer_$numsv
		mv $sdir/Server $sdir/Server_$numsv
	}

	default="lib gateway zone server webapi"
	read -p 'Enter packages (lib, gateway, zone, server, webapi): ' packages
	: ${packages:=$default}
	for package in $packages; do $package; done

	chmod -R 755 $rootdir
}

default="nginx_php mariadb vltkm"
packages=$@
: ${packages:=$default}
for package in $packages; do $package; done