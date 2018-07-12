#!/bin/bash
# =======================================================================================================
# script parameters:
# 1) realm
# 2) time difference of achieved time and realistic time
# 3) warning
# 4) critical threshold
#
# =======================================================================================================
# =======================================================================================================
# main function
# =======================================================================================================
function main()
{
  usage $@
  get_data
  process_data
  check_threshold
}
# =======================================================================================================
# get current revision
# =======================================================================================================
function get_revision()
{
  revision=$(curl "https://$hostname:8443/api/concurrent_rev/" 2>/dev/null) # get revisions array
  revision=$(echo $revision | sed 's/^.*,//; s/\].*$//')
}
# =======================================================================================================
# get /api/concurrent_inst data
# =======================================================================================================
function get_data()
{
  local min
  local max

  hostname="etlog.cesnet.cz"
  min=$(date -d "30 days ago" "+%Y-%m-%d")
  max=$(date "+%Y-%m-%d")

  get_revision

  # get data for visinst_1
  data=$(curl "https://$hostname:8443/api/concurrent_inst/?revision=$revision&diff_needed_timediff>=$time_diff&timestamp>=$min&timestamp<=$max&mac_diff=false&visinst_1=$realm" 2>/dev/null)

  # get data for visinst_2
  data=$data$(curl "https://$hostname:8443/api/concurrent_inst/?revision=$revision&diff_needed_timediff>=$time_diff&timestamp>=$min&timestamp<=$max&mac_diff=false&visinst_2=$realm" 2>/dev/null)

  data=$(echo $data | sed -e 's/},{/\n/g; s/\[{//; s/}\]//g; s/\[{/\n/')   # convert to lines and remove brackets
}
# =======================================================================================================
# process data
# =======================================================================================================
function process_data()
{
  local found

  if [[ "$data" != "[][]" ]]
  then
    total_count=$(echo "$data" | cut -d '"' -f 3 )
    total_count=$(echo $total_count | sed 's/://g; s/,//g; s/ / + /g' | bc) # get total count
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
  if [[ $total_count -ge $critical ]]
  then
    echo "CRITICAL: $total_count events occured too fast for realm $realm | $total_count"
    exit 2
  elif [[ $total_count -ge $warning ]]
  then
    echo "WARNING: $total_count events occured too fast for realm $realm | $total_count"
    exit 1
  else
    echo "OK: $total_count events occured too fast for realm $realm | $total_count"
    exit 0
  fi
}
# =======================================================================================================
# print usage
# =======================================================================================================
function usage()
{
  if [[ $# -lt 4 ]]
  then
    echo "usage: $0 realm time_diff warning_threshold critical_threshold"
    echo ""
    echo "example: $0 cesnet.cz 60 10 20"
    exit 1
  fi
}
# =======================================================================================================
realm=$1
time_diff=$2
warning=$3
critical=$4
# =======================================================================================================
main $@
# =======================================================================================================
