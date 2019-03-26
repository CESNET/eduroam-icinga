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
  # TODO - what happens if API is unavailable?

  inst=$(curl "${API_url}?action=listIdentityProviders&federation=CZ" 2>/dev/null | jq --arg inst_name "$inst_name" '.data[] | select(.display == $inst_name)')

  if [[ -n "$inst" ]]
  then

    if [[ "$idp" == true ]]
    then
      echo "$inst"
    fi

    if [[ "$profile" == true ]]
    then
      get_profile
    fi

    if [[ "$download" == true ]]
    then
      get_profile

      if [[ ! -e $db/${1}_${profile_id}_eap_config.xml ]]      # no eap config exists, write it directly
      then
        wget "${API_url}?action=downloadInstaller&profile=${profile_id}&device=eap-config" -O $db/${1}_${profile_id}_eap_config.xml 2>/dev/null
      else      # config exists, overwrite it only it if differs
        tmp=$(mktemp)
        wget "${API_url}?action=downloadInstaller&profile=${profile_id}&device=eap-config" -O $tmp 2>/dev/null

        diff -q $tmp $db/${1}_${profile_id}_eap_config.xml &>/dev/null     # diff files

        if [[ $? -ne 0 ]]
        then
          cp $tmp $db/${1}_${profile_id}_eap_config.xml    # copy tmp to dest
        fi

        rm $tmp
      fi

    fi

    return 0
  else
    return 1
  fi
}
# =============================================================================
# get institution's CAT profile
# =============================================================================
function get_profile()
{
  if [[ -z "$id" ]]
  then
    id=$(echo "$inst" | jq '.id')       # inst_id
  fi

  if [[ -z "$profile_id" ]]                # profile_id
  then
    profile_id=$(curl "${API_url}?action=listProfiles&idp=$id" 2>/dev/null | jq '.data[0].id' | tr -d '"')      # TODO - process all profiles for given inst?
  fi
}
# =============================================================================
# check state of institution's profile in eduroam CAT
# =============================================================================
function check_inst_state()
{
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
  find_inst $1


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
# script config
config="/home/eduroamdb/eduroam-db/web/coverage/config/realm_to_inst.js"
coverage_files="/home/eduroamdb/eduroam-db/web/coverage/coverage_files/"
API_url="https://cat.eduroam.org/user/API.php"
db="/var/lib/nagios/eap_cert_db"
# =============================================================================
# global variables
declare -g idp
declare -g profile
declare -g download
# =============================================================================
# process command line options
while getopts ":ipd" opt
  do
    case ${opt} in
      i)
        idp=true;          # print info about idp
        ;;
      p)
        profile=true;      # print profile ID
        ;;
      d)
        download=true;      # download installer
        ;;
    esac
done
shift "$((OPTIND-1))"
# =============================================================================
main "$@"

