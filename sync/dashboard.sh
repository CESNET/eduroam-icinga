#!/bin/bash
# ===============================================================
# set custom icingaweb dashboard for all realm admins
# ===============================================================



# ===============================================================
# get admin uids
# ===============================================================
function get_uids
{
  for i in ${admins_uids[@]}
  do
    admins_uids[$i]=$(mysql -u $icinga_db_user -e "select uid from admin where admin_dn='$i'" --password="$icinga_db_pass" ldap_to_icinga | tail -n +2) # strip table header
  done
}
# ===============================================================
# get list of admins
# ===============================================================
function get_admins
{
  admins=$(mysql -u $icinga_db_user -e 'select admin_dn from admin' --password="$icinga_db_pass" ldap_to_icinga | tail -n +2)   # strip table header
  admins_uids=$admins
  get_uids
  admins_servers=$admins
}
# ===============================================================
# get list of servers for every admin
# ===============================================================
function get_servers
{
  for i in ${admins_servers[@]}
  do
    admins_servers[$i]=$(mysql -u $icinga_db_user -e "select distinct radius_cn from radius_server where radius_manager='$i'" --password="$icinga_db_pass" ldap_to_icinga | tail -n +2) # strip table header
  done
}
# ===============================================================
# set preferences for each admin
# ===============================================================
function set_preferences
{
  local path="/etc/icingaweb2/dashboards"
  local template='[My servers]
title = "My servers"

[My servers.My servers]
title = "My servers"
url = "/monitoring/list/hosts?' #(host=radius1.cesnet.cz|host=radius2.cesnet.cz)'

  for i in $admins
  do
    local out=$template

    if [[ $(echo "${admins_servers[$i]}" | wc -w) -gt 1 ]]    # multiple servers
    then
      out=${out}"(host="$(echo ${admins_servers[$i]} | sed 's/ /\|host=/g')")\""
    else      # one server
      out=${out}"host=${admins_servers[$i]}\""
    fi

    # also check the content of the file
    if [[ -d "$path/${admins_uids[$i]}@einfra.cesnet.cz" && -e "$path/${admins_uids[$i]}@einfra.cesnet.cz/dashboard.ini" && $(cat "$path/${admins_uids[$i]}@einfra.cesnet.cz/dashboard.ini") == "$out" ]]
    then
      :     # preferences exist and have correct content, do nothing
    else

      mkdir "$path/${admins_uids[$i]}@einfra.cesnet.cz"
      chmod 2770 "$path/${admins_uids[$i]}@einfra.cesnet.cz"
      echo -e "$out" > "$path/${admins_uids[$i]}@einfra.cesnet.cz/dashboard.ini"
      chmod 0660 "$path/${admins_uids[$i]}@einfra.cesnet.cz/dashboard.ini"
    fi
  done
}
# ===============================================================
# main
# ===============================================================
function main
{
  get_admins
  get_servers
  set_preferences
}
# ===============================================================
# config
source config/config.sh
source config/secrets.sh
# ===============================================================
declare -A admins_uids
declare -A admins_servers
# ===============================================================
main
