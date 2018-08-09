#!/bin/bash
# =====================================================================
# check all ping services for unknown states
# this could indicate DNS failure of some of the RADIUS servers
# =====================================================================
function main
{
  failed_servers=$(icingacli monitoring list services --service="PING" --format='$host_name$,$service_state$,$service_output$'  --columns=host_name,service_state,service_output | grep "Invalid hostname")

  for i in "$failed_servers"
  do
    notify "$(echo $i | cut -d ',' -f1) cannot be resolved"
  done
}
# =====================================================================
# notify admins about problem
# =====================================================================
function notify
{
  echo -e "$1" | mail -s "icinga2 - server out of DNS" $admin
}
# =====================================================================
source ../sync/config/config.sh
main
