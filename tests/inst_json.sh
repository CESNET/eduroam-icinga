#!/bin/bash
# ========================================================================
# params
# 1: xml url
# 2: primary realm
# ========================================================================

# ========================================================================
# ========================================================================
function main
{
  dir=$(mktemp -d)      # temp dir

  out=$(wget --no-check-certificate -4 "$1" -O $dir/${2}.xml 2>&1) # get xml

  if [[ $? -ne 0 ]]
  then
    echo "$out" | grep -i "failed\|error"
    rm -r $dir
    exit 2
  fi

  mkdir /var/www/json/$2 2>/dev/null       # create realm directory for json
  /home/eduroamdb/eduroam-db/convertor/converter.py -fc $dir /var/www/json/$2   # convert xml to json

  if [[ $? -ne 0 ]]
  then
    rm -r $dir
    exit 2
  fi

  /home/eduroamdb/eduroam-db/convertor/inst_json.sh /var/www/json/$2 /var/www/json/$2/institution.json # create institution.json from converted json

  # validate
  out=$(wget -4 -q -O - https://monitor.eduroam.org/eduroam-database/v2/scripts/json_validation_test.php?url=https://monitor.eduroam.cz/json/$2/institution.json 2>/dev/null)

  # check validation output
  if [[ "$out" == "JSON validates OK" ]]
  then
    echo "JSON validates OK"
    rm -r $dir
    exit 0
  else
    echo "Errors during JSON validation:"
    parse_errors "$out" $2
    rm -r $dir
    exit 2
  fi
}
# ========================================================================
# parse error output
# ========================================================================
function parse_errors
{
  props=$(echo "$1" | grep property)
  msgs=$(echo "$1" | grep message) 

  lines=$(echo "$props" | wc -l)

  echo "JSON available at: https://monitor.eduroam.cz/json/$2/institution.json"

  for((i = 1; i <= $lines; i++))
  do
    echo "$props" | sed -n "${i}p"
    key=$(echo "$props" | sed -n "${i}p" | awk '{ print $3 }')
    echo "    [value]: $(jq ".$key" /var/www/json/$2/institution.json)" 
    echo "$msgs" | sed -n "${i}p"
    echo "========================================="
  done
}
# ========================================================================
# ========================================================================
set -o pipefail
main "$@"
