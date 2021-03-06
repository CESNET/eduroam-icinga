#!/bin/bash

# ===============================================================
# do all the work for the icinga to use ldap data
# this file is supposed to be run as nagios user with cron
# ===============================================================


# ===============================================================
# notify admins about sync problem
# ===============================================================
function notify
{
  echo -e "$1" | mail -s "icinga2 sync problem" $admin
}
# ===============================================================
# deploy new configuration
# ===============================================================
function deploy_config
{
  local count=0

  # deploy
  out=$(icingacli director config deploy)

  if [[ "$out" =~ "nothing to do" ]]            # no changes in deploy
  then
    exit 0
  fi

  echo $(date) > /dev/null # just for debug

  ## wait for deploy to finish - 270 seconds max
  #while [[ $count -le 270 ]]
  #do
  #  # TODO - maybe icinga2 daemon -C will be better than extracting the data directly from db?

  #  # get deployed config state
  #  status=$(mysql -u $db_user -e 'select id,startup_succeeded from director_deployment_log order by id desc limit 1;' --password="$db_pass" director)

  #  id=$(echo "$status" | tail -1 | awk '{ print $1 }')
  #  success=$(echo "$status" | tail -1 | awk '{ print $2 }')

  #  if [[ "$success" != "NULL" ]]
  #  then
  #    break
  #  fi

  #  sleep 1
  #  ((count++))
  #done

  #deploy=$(mysql -u $db_user -e "select startup_log from director_deployment_log where id=$id;" --password="$db_pass" director)

  #if [[ "$success" != "y" ]]
  #then
  #  notify "Failed deploy:\n$deploy"
  #  exit 1
  #fi

  #if [[ $(echo "$deploy" | grep "warning") != "" ]]
  #then
  #  notify "configuration warnings:\n$deploy"
  #fi
}
# ===============================================================
# sync director import sources & sync rules
# ===============================================================
function sync_director
{
  sources=$(icingacli director importsource list | grep '[[:digit:]]' | cut -d "|" -f 1 | tr -d " ")

  # import sources
  for i in $sources
  do
    state=$(icingacli director importsource check --id $i)

    if [[ $(echo "$state" | grep "This Import Source failed:") != "" ]]
    then
      notify "Failed import source:\n$state"
      exit 1
    elif [[ $(echo "$state" | grep "pending changes") != "" ]]
    then
     icingacli director importsource run --id $i &>/dev/null
     # TODO - return value handling?
    fi
  done

  # sync rules
  for i in $sync_rules
  do
     icingacli director syncrule run --id $i &>/dev/null
     # TODO - return value handling?
  done
}
# ===============================================================
# generate synchronize ldap source with mysql
# ===============================================================
function ldap_sync
{
  out=$(./ldap_sync.js $1 > /tmp/ldap_sync)
  ret=$?

  if [[ $ret -ne 1 ]]
  then
    return 0        # sync not needed, nothing to do
  fi

  if [[ $ret -ne 1 && $ret -ne 0 ]]
  then
    notify "synchronization failed:\n$out"
    exit 1
  fi

  /usr/bin/cstocs -i utf8 ascii /tmp/ldap_sync

  # sync db only when output is non empty
  if [[ -s /tmp/ldap_sync ]]
  then
    out=$(mysql -u $icinga_db_user --password="$icinga_db_pass" ldap_to_icinga < /tmp/ldap_sync 2>&1)
    ret=$?
  fi

  cp /tmp/ldap_sync /var/lib/nagios/sync_logs/ldap_sync_$(date "+%Y-%m-%d-%H-%M")

  if [[ $ret -ne 0 ]]
  then
    notify "database import problem:\n$out"

    # import old data in case import of new data failed
    out=$(mysql -u $icinga_db_user --password="$icinga_db_pass" ldap_to_icinga < /tmp/ldap_sync_working 2>&1)
    ret=$?

    if [[ $ret -ne 0 ]]
    then
      notify "database import problem (tried to restore older working data):\n$out"
    fi

    exit 1
  else
    cp /tmp/ldap_sync /tmp/ldap_sync_working
  fi

  return 1
}
# ===============================================================
# synchronize data
# ===============================================================
function sync_data
{
  sync_director
  deploy_config
}
# ===============================================================
# main
# ===============================================================
function main
{
  if [[ $DEBUG -eq 1 ]]
  then
    set -x
  fi

  last=$(date -d "5 minutes ago" "+%Y-%m-%d")  # %Y-%m-%d 5 minutes ago
  current=$(date "+%Y-%m-%d")

  if [[ "$last" != "$current" ]]               # force sync once a day
  then
    ldap_sync force
    ./dashboard.sh              # set custom icingaweb2 dashboards
    sync_data
  else
    ldap_sync
    if [[ $? -ne 0 ]]
    then
      ./dashboard.sh            # set custom icingaweb2 dashboards
      sync_data
    fi
  fi
}
# ===============================================================
# config
source config/config.sh
source config/secrets.sh
# ===============================================================
if [[ $DEBUG -eq 1 ]]
then
  main &> /var/lib/nagios/sync_logs/sync_debug_$(date +%Y-%m-%d-%H-%M)
else
  main
fi
# ===============================================================


