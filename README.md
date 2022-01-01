=== setup ===
```
$ URL='https://raw.githubusercontent.com/bittorf/backup-this-machine/main/backup_this_machine.sh'
$ DESTINATION='/usr/local/bin/backup_this_machine.sh'
$ sudo wget -O  "$DESTINATION" "$URL"
$ sudo chmod +x "$DESTINATION"
```
=== work ===

Get some help, how to setup config file:
```
$ backup_this_machine.sh restic
```
This also needs a working [restic](https://restic.net/) installation, e.g.  
   sudo apt-get install restic

=== timemachine walk through your old stuff ===
```
$ backup_this_machine.sh restic-mount
```
