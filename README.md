## Shell script to do incremental backups for ZFS pool
This script will create a snapshot of the given filesystem(s) and back it up using `zfs send/receive` commands.<br/>
Snapshots are backed up incrementally from the previous snapshots.

**NOTE**: This script has been only tested on Linux!

Usage:
`zsnaptool.sh [-r] [-n] [-v] SRCPOOL DSTPOOL`

Options:
* `-r` act recursively on a given SRCPOOL
* `-n` dry run - don't do anything, only print actions
* `-v` verbose output of the 'zfs send' command
* `SRCPOOL` source pool/filesystem, e.g. **rpool/root**
* `DSTPOOL` destination pool/filesystem, e.g. **backup/rpool**

