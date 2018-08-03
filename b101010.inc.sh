#!/bin/bash

# Blondie101010's basic shell script library.
# It will be done progressively based on other open source project requirements.

if [[ $b101010 > 0 ]]; then	# script already included
	return 0
fi

# define version which is also used to know if the script was already included
b101010=1

# Show a warning.
warn() {	# $1:message
	echo -e "\n\e[1;33m$1\e[0m"
}

# Output an error message and exit.
error() {	# $1:errorMessage
	echo -e "\n\e[1;31m$1\e[0m"
	exit 1
}

# Prompt for confirmation and abort if the user enters anything other than 'y'.
confirm() {
	echo ""
	read -e -p "Are you sure? [y/N] " yn

	case "$yn" in
		[yY])
			return
		;;

		*)
			error aborting
		;;
	esac
}

# Validate the return value and output a warning or error when appropriate.
checkRet() {	# $1:$?, $2:operation ('W'arn/'E'rror)
	message="An error occured.  Its description should appear above."

	if [[ $1 != 0 ]]; then
		case "$2" in
			[wW]) warn $message;;
			[eE]) error $message;;
			*) error "Invalid operation passed to checkRet(): '$2'."
		esac
	fi
}

# Run the system's init service controller.
# Note that install and remove operations were intentionally left out for now as they might increase the risk of manual errors.
service() {	# $1:operation, $2:unit
	case "$1" in
		start|stop|restart) ;;# all ok
		*) error "Invalid service operation ($1).";;
	esac

	case "$INIT_SYSTEM" in
		"openrc")
			rc-service $2 $1
		;;

		"systemd")
			systemctl $1 $2
		;;

		"sysv")
			/etc/init.d/$2 $1
		;;

		"sysv-service")
			/sbin/service $2 $1
		;;
	esac
}

getEnvOrPrompt() {	# $1:varName, $2:prompt, [$3:default]
	_val=${!1}
	if [[ "$_val" = "" ]]; then
		echo ""
		read -e -p "$2" -i "$3" $1
	else
		echo "Using predefined $1=$_val.";
	fi
}



