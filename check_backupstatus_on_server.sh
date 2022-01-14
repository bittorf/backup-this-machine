#!/bin/sh

MAINDIR='/tank/bastian/privat/backup'
PATTERN="-restic-repo"

echo "# directories in '$MAINDIR' with pattern '$PATTERN'"
echo

find "$MAINDIR" -maxdepth 1 -type d -name "*$PATTERN*" | while read -r LINE; do {
	BASE="$( basename "$LINE" | sed "s/$PATTERN//" )"
	DIR="$LINE/snapshots"

	test -d "$DIR" && {
		NEWEST_FILE="$( find "$DIR" -type f -printf "%T@|%p\n" | sort -n | tail -n1 | cut -d'|' -f2 )"
		UNIX="$( date +%s -r "$NEWEST_FILE" )"
		DATE="$( date -d "@$UNIX" )"

		for SIZE in $( du -sh "$LINE" ); do break; done
		SIZE="$( printf '%5s\n' "$SIZE" )"

		echo "$UNIX | $DATE | $SIZE | $BASE"
	}
} done | sort -rn
