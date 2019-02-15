#!/bin/bash
# =============================================================================
# script params: 
# 1) realm
# =============================================================================
# main
# =============================================================================
function main()
{
  check_mapping $1

  if [[ $? -ne 0 ]]
  then
    echo "CRITICAL: Nejsou dostupne zadne informace o pokryti"
    exit 2
  fi

  validate_json

  if [[ $? -ne 0 ]]
  then
    echo "CRITICAL: Chyby pri validaci dat o pokryti"
    echo "$errors"
    exit 2
  fi

  check_urls

  if [[ $? -ne 0 ]]
  then
    echo "CRITICAL: Nespravne informacni URL $bad_url"
    exit 2
  fi

  echo "OK"
  exit 0
}
# =============================================================================
# check realm to inst mapping
# =============================================================================
function check_mapping()
{

  mapping=$(grep "\"$1\"" /home/eduroamdb/eduroam-db/web/coverage/config/realm_to_inst.js | cut -d ":" -f2 | tr -d '"' | tr -d ',' | tr -d ' ')

  if [[ "$mapping" != "" ]]
  then
    return 0
  else
    return 1        # no mapping available
  fi

  # the file does not exists
  if [[ ! -e "/home/eduroamdb/eduroam-db/web/coverage/coverage_files/$mapping.json" ]]
  then
    return 1
  fi
}
# =============================================================================
# validate json against schema
# =============================================================================
function validate_json()
{
  errors=$(jq -S -s '{ "schema_version": 2, "institutions": { "institution": . } }' "/home/eduroamdb/eduroam-db/web/coverage/coverage_files/$mapping.json" | /usr/lib/nagios/plugins/validate_inst_json.py 2>&1)

  if [[ $? -ne 0 ]]
  then
    return 1
  fi
}
# =============================================================================
# check urls
# =============================================================================
function check_urls()
{
  urls=$(jq '.info_URL[0].data , .location[].info_URL[0].data' "/home/eduroamdb/eduroam-db/web/coverage/coverage_files/$mapping.json" | tr -d '"')

  if [[ $mapping =~ CESNET ]]   # do not check urls for CESNET
  then
    return 0
  fi

  for i in $urls
  do
    if [[ "$i" == "http://eduroam.cesnet.cz/en/procizi/index.html" || "$i" == "http://eduroam.cesnet.cz/cz/procizi/index.html" ]]
    then
      bad_url=$i
      return 1
    fi
  done
}
# =============================================================================
main $@


