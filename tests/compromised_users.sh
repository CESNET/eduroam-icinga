#!/bin/bash
# =======================================================================================================
# script parameters:
# 1) time difference of achieved time and realistic time
# 2) realm list (realms must be separated by comma: 'realm1,realm2,realm3'
#
# =======================================================================================================
# =======================================================================================================
# main function
# =======================================================================================================
function main()
{
  usage $@
  unique_realms

  for i in ${realm_list[@]}  # iterate all realms
  do
    get_data $i
    process_data
    check_threshold $i
  done

  exit $retval
}
# =======================================================================================================
# get unique realm list
# =======================================================================================================
function unique_realms()
{
  realm_list=()

  for i in $(echo $realms | tr "," " ")
  do
    if [[ $(echo ${realm_list[@]} | grep $i) == "" ]]
    then
      realm_list+=($i)
    fi
  done
}
# =======================================================================================================
# get current revision
# =======================================================================================================
function get_revision()
{
  revision=$(curl "https://$hostname:8443/api/concurrent_rev/" 2>/dev/null) # get revisions array
  revision=$(echo $revision | sed 's/^\[.*,//; s/\]//')
}
# =======================================================================================================
# get /api/concurrent_users data
# =======================================================================================================
function get_data()
{
  local min
  local max
  local realm=$1

  hostname="etlog.cesnet.cz"
  min=$(date -d "30 days ago" "+%Y-%m-%d")
  max=$(date "+%Y-%m-%d")

  get_revision

  # get data for realm
  data=$(curl "https://$hostname:8443/api/concurrent_users/?revision=$revision&diff_needed_timediff>=$time_diff&timestamp>=$min&timestamp<=$max&mac_diff=true&username=/@$realm/" 2>/dev/null)

  data=$(echo $data | sed -e 's/},{/\n/g')   # convert to lines and remove brackets
}
# =======================================================================================================
# count number of users
# =======================================================================================================
function count_users
{
  stats=$(echo "$data" | cut -d "," -f8 | cut -d ":" -f2 | sort | uniq -c | sort -rn)   # get usernames, sort, count number of occurences, sort by number of occurences
  total_count=$(echo "$stats" | wc -l)      # get total user count
}
# =======================================================================================================
# process data
# =======================================================================================================
function process_data()
{
  local found

  if [[ "$data" != "[]" ]]
  then
    count_users
  else  # no data available
    # we need to distinct no data available for given realm - 0 users moving too fast and unknown realm
    found=$(curl "https://$hostname:8443/api/realms" 2>/dev/null)

    if [[ "$(echo "$found" | grep "$realm")" == "" ]]  # realm does not exist
    then
      echo "UNKNOWN: Unknown realm $realm"
      exit 3
    else
      total_count=0     # no data available, but realm is known => 0 users
    fi
  fi
}
# =======================================================================================================
function check_threshold()
{
  local realm=$1

  if [[ $total_count -gt 0 ]]
  then
    echo "CRITICAL: $total_count users compromised for realm $realm | $total_count"
    echo -e "stats:\n$stats"
    retval=2

  #elif [[ $total_count -ge $warning ]]
  #then
  #  echo "WARNING: $total_count users compromised for realm $realm | $total_count"
  #  exit 1
  else
    echo "OK: $total_count users compromised for realm $realm | $total_count"

    if [[ $retval -ne 2 ]]
    then
      retval=0
    fi
  fi
}
# =======================================================================================================
# print usage
# =======================================================================================================
function usage()
{
  if [[ $# -lt 2 ]]
  then
    echo "usage: $0 realm time_diff"
    echo ""
    echo "example: $0 60 cesnet.cz,[test.cesnet.cz,...]"
    exit 1
  fi
}
# =======================================================================================================
time_diff=$1
realms=$2
# =======================================================================================================
main $@
# =======================================================================================================
