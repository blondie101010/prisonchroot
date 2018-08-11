#!/bin/bash

source /etc/prisonchroot.conf

source /usr/local/lib/b101010.inc.sh
source /usr/local/lib/b101010-system.inc.sh

# Save the jails allowed commands.
jail_save_commands() {	#$1:jailName, $2-*:space delimited list of commands
	jailName=$1
	shift

	# `bash` is needed on all systems and `id` is used in many /etc/profile which we use to deal with basic options and environment
	FORCED_COMMANDS="bash id"

	echo $* $FORCED_COMMANDS > $PRISON_ROOT/$jailName/.commands
}

# Add a new jail.
jail_add() {	# $1:jailName, $2:allowedCommands
	if [[ -d $PRISON_ROOT/$1 ]] || [[ -f $PRISON_ROOT/$1 ]]; then
		error "Jail '$1' already exists."
	fi

	groupadd $1
  
  	checkRet $? E

	mkdir -p $PRISON_ROOT/$1/.template/{dev,etc/conf.d,etc/security,lib,usr/libexec/openssh,usr/lib,lib64,usr/lib64,proc,usr/bin,bin,usr/share,share,home}

	chown -R root:root $PRISON_ROOT/$1
	chmod -R 755 $PRISON_ROOT/$1

	jail_save_commands $*

	jail_update	$1

	# add the new rule to /etc/ssh/sshd_config
	echo -e "\nMatch Group $1\n\tChrootDirectory $PRISON_ROOT/$1/%u\n\tAllowTcpForwarding no\n" >> /etc/ssh/sshd_config

	serviceControl restart sshd
}

