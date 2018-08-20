#!/bin/bash
# ========================================================================
# better implementation of institution-xml check
# ========================================================================
# params:
# 1: realm list - realms must be separated by comma: 'realm1,realm2,...'
# ========================================================================
function main()
{
  list=$1
  shift

  out=$(/usr/lib/nagios/plugins/check_http --onredirect=follow -v "$@" 2>&1)  # call check_http with all params first
  ret=$?

  status=$(echo "$out" | tail -1)     # check_http status line

  if [[ $ret -ne 0 ]]
  then
    echo "$status"
    exit $ret       # test not ok, exit
  fi

  for i in $(echo $list | tr "," " ")
  do
    if [[ $(echo "$out" | grep "<inst_realm>$i</inst_realm>") == "" ]]
    then
      echo "CRITICAL: string <inst_realm>$i</inst_realm> not found in institution.xml"
      exit 2;
    fi
  done
  
  echo "$status"
  exit $ret
}
# ========================================================================
main "$@"
