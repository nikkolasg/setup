# Setup
Set of scripts / configs to setup a new laptop / server with Archlinux /customized mainly for myself/
# Usage

./init_laptop.sh <user> <operation>
<user> is the name of the user we want to do operations for.
<operation> can be one of the following:
* user:
  + create new user (given on cmd line)
  + install sudo & set user as sudoers
* pacman:
  + configure pacman & update repo
  + install predefined packages for laptop mode. 
* system:
  + install some common configuration files
* backup:
  + rsync data from backup server: 
    - BACKUP_SERVER ip address
    - BACKUP_USER name to connect with ssh
    - BACKUP_PATH path to sync with data folders in home
      It will sync all packages in download.rsync
    - It first asks the users these informations
  + install a cron job to periodically backup the folders in upload.rsync.
    The difference is to avoid downloading big files for a new setup.
* all: makes all operations by default
