#!/bin/bash

##Author : Julie Pelletier (blondie101010)
##Email  : blondie101010@hotmail.com
##Desc   : Simple multi-jail system for ssh and sftp.
##License: LGPL-3


# load system environment
source /etc/profile

function validateRootPath {
	if [ -d $1 ] || [ -f $1 ] || [ ! -w `dirname $1` ] || [ ${1:0:1} != / ]; then
		# invalid
		return 0
	else
		return 1
	fi
}

saveConf() {	# $1:INIT_SYSTEM
	INIT_SYSTEM=$1
	echo "PRISON_ROOT=$PRISON_ROOT" > /etc/prisonchroot.conf
	echo "INIT_SYSTEM=$INIT_SYSTEM" >> /etc/prisonchroot.conf
	echo "PRISON_HOSTNAME=$PRISON_HOSTNAME" >> /etc/prisonchroot.conf
}

# create our configuration based on user selection
echo "Welcome to the prisonchroot installer!";
echo ""
echo "You will now be asked a few questions to customize your prison system."
echo ""

while validateRootPath $PRISON_ROOT; do
	echo ""
	read -e -p "Base directory for jails (must not exist): " -i "/prisons" PRISON_ROOT
done

while [[ "$PRISON_HOSTNAME" = "" ]]; do
	echo ""
	read -e -p "Prison host name which is shown to jailed users: " -i "`hostname`" PRISON_HOSTNAME
done


mkdir -p $PRISON_ROOT/archive
chown root:root $PRISON_ROOT
chmod 755 $PRISON_ROOT

if [[ ! -d /usr/local ]]; then
	USRLOCAL=/usr
	sed -i "s|/usr/local|/usr|g" prisonchroot
	sed -i "s|/usr/local|/usr|g" prisonchroot.openrc
	sed -i "s|/usr/local|/usr|g" prisonchroot.systemd
	sed -i "s|/usr/local|/usr|g" prisonchroot.sysv
else
	USRLOCAL=/usr/local
fi

cp prisonchroot $USRLOCAL/bin
cp prisonchroot.inc.sh b101010.inc.sh $USRLOCAL/lib/.
chmod 700 $USRLOCAL/bin/prisonchroot $USRLOCAL/lib/prisonchroot.inc.sh $USRLOCAL/lib/b101010.inc.sh


# Detect whether to use rc-service, service, or systemctl to lauch us.
# Though enable and install options could go in service(), that would facilitate errors.
type rc-service > /dev/null 2>&1

if [[ $? == 0 ]]; then
	saveConf openrc

	cp prisonchroot.openrc /etc/init.d/prisonchroot
	rc-update add prisonchroot
	rc-service prisonchroot start
	exit 0
fi

type systemctl > /dev/null 2>&1

if [[ $? == 0 ]]; then
	saveConf systemd

	cp prisonchroot.systemd /etc/systemd/system/prisonchroot.service
	systemctl enable prisonchroot
	systemctl start prisonchroot
	exit 0
fi

type service > /dev/null 2>&1
if [[ $? == 0 ]]; then
	saveConf sysv-service
else
	saveConf sysv
fi

# default init system (assuming sysv)

cp prisonchroot.sysv /etc/init.d/prisonchroot

type chkconfig > /dev/null 2>&1

if [[ $? == 0 ]]; then
	chkconfig prisonchroot on
else
	type update-rc.d > /dev/null 2>&1

	if [[ $? == 0 ]]; then
		update-rc.d prisonchroot defaults
	else
		ln -s /etc/init.d/prisonchroot /etc/defaults/prisonchroot
	fi
fi


if [[ "$INIT_SYSTEM" = "sysv-service" ]]; then
	service prisonchroot start
else
	/etc/init.d/prisonchroot start
fi

