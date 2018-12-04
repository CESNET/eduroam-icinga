#!/bin/bash
# ========================================================================
# better implementation of institution-xml check
# ========================================================================
# params:
# 1: realm list - realms must be separated by comma: 'realm1,realm2,...'
# all other params are for check_http - see director for details
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
    echo "$out"
    exit $ret       # test not ok, exit
  fi

  # strip html comments from out
  out=$(echo "$out" | sed -e :a -re 's/<!--.*?-->//g;/<!--/N;//ba')

  # ==========================================================================================
  # check info_URL against CESNET info_URL for realms that are not cesnet.cz or eduroom.cesnet.cz
  if [[ ! $list =~ "cesnet.cz" && ! list =~ "eduroroom.cesnet.cz" ]]
  then
    if [[ $(echo "$out" | grep "http://eduroam.cesnet.cz/en/procizi/index.html") != "" ]]
    then
      echo "CRITICAL: bad info_URL http://eduroam.cesnet.cz/en/procizi/index.html"
      exit 2;
    fi

    if [[ $(echo "$out" | grep "http://eduroam.cesnet.cz/cz/procizi/index.html") != "" ]]
    then
      echo "CRITICAL: bad info_URL http://eduroam.cesnet.cz/cz/procizi/index.html"
      exit 2;
    fi
  fi


  # ==========================================================================================
  # check that all realm are available
  for i in $(echo $list | tr "," " ")
  do
    if [[ $(echo "$out" | grep "<inst_realm>$i</inst_realm>") == "" ]]
    then
      echo "CRITICAL: string <inst_realm>$i</inst_realm> not found in institution.xml"
      exit 2;
    fi
  done

  # ==========================================================================================
  # check that no realm more realms are available
  for i in $(echo "$out" | grep '<inst_realm>' | cut -d ">" -f2 | cut -d "<" -f1)
  do
    matched=false

    for j in $(echo $list | tr "," " ")
    do
      if [[ "$i" == "$j" ]]
      then
        matched=true
      fi
    done

    if [[ $matched == false ]]
    then
      echo "CRITICAL: string <inst_realm>$i</inst_realm> found in institution.xml"
      exit 2;
    fi

  done

  # disable checking of invalid encoding
  # is does not correctly handle other than utf-8 encodings
  #check_invalid_encoding

  echo "$status"
  exit $ret
}
# ========================================================================
# check invalid encoding of characters in document
# ========================================================================
function check_invalid_encoding()
{
  content=$(echo "$out" | sed -n '/<?xml version="1.0"/,/!/p' | head -n -2)
  tmp=$(mktemp)
  echo "$content" > $tmp
  errors=$(grep -avx '.*' $tmp)
  rm $tmp

  if [[ "$errors" != "" ]]
  then
    echo -e "CRITICAL: invalid characters detected:\n$errors"
    exit 2;
  fi
}
# ========================================================================
main "$@"
