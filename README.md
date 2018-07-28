# prisonchroot
Simple multi-jail system for ssh and sftp.

## Introduction

This small package serves as defining a simple jail on many Unix/Linux compatible operating systems.

It contains the following features:
- give each user their own restrained environment
- limit storage requirements by hard-linking files to a template
- installation supports classic sysv, open-rc, and systemd init systems
- support any number of jails
- create a jailed user in a single easy step
- users can be moved from one jail to another
- jail command lists can be easily updated

## Installation

Single step installation coming soon.

## Syntax

To get its syntax, you can simply call the main script without any parameters:
    prisonchroot

As shown, the command can either apply to a jail or a user.  The resulting syntax details can be obtained with:
    prisonchroot user
and
    prisonchroot jail

### Example

In this example, we will create 2 jails with 2 users each.

    prisonchroot jail add maxsecurity "ls cp vi bash"
    prisonchroot user add um00001 maxsecurity
    prisonchroot user add um00002 maxsecurity
    prisonchroot jail add looser "ls cp vi bash php more cat"
    prisonchroot user add ul00001 looser
    prisonchroot user add ul00002 looser

Note that the jail and user names used are only for illustrative purposes.

    # now if you want to move a user
    prisonchroot user move ul00001 looser maxsecurity

The user will be in the new jail when they open a new session.
