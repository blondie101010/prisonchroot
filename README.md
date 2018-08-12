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
- create a jailed user in a single easy step
- users can be moved from one jail to another
- jail command lists can be easily updated
- no deamon is used; the startup script is only to do the /dev bind-mount
- changes are live without needing to close the session;  some systems allow the session to remain active even when the user is deleted or archived, but they have access to nothing
- support for selinux when active

## System requirements

Although the included scripts are very generic, their testing on various systems is still ongoing.

The only absolute minimum requirement is the presence of `/bin/bash`.

> Note that `/etc/ssh/ssh_config` must not include any `Match` instruction before the installation.  Once the installation is complete, you are free to add and remove your own condition blocks.
> The `prisonchroot` installer first takes a backup of your initial configuration file in `/etc/ssh/sshd_config.prisonchroot.bak`.

## Installation

`prisonchroot` can be installed by running the following command:

	bash <(curl -L -Ss https://raw.githubusercontent.com/blondie101010/prisonchroot/master/prisonchroot-install.sh)


### Stream-lining the installation

The installation script will not prompt you for acceptable parameters that are predefined in the environment.  The two applicable parameters are:

	name		default		criteria
	_______________	_______________	_______________________________________	
	PRISON_ROOT	/prisons	must not exist and has to be writable
	PRISON_HOSTNAME	real hostname	must not be blank

## Configuration file

`prisonchroot` has a single configuration file (other than imported system-wide configurations):

- `/etc/prisonchroot.conf`: defined automatically during the installation and should not be modified manually

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

This project is currently in beta testing phase.  It is still not recommended to use it on production, but it has been quite extensively tested on the following setups:

	System	Version	with selinux	without selinux
	_______	_______	_______________ _______________
	Gentoo 	current	not tested	pass
	CentOS	6	pass		pass
	CentOS	7	not tested	pass
	Ubuntu	14.04	not tested	pass
	Ubuntu	16.04	not tested	pass
	Debian	7	not tested	pass
	Debian	8	not tested      pass
	Fedora	25	not tested	pass

Our current suggestion is to run through a series of tests on the target server before you implement it for real users.  The provide examples combined with proper testing of the jailed environment should allow you to properly evaluate the `prisonchroot` functionality on your specific system.

Please submit any issues and suggestions you may come up with on GitHub.

