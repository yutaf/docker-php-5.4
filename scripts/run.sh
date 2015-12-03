#!/usr/bin/env bash

# php session
mkdir -m 777 -p /srv/php/session
echo "tmpfs /srv/php/session tmpfs size=32m,mode=700,uid=apache,gid=apache 0 0" >> /etc/fstab
mount /srv/php/session # need docker run "--cap-add=SYS_ADMIN" option

# php upload_tmp_dir
mkdir -m 777 -p /srv/php/upload_tmp_dir

# make log directories
test -d /srv/www/logs/access || mkdir -m 777 -p /srv/www/logs/access
test -d /srv/www/logs/error || mkdir -m 777 -p /srv/www/logs/error
test -d /srv/www/logs/app || mkdir -m 777 -p /srv/www/logs/app
cd /srv/www/logs
chmod 777 access error app
cd -

#
# Run container foreground
#

# supervisor
/usr/bin/supervisord
