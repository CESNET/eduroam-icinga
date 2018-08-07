#!/bin/bash

# ============================================================
# aggregate results check for icinga2
# checks how many of visitor realms are problematic
# > 80 % - OK
# > 70 % - WARNING
# < 70 % - CRITICAL
# ============================================================
# usage:
# aggregate-results.sh hostname
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

  out=$(icingacli monitoring list services --host=$1 --service="*@*" --format=csv --columns=service,service_state)

  services=$(echo "$out" | tail -n +3)          # suppress header
  count=$(echo "$services" | wc -l)
  ok_count=$(echo "$services" | grep ',"0"' | wc -l)
  warn_count=$(echo "$services" | grep ',"1"' | wc -l)
  crit_count=$(echo "$services" | grep ',"2"' | wc -l)

  ok_percent=$(printf "%0.2f" $(echo "$ok_count" / $count | bc -l))

  echo "$ok_count visitors' realms OK"
  echo "$warn_count visitors' realms WARNING"
  echo "$crit_count visitors' realms CRITICAL"

  if [[ $(echo "$ok_percent > 0.8" | bc) -eq 1 ]]
  then
    return 0
  elif [[ $(echo "$ok_percent > 0.7" | bc) -eq 1 ]]
  then
    return 1
  else
    return 2
  fi

  return 0
}
# ============================================================
main $1
