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

### work

Get some help, how to setup config file:
```
$ backup_this_machine.sh restic
```

### timemachine: walk through your old stuff
```
$ backup_this_machine.sh restic-mount
```
