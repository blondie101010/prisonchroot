#!/bin/bash

source /etc/prisonchroot.conf

source /usr/local/lib/b101010.inc.sh

# Save the jails allowed commands.
jail_save_commands() {	#$1:jailName, $2-*:space delimited list of commands
	jailName=$1
	shift
	echo $* bash > $PRISON_ROOT/$jailName/.commands
}

# Add a new jail.
jail_add() {	# $1:jailName, $2:allowedCommands
	if [[ -d $PRISON_ROOT/$1 ]] || [[ -f $PRISON_ROOT/$1 ]]; then
		error "Jail '$1' already exists."
	fi

	groupadd $1
  
  	checkRet $? E

	mkdir -p $PRISON_ROOT/$1/.template/{dev,etc/conf.d,lib,usr/lib,lib64,usr/lib64,proc,usr/bin,bin,usr/share,share,home}

	chown -R root:root $PRISON_ROOT/$1
	chmod -R 755 $PRISON_ROOT/$1

	jail_save_commands $*

	jail_update	$1

	# add the new rule to /etc/ssh/sshd_config
	echo -e "\nMatch Group $1\n\tChrootDirectory $PRISON_ROOT/$1/%u\n\tAllowTcpForwarding no\n" >> /etc/ssh/sshd_config

	service restart sshd
}

# Update a jail and its users' environment.  It is used to update jailed environment after system updates or its initial creation.
jail_update() {	# $1:jailName, $2:allowedCommands (optional)
	if [[ "$jailName" = "archive" ]]; then
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
	mkdir -p $PRISON_ROOT/$1/.template/{dev,etc/conf.d,lib,usr/lib,lib64,usr/lib64,proc,usr/bin,bin,usr/share,share,home}

	FILES="$FILES $LD_LINUX"
	for file in $FILES
	do
		cp $file $PRISON_ROOT/$1/.template$file
	done

	# copy terminfo and basic configuration files
	cp -r /usr/share/terminfo/ $PRISON_ROOT/$1/.template/usr/share/.
	cp /etc/ld.so.conf $PRISON_ROOT/$1/.template/etc/.

	echo "HOSTNAME=$PRISON_HOSTNAME" >> $PRISON_ROOT/$1/.template/etc/profile
	cat /etc/profile >> $PRISON_ROOT/$1/.template/etc/profile

	cp -r /etc/terminfo $PRISON_ROOT/$1/.template/etc/.

	chmod -R o-w $PRISON_ROOT/$1/.template

	# set host name
	if [[ -f /etc/conf.d/hostname ]]; then
		echo 'hostname="'$PRISON_HOSTNAME'"' > $PRISON_ROOT/$1/.template/etc/conf.d/hostname
	else
		if [[ -f /etc/hostname ]]; then
			echo $PRISON_HOSTNAME > $PRISON_ROOT/$1/.template/etc/hostname
		fi
	fi

	if [[ ! -f /bin/bash ]]; then	# in case /bin/bash points to /usr/bin/bash
		ln /usr/bin/bash /bin/bash
	fi

	# copy locales
	cp -r /usr/lib/locale/ $PRISON_ROOT/$1/.template/usr/lib/.

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
	if [[ ! -d $PRISON_ROOT/$1 ]]; then
		error "Jail '$1' not found."
	fi

	groupdel $1

  	checkRet $? E

	jail_dev $1 umount

	rm -rf $PRISON_ROOT/$1/.commands $PRISON_ROOT/$1/.template

	# move users to archive
	mkdir -p $PRISON_ROOT/archive
	rm -rf $PRISON_ROOT/$1/*/{dev,etc,lib,lib64,usr,proc,bin,share}
	mv $PRISON_ROOT/$1/* $PRISON_ROOT/archive/.
	rmdir $PRISON_ROOT/$1

	warn "Jail removal successful.  Note that the 'Match' conditions in /etc/ssh/sshd_config do not get removed automatically for safety reasons."

	# user groups are not changed but it doesn't matter as they won't have any access
}

# Update a user's jailed environment.
jail_update_user() {	# $1:jailName, $2:userName
	jail_dev_user $1 $2 umount

	# remove everything in the user's jail except their home directory
	rm -rf $PRISON_ROOT/$1/$2/{dev,etc/conf.d,lib,lib64,usr/lib64,proc,usr/bin,bin,usr/share,share}

	if [[ "$jailName" = "archive" ]]; then
		return
	fi

	cp -alfL $PRISON_ROOT/$1/.template/{dev,etc,lib,lib64,usr,proc,bin,share} $PRISON_ROOT/$1/$2/.

	# force load of .bashrc
	echo "source /home/$2/.bashrc" >> $PRISON_ROOT/$1/$2/etc/profile
	
	jail_dev_user $1 $2 mount
}

# Add a jailed system user.
user_add() {	# $1:userName, $2:jailName
	if [[ ! -d $PRISON_ROOT/$2 ]]; then
		error "Destination jail '$2' doesn't exist."
	fi

	useradd -r -G $2 -d $PRISON_ROOT/$2/$1 $1

  	checkRet $? E

	mkdir -p $PRISON_ROOT/$2/$1/home/$1
	echo "HOME=/home/$1; cd ~; HOME=/home/$1; export PS1='$1@$PRISON_HOSTNAME \w \$ '; if [[ -f /home/$1/.profile ]]; then source /home/$1/.profile; fi" > $PRISON_ROOT/$2/$1/home/$1/.bashrc
	chmod 0755 $PRISON_ROOT/$2/$1/home/$1/.bashrc

	chown $1:$1 $PRISON_ROOT/$2/$1/home/$1

	jail_update_user $2 $1
}

# Move a user from one jail to another.
user_move() {	# $1:userName, $2:oldJail, $3:newJail
	if [[ ! -d $PRISON_ROOT/$2/$1 ]]; then
		error "User '$1' is not in jail '$2'."
	fi

	if [[ ! -d $PRISON_ROOT/$3 ]]; then
		error "Destination jail '$3' doesn't exist."
	fi

	usermod -G $3 -d $PRISON_ROOT/$3/$1 $1 2>/dev/null

  	checkRet $? E

	mv $PRISON_ROOT/$2/$1 $PRISON_ROOT/$3/$1 
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

	userdel $1

  	checkRet $? E

	jail_dev_user $jail $1 umount

	rm -rf $PRISON_ROOT/$jail/$1
}


# allow systemd to call jail_dev_all() directly here
if [[ "$1" = "jail_dev_all" ]]; then
	jail_dev_all $2
fi
