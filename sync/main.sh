#!/bin/bash

# ===============================================================
# do all the work for the icinga to use ldap data
# this file is supposed to be run as nagios user with cron
# ===============================================================


# ===============================================================
# generate roles for users
# ===============================================================
function generate_roles
{

  # TODO - volat pouze pri zmene
  # TODO - diff ldap sync souboru?

  role_file="/etc/icingaweb2/roles.ini"
  role_base="/etc/icingaweb2/roles_base.ini"
  cp $role_base $role_file      # copy base
  ./roles.js                    # generate realm amdin roles

  #admins=$(mysql -u icinga2 --password=$db_pass -e 'select uid from admin;' ldap_to_icinga | tail -n +2)
 
  #for i in $admins
  #do
  #  echo "admin: $i"
  #done 



}
# ===============================================================
# generate roles for users
# ===============================================================
function ldap_sync
{
  ./ldap_sync.js > /tmp/ldap_sync
  mysql ldap_to_icinga < /tmp/ldap_sync
}
# ===============================================================
# main
# ===============================================================
function main
{
  # TODO - vynucene spusteni jednou denne

  #source config/secrets.sh
  #ldap_sync
  generate_roles #- TODO - lepe v javascriptu?
}
# ===============================================================
main


