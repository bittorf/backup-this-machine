#!/bin/sh
# check: shellcheck --shell=dash /usr/local/bin/backup_this_machine.sh
#
# e.g. run rootjob with
# list_users() { grep "/bin/bash"$ /etc/passwd | cut -d':' -f1; }
# for U in $(list_users); do sudo -u $U backup_this_machine.sh restic; done
{

ACTION="$1"
ARG2="$2"

case "$ACTION" in
	restic-cronmode)
		# only work if cpu-load is OK (max half cpu-cores),
		# e.g. 4.xx or lower with 8 cores or 0.xx with 1 core
		CPU=1; for _ in /sys/devices/system/cpu/cpu[0-9]*; do CPU=$(( CPU + 1 )); done
		read -r LOAD REST </proc/loadavg && LOAD=${LOAD%.*}
		test "$LOAD" -le $(( CPU / 2 )) || exit 0
	;;
esac

USERNAME="$( whoami )"
COMPUTERNAME="$USERNAME-$( hostname || cat /etc/hostname )"	# e.g. bob-laptop
HOME="$( eval echo ~"$USERNAME" )"
ME="$( realpath "$0" || echo "$0" )"

# avoid double username:
case "$COMPUTERNAME" in "$USERNAME-$USERNAME-"*) COMPUTERNAME="${COMPUTERNAME#*-}" ;; esac

# also for overriding any of the vars above:
CONFIG="$HOME/.backup_this_machine.config"
LOCKDIR="$CONFIG.lock"

log()
{
	>&2 printf '%s\n' "$1"
}

lock()
{
	mkdir "$LOCKDIR" 2>/dev/null || return 1	# autounlocked in cleanup()
}

# shellcheck disable=SC1090
test -s "$CONFIG" && log "[OK] loading settings from '$CONFIG'" && . "$CONFIG"

usage_show()
{
	local me && me="$( basename "$ME" )"

	cat <<EOF
Usage: $me <full|restic|restic-and-suspend|restic-cronmode|restic-snapshots-list|restic-mount|restic-restore|update>

 e.g.: $me full
       $me restic
       $me restic-and-suspend
       $me restic-snapshots-list
       $me restic-mount
       $me restic-restore
       $me update

  see: https://github.com/bittorf/backup-this-machine

configured vars (defaults or from file '$CONFIG'):
 # USERNAME	=> $USERNAME
 # COMPUTERNAME	=> $COMPUTERNAME
 # HOME		=> $HOME
 # EXCLUDE	=> ${EXCLUDE:-*** <empty> ***}
 # OPT		=> ${OPT:-*** <empty> ***}
 # FLAGS        => ${FLAGS:-*** <empty> ***}
 # DESTINATION	=> $DESTINATION
 # SERVER	=> $SERVER
 # PASS		=> $PASS

EOF
}

check_essentials()
{
	[ -s "$CONFIG" ] || {
		log "[OK] generated a basic config file for you, see '$CONFIG'"

		cat >>"$CONFIG" <<EOF
#!/bin/sh
#
# this config file belongs to '$0'
# the filedate is used for marking the last good update in cronmode
# unmark to schedule the next backup with:
# touch -t 202011111200 '$CONFIG'
#
# uncomment and set these vars:
#DESTINATION="/tank/bastian/privat/backup/\${COMPUTERNAME}-restic-repo"
# setup autologin with this command: ssh-copy-id -p 443 user@hostname
#SERVER="sftp://bastian@bwireless.mooo.com:443"
#PASS='a secret password'

# you can also mark not-to-backup directories like proposed in https://bford.info/cachedir/
# echo 'Signature: 8a477f597d28d172789f06886806bc55' >my/dir/CACHEDIR.TAG"
#
#EXCLUDE="\$EXCLUDE \$HOME/ssd \$HOME/.steam \$HOME/kannweg \$HOME/Downloads"

# uncomment this for storing ssh-keys, passwords and network-configs
# for cronjobs add next line to '/etc/sudoers.d/$( basename "$0" '.sh' )'"
#    $USER ALL = (ALL) NOPASSWD: $ME"
#
#SUDO=true

# uncomment for automatic updates in cronmode
#AUTOUPDATE=true

# values are in [kilobits/sec]
#FLAGS="--limit-upload 200 --limit-download 3000"

EOF
		return 1
	}

	[ -n "$DESTINATION" ] || {
		echo "please define backup location in '$CONFIG' or in environment:"
		echo "DESTINATION=\"/tank/bastian/privat/backup/\${COMPUTERNAME}-restic-repo\""
		return 1
	}

	[ -n "$SERVER" ] || {
		echo "please define server and protocol in '$CONFIG' or in environment:"
		echo 'SERVER="sftp://user@my.domain.tld:443"'
		return 1
	}

	[ -n "$PASS" ] || {
		echo "please define backup-password in '$CONFIG' or in environment:"
		echo 'PASS="foo bar baz"'
		return 1
	}

	[ -n "$EXCLUDE" ] || {
		echo "please define an EXCLUDE var, e.g.:"
		echo "EXCLUDE=\"\$HOME/.steam \$HOME/kannweg \$HOME/Downloads\""
		return 1
	}

	command -v 'restic' >/dev/null || {
		echo "please install restic, see: https://restic.net/"
		return 1
	}
}

