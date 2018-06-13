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
  role_file="/etc/icingaweb2/roles.ini"
  role_base="/etc/icingaweb2/roles_base.ini"
  cp $role_base $role_file      # copy base
  ./roles.js                    # generate realm amdin roles
}
# ===============================================================
# generate roles for users
# ===============================================================
function ldap_sync
{
  if [[ -f /tmp/ldap_sync ]]
  then
    cp /tmp/ldap_sync /tmp/ldap_sync.old
  fi
  ./ldap_sync.js $1 > /tmp/ldap_sync
  mysql ldap_to_icinga < /tmp/ldap_sync

  if [[ -f /tmp/ldap_sync && -f /tmp/ldap_sync.old ]]
  then
    diff -q /tmp/ldap_sync{,.old} >/dev/null
    return $?
  fi

  return 1
}
# ===============================================================
# main
# ===============================================================
function main
{
  last=$(date -d "5 minutes ago" "+%Y-%m-%d")  # %Y-%m-%d 5 minutes ago
  current=$(date "+%Y-%m-%d")

  if [[ "$last" != "$current" ]]               # force sync once a day
  then
    ldap_sync force
    generate_roles
  else
    ldap_sync
    if [[ $? -ne 0 ]]
    then
      generate_roles            # generate roles if ldap sync did something
    fi
  fi
}
# ===============================================================
main


