#!/bin/bash

# ============================================================
# check if any of the home servers can autenticate user
#
# ============================================================
# usage:
# aggregate-results.sh realm hostname1 hostname2 [hostname3] [...]
# ============================================================


# ============================================================
# main function
# ============================================================
function main
{
  realm=$1
  shift

  count=0
  dead=0
  alive=0

  for i in $@
  do
    out=$(icingacli monitoring list services --host=$i --service="@$realm" --format=csv --columns=service_state)
    state=$(echo "$out" | tail -1)

    if [[ "$state" =~ "1" ]]
    then
      ((dead++))
    else
      ((alive++))
    fi

    ((count++))
  done

  if [[ $dead -eq $count ]]
  then
    echo "no home servers could authenticate user"
    exit 2
  elif [[ $alive -eq $count ]]
  then
    echo "all home servers could authenticate user"
    exit 0
  else
    echo "only $alive (out of $count) home servers could authenticate user"
    exit 1
  fi
}
# ============================================================
main $@
