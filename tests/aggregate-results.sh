#!/bin/bash

# ============================================================
# aggregate results check for icinga2
#
# ============================================================
# usage:
# aggregate-results.sh hostname [service1] [service2] [...]
# ============================================================


# ============================================================
# main function
# ============================================================
function main
{
  if [[ -z "$1" ]]
  then
    echo "no host specified"
    return 3
  fi

  out=$(icingacli monitoring list services --host=$1)

  services=$(echo "$out" | grep -v $1)
  echo "$services"

  return 0
}
# ============================================================
main $1
