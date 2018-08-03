# prisonchroot
Simple multi-jail system for ssh and sftp.

## Introduction

This small package serves as defining a simple jail on many Unix/Linux compatible operating systems.

It contains the following features:
- give each user their own restrained environment
- complete isolation from the host system's directory tree
- low storage requirements by hard-linking files to a template
- installation supports classic sysv, open-rc, and systemd init systems
- support any number of jails
- allows per jail `ulimit` configuration
- create a jailed user in a single easy step
- users can be moved from one jail to another
- jail command lists can be easily updated
- no deamon is used; the startup script is only to do the /dev bind-mount
- changes are live; no need to close the session

## System requirements

Although the included scripts are very generic, their testing on various systems is still ongoing.

The only absolute minimum requirement is the presence of `/bin/bash`.

## Installation

We provide two alternative installation methods depending on whether you have `wget` or `git` installed.

### Installation with `wget`

    cd /tmp; mkdir prisonchroot; cd prisonchroot; wget https://github.com/blondie101010/prisonchroot/archive/master.tar.gz && tar -xzf master.tar.gz && cd prisonchroot-master && ./prisonchroot-install.sh && rm -rf /tmp/prisonchroot; cd ~

### Installation with `git`

    cd /tmp; git clone https://github.com/blondie101010/prisonchroot && cd prisonchroot && ./prisonchroot-install.sh && rm -rf /tmp/prisonchroot; cd ~

### Stream-lining the installation

The installation script will not prompt you for acceptable parameters that are predefined in the environment.  The two applicable parameters are:

	name		default		criteria
	_______________	_______________	_______________________________________	
	PRISON_ROOT	/prisons	must not exist and has to be writable
	PRISON_HOSTNAME	real hostname	must not be blank

## Configuration files

`prisonchroot` uses only a few configuration files (other than imported system-wide configurations):

    - `/etc/prisonchroot.conf`: defined automatically during the installation
    - `/etc/security/limits-$jailName.conf`: if such a file exists when the jail (corresponding to $jailName) gets created or updated, this file is copied to the `chroot`ed environment's `/etc/security/limits.conf`

## Syntax

To get its syntax, you can simply call the main script without any or bad parameters:

    prisonchroot

As shown, the command can either apply to a jail or a user.  The resulting syntax details can be obtained with:

    prisonchroot user

and

    prisonchroot jail

### Example

#### create 2 jails with 2 users each

    prisonchroot jail add maxsecurity "ls cp vi bash"
    prisonchroot user add um00001 maxsecurity
    prisonchroot user add um00002 maxsecurity
    prisonchroot jail add looser "ls cp vi bash php more cat"
    prisonchroot user add ul00001 looser
    prisonchroot user add ul00002 looser

Note that the jail and user names used are only for illustrative purposes.

#### move a user to a different jail

    prisonchroot user move ul00001 looser maxsecurity

#### change allowed commands

    prisonchroot jail update looser "ls cp vi bash php more cat less dd"

#### delete a jailed user

    prisonchroot user del um00002
or avoid confirmation with `-f`:

    prisonchroot user del -f um00002

The system user and all their files are removed.

#### delete a jail

    prisonchroot jail del looser
or avoid confirmation with `-f`:

    prisonchroot jail del -f looser

Users from that jail are moved to the 'archive' jail which is only usable for sftp.  Those user accounts are therefore disabled until they are moved to another jail.

## Status

This project is currently in testing phase.  It is not recommended to use it on production yet, but everyone is encouraged to test it out and send us any issues and suggestions you find.

So far it has a 100% test rate on Gentoo and CentOS 7, and minor issues on CentOS 6.
