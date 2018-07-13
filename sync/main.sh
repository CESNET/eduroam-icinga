#!/bin/bash

# ===============================================================
# do all the work for the icinga to use ldap data
# this file is supposed to be run as nagios user with cron
# ===============================================================


# ===============================================================
# generate synchronize ldap source with mysql
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
    : # TODO
  else
    ldap_sync
    if [[ $? -ne 0 ]]
    then
      : # TODO
    fi
  fi
}
# ===============================================================
main


