### setup
Download script and make it executable:
```
$ BASE='https://raw.githubusercontent.com/bittorf'
$ URL="$BASE/backup-this-machine/main/backup_this_machine.sh"
$ DESTINATION='/usr/local/bin/backup_this_machine.sh'
$
$ sudo wget -O  "$DESTINATION" "$URL"
$ sudo chmod +x "$DESTINATION"
```
You can later update it using:
```
$ backup_this_machine.sh update
```
It needs a working [restic](https://restic.net/) installation:
```
$ sudo apt-get install restic
```
Get some help, how to setup config file:
```
$ backup_this_machine.sh help
```

### backup
```
$ backup_this_machine.sh restic
# or:
$ backup_this_machine.sh restic-and-suspend
```

## restore
```
$ export PASS=...
$ export SERVER="sftp://user@your.host.name:443"
$ export DESTINATION="/path/to/restic-dir/on/server"
$ backup_this_machine.sh restic-restore
```

### timemachine: walk through your old stuff
```
$ backup_this_machine.sh restic-mount
```
