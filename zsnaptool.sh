#!/bin/bash

usage() {
cat <<END_OF_HELP
usage: $0 [options] srcpool destpool
Options are:
	-r	Take snapshots recursively
	-n	Dry run (no actions)
END_OF_HELP
}

zfs_exec() {
	if [ -z "$DRY" ]; then
		bash -c "$@"
	else
		log "cmd: $@"
	fi
}

log() {
	echo "[$(date +'%Y-%m-%d %H:%M:%S.%3N')] => $1"
}

SRCPOOL=""
DESTPOOL=""
RFLAG=""
DRY=""

while [ "$1" != "" ]; do
	case "$1" in
		-r)
			RFLAG="-r"
			;;
		-n)
			DRY=1
			;;
		*)
			if [ -z "$SRCPOOL" ]; then
				SRCPOOL=$1
			elif [ -z "$DESTPOOL" ]; then
				DESTPOOL=$1
			else
				echo "ERROR: too many arguments"
				usage
				exit 1
			fi
	esac
	shift
done

if [ "$SRCPOOL" == "" -o "$DESTPOOL" == "" ]; then
	usage
	exit 1
fi

if [ "$(zfs list -H -o name $SRCPOOL 2>/dev/null)" == "" ]; then
	echo "No such pool: $SRCPOOL"
	exit 2
fi

dest=
if [ "$(zfs list -H -o name $DESTPOOL 2>/dev/null)" == "" ]; then
	echo "No such pool: $DESTPOOL"
	exit 3
fi

export ALLFS=$(zfs list $RFLAG -H -o name $SRCPOOL)

for fs in $ALLFS; do
	prop=$(zfs get -H com.sun:auto-snapshot $fs|awk '{print $3}')
	if [ "$prop" == "false" ]; then
		#echo "Skipping $fs"
		continue
	fi
	log "Processing $fs"
	prefix="$(date +%Y)-$(date +%02m)-$(date +%02d)"

	# check if it already exists
	out=$(zfs list -H -o name $fs@$prefix 2>/dev/null)
	if [ "$out" == "" ]; then
		log "Creating $fs@$prefix"
		zfs_exec "zfs snap $fs@$prefix"
	else
		log "$fs@$prefix already exists"
		continue
	fi

	# find parent snapshot
	SNAPS=$(zfs list -H -o name -t snap -r -s name $fs)
	parent=""
	for snap in $SNAPS; do
		fscomp=$(echo $snap|awk -F'@' '{print $1}')
		if [ "$fscomp" == "$fs" ]; then
			if [ "$snap" == "$fs@$prefix" ]; then
				break
			fi
			parent=$snap
		fi
	done

	if [ "$parent" != "" ]; then
		log "Sending incremental from $parent to $DESTPOOL/$fs"
		zfs_exec "zfs send -i $parent $fs@$prefix | zfs receive -F $DESTPOOL/$fs"
	else
		log "Sending initial to $DESTPOOL/$fs"
		zfs_exec "zfs create -p $DESTPOOL/$fs"
		zfs_exec "zfs send $fs@$prefix | zfs receive -F $DESTPOOL/$fs"
	fi

	log "Finished $fs"
done