update()
{
	BASE='https://raw.githubusercontent.com/bittorf'
	URL="$BASE/backup-this-machine/main/backup_this_machine.sh"
	DESTINATION="$ME"
	TEMP="$( mktemp )" || exit 1

	log "[OK] checking '$URL'"
	wget -qO "$TEMP" "$URL" || exit $?

	# some plausibility checks:
	tail -n1 "$TEMP" | grep -q '}' || exit $?
	sh -n "$TEMP" || exit $?

	if cmp "$TEMP" "$DESTINATION"; then
		log "[OK] no change detected"
	else
		log "[OK] sudo: download + install"
		log "     from '$URL'"
		log "     to '$DESTINATION'"

		sudo cp  "$TEMP" "$DESTINATION" || exit $?
		sudo chmod +x    "$DESTINATION" && log "[OK] updated"
	fi

	rm -f "$TEMP"
}

case "$ACTION" in
	restic-cronmode)
		UNIXTIME="$( date +%s )"
		UNIXFILE="$( date +%s -r "$CONFIG" )"	# touched after successful backup
		FILE_AGE=$(( UNIXTIME - UNIXFILE ))

		if test "$FILE_AGE" -lt 86400; then
			exit 0
		else
			test "$AUTOUPDATE" = true && update
			ACTION='restic'
		fi
	;;
	restic-restore)
	;;
	full|restic|restic-and-suspend|restic-snapshots-list|restic-mount)
		check_essentials || exit 1
	;;
	help)
		check_essentials
		log "### start"
		cat "$CONFIG"
		log "### end of file '$CONFIG'"
		exit
	;;
	add_secrets)
	;;
	update)
		update
		exit 0
	;;
	*)
		usage_show && exit 1
	;;
esac

rootuser_allowed()
{
	test "$SUDO" = true
}

runs_as_root()
{
	test "$( id -u )" -eq 0
}

cleanup()
{
	local dir="$1"

	test -d "$LOCKDIR" && rm -fR "$LOCKDIR"

	test -d "$dir" && {
		rm -fR "$dir"
		log
		log "[OK] cleanup: removed tempdir '$dir'"
	}
}

prepare_usrlocalbin()
{
	local dir="$1"

	log "[OK] creating and filling directory '$dir'"

	if lock && mkdir "$dir"; then
		# shellcheck disable=SC2064
		trap "cleanup '$dir'" HUP INT QUIT TERM EXIT
	else
		log "[ABORT] directory already exists: '$dir'"
		exit 1
	fi

	cp -p -R /usr/local/bin/                   "$dir"

	[ -f /etc/rc.local ] && cat /etc/rc.local >"$dir/etc-rc.local"

	crontab -l 2>/dev/null >/dev/null && \
		crontab -l >"$dir/crontab.txt"

	if rootuser_allowed; then
		log "[HINT] for cronjobs add e.g. to '/etc/sudoers.d/$( basename "$0" '.sh' )' this line:"
		log "       $USER ALL = (ALL) NOPASSWD: $ME"
		log
		log "[sudo] will execute: sudo $0 add_secrets '$dir'"
		sudo "$0" add_secrets "$dir" || exit 1
	else
		log
		log "[HINT] run with SUDO=true for storing ssh-keys, passwords and network-configs"
		log "       e.g. SUDO=true $0 $ACTION $ARG2"
		log
		log "[HINT] for cronjobs add e.g. to '/etc/sudoers.d/$( basename "$0" '.sh' )' this line:"
		log "       $USER ALL = (ALL) NOPASSWD: $ME"
	fi

	log
	ip address show	>"$dir/ip-address-show.txt"
	ip route show	>"$dir/ip-route-show.txt"

	find /etc/network/interfaces /etc/network/interfaces.d -type f -exec echo "{}" \; | while read -r LINE; do {
		echo "### file: $LINE"
		cat "$LINE"
		echo
	} done >"$dir/etc-network-interfaces.txt"
}

do_suspend()	# https://askubuntu.com/questions/1792/how-can-i-suspend-hibernate-from-command-line
{
	dbus-send --system --print-reply \
		  --dest="org.freedesktop.UPower" \
			"/org/freedesktop/UPower" \
			 "org.freedesktop.UPower.Suspend"
}

