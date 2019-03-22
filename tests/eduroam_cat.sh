#!/bin/bash
# =============================================================================
# determine if institution is present in eduroam CAT
# params: 
# 1) realm
# options:
# -v - print output about identity provider for possible further processing
# =============================================================================
# check realm to inst mapping
# =============================================================================
function get_inst_name()
{
  mapping=$(grep "\"$1\"" $config | cut -d ":" -f2 | tr -d '"' | tr -d ',' | tr -d ' ')

  if [[ "$mapping" != "" && -e "$coverage_files/$mapping.json" ]]
  then
    inst_name=$(jq '.inst_name[1].data' "$coverage_files/$mapping.json" | tr -d '"')
  else        # no mapping available or file does not exist
    echo "CRITICAL: $1 not found in eduroam CAT"        # not even possible to be in CAT
    exit 2
  fi
}
# =============================================================================
# find institution by its name in eduroam CAT API
# =============================================================================
function find_inst()
{
  inst=$(curl "${API_url}?action=listIdentityProviders&federation=CZ" 2>/dev/null | jq --arg inst_name "$inst_name" '.data[] | select(.display == $inst_name)')

  if [[ -n "$inst" ]]
  then

    if [[ "$verbose" == true ]]
    then
      echo "$inst"
    fi

    return 0
  else
    return 1
  fi
}
# =============================================================================
# check state of institution's profile in eduroam CAT
# =============================================================================
function check_inst_state()
{
  #echo "$inst" | 
  :
  # TODO




  # C = enough Configuration uploaded to create installers
  # V = installers are visible on the download page
  # (nothing) = not enough info in the system to create installers


  # =>
  # CV - (OK)
  # C - no installers visible on download page (WARN)
  # (nothing) = not enough info in the system to create installers (WARN)
}
# =============================================================================
# main function
# =============================================================================
function main()
{
  get_inst_name $1
  find_inst

  if [[ $? -eq 0 ]]     # inst found in CAT, do furher checks
  then
    echo "OK: $1 present in eduroam CAT"
    # TODO
    #check_inst_state
  else                  # NOT found
    echo "CRITICAL: $1 not found in eduroam CAT"
    exit 2
  fi
}
# =============================================================================
config="/home/eduroamdb/eduroam-db/web/coverage/config/realm_to_inst.js"
coverage_files="/home/eduroamdb/eduroam-db/web/coverage/coverage_files/"
API_url="https://cat.eduroam.org/user/API.php"
# =============================================================================
# process command line options
while getopts ":v" opt; do
  case ${opt} in
    v ) verbose=true; shift;;
  esac
done
# =============================================================================
main "$@"

