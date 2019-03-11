#!/bin/bash
# ========================================================================
# check validity of export to eu eduroam database
# ========================================================================
function main
{
  out=$(wget -4 -q -O - https://monitor.eduroam.org/eduroam-database/v2/scripts/json_validation_test.php?url=https://monitor.eduroam.cz/json/$2/institution.json 2>/dev/null)

  # check validation output
  if [[ "$out" == "JSON validates OK" ]]
  then
    echo "JSON validates OK"
    exit 0
  else
    echo "Errors during JSON validation:"
    echo $out
    exit 2
  fi
}
# ========================================================================
main "$@"