OPT="$( for DIR in $EXCLUDE $HOME/.cache; do printf '%s ' "--exclude $DIR"; done ) --exclude-caches"

case "$ACTION" in
	'full')
		# fall through
	;;
	'add_secrets')
		DIR="$ARG2"
		USER_AND_GROUP="$( stat -c "%U:%G" "$DIR" )"

		cat /etc/passwd >"$DIR/etc-passwd"
		cat /etc/shadow >"$DIR/etc-shadow"

		# e.g. /etc/ssh/ssh_host_rsa_key
		#      /etc/ssh/ssh_host_rsa_key.pub
		for FILE in /etc/ssh/ssh_host_*; do {
			[ -f "$FILE" ] && cp "$FILE" "$DIR"
		} done

		# network and wifi-configs and passwords:
		[ -d /var/lib/wicd/configurations ] && {
			tar cf "$DIR/wicd.tar" /var/lib/wicd/configurations 2>/dev/null
		}

		[ -d /etc/NetworkManager ] && {
			tar cf "$DIR/networkmanager.tar" /etc/NetworkManager 2>/dev/null
		}

		chown -R "$USER_AND_GROUP" "$DIR"
		exit 0
	;;
	'restic'|'restic-and-suspend'|'restic-snapshots-list'|'restic-mount'|'restic-restore')
		REPO="$SERVER:$DESTINATION"	# oldstyle?
		REPO="$SERVER/$DESTINATION"

		case "$ACTION" in
			'restic-snapshots-list')
				RESTIC_PASSWORD=$PASS restic -r "$REPO" snapshots
				exit $?
			;;
			'restic-mount')
				MOUNTDIR="$( mktemp -d )" || exit 1

				# shellcheck disable=SC2064
				trap "cleanup '$MOUNTDIR'" HUP INT QUIT TERM EXIT

				log "[OK] trying to mount in directory '$MOUNTDIR'"
				RESTIC_PASSWORD=$PASS restic -r "$REPO" mount "$MOUNTDIR"

				exit $?
			;;
			'restic-restore')
				# TODO: crontab + ssh + password
				# shellcheck disable=SC2086
				RESTIC_PASSWORD=$PASS restic -r "$REPO" restore latest --target /
				exit $?
			;;
		esac

		prepare_usrlocalbin "$HOME/usr-local-bin"

		# shellcheck disable=SC2086
		if RESTIC_PASSWORD=$PASS restic -r "$REPO" $OPT --verbose backup $FLAGS "$HOME"; then
			touch "$CONFIG"		# mark as 'done' using file timestamp
		else
			RC=$?
			log
			log "[ERROR] restic exited with rc $RC"
			log "        maybe this is your first time and you must initialize your repository like:"
			log "        RESTIC_PASSWORD=$PASS restic -r \"$REPO\" init"
		fi

		[ "$ACTION" = 'restic-and-suspend' ] && do_suspend
		exit ${RC:-0}
	;;
esac

log "[OK] running full backup (uncompressed tarball)"

VERSION="$1"			# TODO: autoincrement if /dev/shm/COUNTER is from today

SERVER="bastian@10.63.22.98"	# TODO: autobuild
DEST_FILE="backup-$COMPUTERNAME-$( LC_ALL=C date +%Y%b%d )-${VERSION:-v1}"
DEST_DIR="/tank/bastian/privat/backup"

cd ~  || exit		# go one step below homedir:
cd .. || exit		# e.g. /home/user -> /home or
			# e.g. /root -> /

log "[OK] pwd: '$PWD' server: $SERVER destination: $DEST_DIR/$DEST_FILE"

S1="$( date +%s )"
# shellcheck disable=SC2029
tar -cf - --one-file-system /usr/local/bin '/etc/rc.local' | ssh $SERVER "cat >$DEST_DIR/${DEST_FILE}-usr-local-bin.tar"
R1=$?
S2="$( date +%s )"
D1=$(( S2 - S1 ))

S1="$( date +%s )"
# shellcheck disable=SC2029
tar                                              -cf - --one-file-system "$USERNAME" | ssh $SERVER "cat >$DEST_DIR/${DEST_FILE}-home.tar"
# shellcheck disable=SC2029
test "$PWD" = '/' && tar --exclude="./$USERNAME" -cf - --one-file-system .           | ssh $SERVER "cat >$DEST_DIR/${DEST_FILE}-rootdir.tar"
R2=$?
S2="$( date +%s )"
D2=$(( S2 - S1 ))

# tgz + verbose = 23/9743 -> 68gig
# tar + quiet   = 29/7553 -> 81gig
log "OK - needed: $D1/$D2 seconds, returncodes: $R1/$R2"

}