# Update a jail and its users' environment.  It is used to update jailed environment after system updates or its initial creation.
jail_update() {	# $1:jailName, $2:allowedCommands (optional)
	if [[ "$jailName" = "archive" ]]; then
		# we do nothing in 'archive'
		return
	fi

	if [[ $# > 1 ]]; then
		jail_save_commands $*
	fi

	export FILES=
	for prog in `cat $PRISON_ROOT/$1/.commands`; do
		filename=`which $prog 2> /dev/null`
		if [[ $? != 0 ]]; then
			continue
		fi

		echo "Installing $filename in '$1' jail."

		FILES="$FILES `ldd $filename | awk '{ print $3 }' | grep -v '('` $filename"
		LD_LINUX=`ldd $filename | grep ld-linux | awk '{ print $1 }'`
	done

	rm -rf $PRISON_ROOT/$1/.template
	mkdir -p $PRISON_ROOT/$1/.template/{dev,etc/conf.d,etc/security,lib,usr/libexec/openssh,usr/lib,lib64,usr/lib64,proc,usr/bin,bin,usr/share,share,home}

	FILES="$FILES $LD_LINUX"
	for file in $FILES
	do
		_dir=`dirname $file`

		if [[ ! -d $PRISON_ROOT/$1/.template/$_dir ]]; then
			mkdir $PRISON_ROOT/$1/.template/$_dir
		fi

		cp $file $PRISON_ROOT/$1/.template$file
	done

	# copy terminfo and basic configuration files
	cp -r /usr/share/terminfo/ $PRISON_ROOT/$1/.template/usr/share/.

	if [[ -d /lib/terminfo ]]; then
		cp -r /lib/terminfo $PRISON_ROOT/$1/.template/lib/.
	fi

	cp /etc/ld.so.conf $PRISON_ROOT/$1/.template/etc/.

        echo "HOSTNAME=$PRISON_HOSTNAME" > $PRISON_ROOT/$1/.template/etc/profile
        cat /etc/profile >> $PRISON_ROOT/$1/.template/etc/profile

	cp -r /etc/terminfo $PRISON_ROOT/$1/.template/etc/.

	if [[ -d /etc/security ]]; then
		cp -r /etc/security $PRISON_ROOT/$1/.template/etc/.
	fi

	# set host name
	if [[ -f /etc/conf.d/hostname ]]; then
		echo 'hostname="'$PRISON_HOSTNAME'"' > $PRISON_ROOT/$1/.template/etc/conf.d/hostname
	else
		if [[ -f /etc/hostname ]]; then
			echo $PRISON_HOSTNAME > $PRISON_ROOT/$1/.template/etc/hostname
		fi
	fi

	# copy locales
	cp -r /usr/lib/locale/ $PRISON_ROOT/$1/.template/usr/lib/.

	chown -R root:root $PRISON_ROOT/$1/.template
	chmod -R o-w $PRISON_ROOT/$1/.template

	# update user jails from .template
	for user in `ls $PRISON_ROOT/$1`; do
		jail_update_user $1 $user
	done
}

# Update all jails and their users' environment.  Its main use is to update jailed environment after system updates.
jail_update_all() {
	for jail in `ls $PRISON_ROOT/`; do
		jail_update $jail
	done
}

# Bind mount or umount /dev for all jailed users.  This is done on system boot and shutdown.
jail_dev_all() {	# $1:[mount|umount]
	for jail in `ls $PRISON_ROOT/`; do
		if [[ "$jail" = "archive" ]]; then
			continue
		fi

		jail_dev $jail $1
	done
}

# Bind mount or umount /dev/for the specified user.
jail_dev_user() {	# $1:jailName, $2:username, $3:[mount|umount]
	# umount first to ensure we don't double-mount them
	umount $PRISON_ROOT/$1/$2/dev/pts 2> /dev/null
	umount $PRISON_ROOT/$1/$2/dev 2> /dev/null

	mount|grep "$2" > /dev/null 2>&1
	if [[ $? = 0 ]]; then
		# we must kill the session
		_pid=`lsof $PRISON_ROOT/$1/$2/dev/pts|grep "/$2/"|head -1| awk '{print $2}'`

		if [[ $PRISONCHROOT_DEBUG = 1 ]]; then
			echo "killing session with pid: $_pid"
		fi

		kill -9 $_pid

		# make sure the umount succeeds (recursively)
		sleep 1
		jail_dev_user $1 $2 $3
		return
	fi

	if [[ "$3" = "mount" ]]; then
		mount --bind /dev $PRISON_ROOT/$1/$2/dev
		mount --bind /dev/pts $PRISON_ROOT/$1/$2/dev/pts
	fi
}

# Bind mount or umount /dev for the specified jail's users.  This is done on system boot and shutdown, and in jail_del.
jail_dev() {	# $1:jailName, $2:[mount|umount]
	for user in `ls $PRISON_ROOT/$1/`; do
		jail_dev_user $1 $user $2
	done
}

# Delete a jail.  Member users are moved to the 'archive' jail which blocks everything.
jail_del() { # $1:jailName
	if [[ "$1" = "archive" ]]; then
		error "The 'archive' jail can not be deleted."
	fi

	if [[ ! -d $PRISON_ROOT/$1 ]]; then
		error "Jail '$1' not found."
	fi

	jail_dev $1 umount

	groupdel $1

  	checkRet $? E

	rm -rf $PRISON_ROOT/$1/.commands $PRISON_ROOT/$1/.template

	# move users to archive
	mkdir -p $PRISON_ROOT/archive
	rm -rf $PRISON_ROOT/$1/*/{etc,lib,lib64,usr,proc,bin,share}
	mv $PRISON_ROOT/$1/* $PRISON_ROOT/archive/.
	rmdir $PRISON_ROOT/$1

	warn "Jail removal successful.  Note that the 'Match' conditions in /etc/ssh/sshd_config do not get removed automatically for safety reasons."

	# user groups are not changed but it doesn't matter as they won't have any access
}

# Update a user's jailed environment.
jail_update_user() {	# $1:jailName, $2:userName
	# remove everything in the user's jail except their home directory and /dev
	rm -rf $PRISON_ROOT/$1/$2/{etc/conf.d,lib,lib64,usr/lib64,proc,usr/bin,bin,usr/share,share}

	if [[ "$jailName" = "archive" ]]; then
		return
	fi

	cp -alfL $PRISON_ROOT/$1/.template/{lib,lib64,usr,proc,bin,share} $PRISON_ROOT/$1/$2/.

	# keep etc separate for certain user level customizations like the profile
	cp -r $PRISON_ROOT/$1/.template/etc $PRISON_ROOT/$1/$2/.

	if [[ ! -f $PRISON_ROOT/$1/$2/bin/bash ]]; then	# in case /bin/bash points to /usr/bin/bash
		ln $PRISON_ROOT/$1/$2/usr/bin/bash $PRISON_ROOT/$1/$2/bin/bash
	fi

	# symlink sh if applicable
	if [[ ! -f $PRISON_ROOT/$1/.template/bin/sh ]]; then
		ln -s /bin/bash $PRISON_ROOT/$1/$2/bin/sh
	fi

	# populate /etc/passwd file
	grep $2 /etc/passwd|sed "s|prisons/$1|home|" > $PRISON_ROOT/$1/$2/etc/passwd

	mkdir -p $PRISON_ROOT/$1/$2/prisons/$1
	ln -s /home/$2 $PRISON_ROOT/$1/$2/prisons/$1/$2
	chown $2:$2 $PRISON_ROOT/$1/$2/prisons/$1/$2

	# wrap the whole chroot /etc/profile in an stderr redirect
	echo "(" > $PRISON_ROOT/$1/$2/etc/profile
	cat $PRISON_ROOT/$1/.template/etc/profile >> $PRISON_ROOT/$1/$2/etc/profile
	echo ") 2> /dev/null" >> $PRISON_ROOT/$1/$2/etc/profile

	echo "HOME=/home/$2; export PS1='$2@$PRISON_HOSTNAME \w \$ '; cd \$HOME; if [[ -f /home/$2/.profile ]]; then source /home/$2/.profile; fi" >> $PRISON_ROOT/$1/$2/etc/profile
}

# Add a jailed system user.
user_add() {	# $1:userName, $2:jailName
	if [[ ! -d $PRISON_ROOT/$2 ]]; then
		error "Destination jail '$2' doesn't exist."
	fi

	useradd -r -G $2 -s /bin/bash -d $PRISON_ROOT/$2/$1 $1

  	checkRet $? E

	mkdir -p $PRISON_ROOT/$2/$1/dev
	chmod 755 $PRISON_ROOT/$2/$1/dev
	jail_dev_user $2 $1 mount
	mkdir -p $PRISON_ROOT/$2/$1/tmp
	chmod 1777 $PRISON_ROOT/$2/$1/tmp
	mkdir -p $PRISON_ROOT/$2/$1/home/$1

	chown $1:$1 $PRISON_ROOT/$2/$1/home/$1

	jail_update_user $2 $1
}

# Move a user from one jail to another.
user_move() {	# $1:userName, $2:oldJail, $3:newJail
	if [[ "$2" = "$3" ]]; then
		error "Source and destination must be different."
	fi

	if [[ ! -d $PRISON_ROOT/$2/$1 ]]; then
		error "User '$1' is not in jail '$2'."
	fi

	if [[ ! -d $PRISON_ROOT/$3 ]]; then
		error "Destination jail '$3' doesn't exist."
	fi

	usermod -G $3 -d $PRISON_ROOT/$3/$1 $1

  	checkRet $? E

	mv $PRISON_ROOT/$2/$1 $PRISON_ROOT/$3/$1 

	if [[ "$2" = "archive" ]]; then
		jail_dev_user $3 $1 mount
	else
		if [[ "$3" = "archive" ]]; then
			jail_dev_user $3 $1 umount
		fi
	fi

	jail_update_user $3 $1
}

# Delete a system user and all their files.
user_del() {	# $1:userName
	found=0
	for jail in `ls $PRISON_ROOT/`; do
		if [[ -d $PRISON_ROOT/$jail/$1 ]]; then
			found=1
			break
		fi
	done

	if [[ $found = 0 ]]; then
		error "User '$1' was not found in any jail."
	fi

	jail_dev_user $jail $1 umount

	userdel $1

  	checkRet $? E

	rm -rf $PRISON_ROOT/$jail/$1
}


# allow systemd to call jail_dev_all() directly here
if [[ "$1" = "jail_dev_all" ]]; then
	jail_dev_all $2
fi
