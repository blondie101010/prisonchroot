#!/bin/bash

##Author : Julie Pelletier (blondie101010)
##Email  : blondie101010@hotmail.com
##Desc   : Simple multi-jail system for ssh and sftp.
##License: LGPL-3


# load system environment
source /etc/profile

cd /tmp
rm -rf prisonchroot
mkdir prisonchroot
cd prisonchroot
wget https://github.com/blondie101010/prisonchroot/archive/master.tar.gz 
tar -xzf master.tar.gz 
cd prisonchroot-master 

# install b101010 utils
bash <(curl -L -Ss https://raw.githubusercontent.com/blondie101010/b101010-shell-utils/master/install.sh)

source /usr/local/lib/b101010-system.inc.sh

validateRootPath() {	# $1:varName
	_root=${!1}
	if [ -d $_root ] || [ -f $_root ] || [ ! -w `dirname $_root` ] || [ ${_root:0:1} != / ]; then
		# invalid
		if [[ "$_root" != "" ]]; then
			warn "$_root already exists or is not writable."
			unset $1
		fi
		return 0
	else
		return 1
	fi
}

saveConf() {	# $1:INIT_SYSTEM
	echo "PRISON_ROOT=$PRISON_ROOT" > /etc/prisonchroot.conf
	echo "PRISON_HOSTNAME=$PRISON_HOSTNAME" >> /etc/prisonchroot.conf

	# also keep INIT config to avoid redetecting all the time
	echo "INIT_SYSTEM=$INIT_SYSTEM" >> /etc/prisonchroot.conf
	echo "INIT_DIR=$INIT_DIR" >> /etc/prisonchroot.conf
	echo "INIT_ENABLE=$INIT_ENABLE" >> /etc/prisonchroot.conf
}

# create our configuration based on user selection
echo "Welcome to the prisonchroot installer!";
echo ""
echo "You will now be asked a few questions to customize your prison system."
echo ""

while validateRootPath PRISON_ROOT; do
	getEnvOrPrompt PRISON_ROOT "Base directory for jails (must not exist): " "/prisons"
done

while [[ "$PRISON_HOSTNAME" = "" ]]; do
	getEnvOrPrompt PRISON_HOSTNAME "Prison host name which is shown to jailed users: " "`hostname`"
done


mkdir -p $PRISON_ROOT/archive
chown root:root $PRISON_ROOT
chmod 755 $PRISON_ROOT

cp prisonchroot /usr/local/bin
cp prisonchroot.inc.sh /usr/local/lib/.
chmod 700 /usr/local/bin/prisonchroot /usr/local/lib/prisonchroot.inc.sh

# if present, force selinux to allow chroot
if (type sestatus >/dev/null 2>&1) && (sestatus|grep -v disabled >/dev/null); then
	setsebool -P ssh_chroot_full_access=1 2> /dev/null
	semodule -r prisonchroot
	checkmodule -M -m -o prisonchroot.mod prisonchroot.te
	semodule_package -o prisonchroot.pp -m prisonchroot.mod
	semodule -i prisonchroot.pp
fi


# make sure sshd uses its internal sftp server (more secure)
cp -n /etc/ssh/sshd_config /etc/ssh/sshd_config.prisonchroot.bak
sed -i "/^Subsystem\ssftp/d" /etc/ssh/sshd_config
echo -e "\nSubsystem sftp internal-sftp\n" >> /etc/ssh/sshd_config


initDetect

case "$INIT_SYSTEM" in
	openrc) source=prisonchroot.openrc ;;

	systemd) source=prisonchroot.systemd ;;

	sysv|sysv-service) source=prisonchroot.sysv ;;
esac

saveConf

serviceControl install prisonchroot $source
serviceControl enable prisonchroot
serviceControl start prisonchroot

rm -rf /tmp/prisonchroot
