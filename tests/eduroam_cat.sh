#!/bin/bash
# =============================================================================
# determine if institution is present in eduroam CAT
# params: 
# 1) realm
# options:
# -i - print info about idp
# -p - print profile id
# =============================================================================
# check realm to inst mapping
# params:
# 1) realm
# =============================================================================
function get_inst_name()
{
  mapping=$(grep "\"$1\"" $config | cut -d ":" -f2 | tr -d '", ')

  if [[ "$mapping" != "" && -e "$coverage_files/$mapping" ]]
  then
    mapping="$coverage_files/$mapping.json"

  else        # no mapping available or file does not exist
    # realm alias does not have a direct mapping in config, check it directly in all coverage files

    # ldap should always guarantee that any realm or alias is present only for no more than institution
    # so result of this should not me more than one line
    mapping=$(grep -l "\"$1\"" $coverage_files/*)

    if [[ $? -eq 0 && $(echo "$mapping" | wc -l) -eq 1 ]]
    then
      :       # nothing do do here really

    else
      echo "CRITICAL: $1 not found in eduroam CAT"        # not even possible to be in CAT
      exit 2
    fi
  fi

  # determine all the variables needed to further processing

  inst_name=$(jq '.inst_name[1].data' $mapping | tr -d '"')
  # we also need to determine "primary" realm here, assuming the $1 is only alias for the "primary" realm
  primary_realm=$(jq -c '.inst_realm' $mapping | cut -d "," -f1 | tr -d '["]')      # primary realm should always be the first one
  all_realms=$(jq -c '.inst_realm' "$mapping" | tr -d '[]')
  all_realms_plain=$(echo $all_realms | tr -d '"' | tr "," " ")   # more suitable for iteration
}
# =============================================================================
# find institution by its name in eduroam CAT API
# params:
# 1) realm
# =============================================================================
function find_inst()
{
  # TODO - what happens if API is unavailable?
  # TODO this should be handled somehow

  inst=$(curl "${API_url}?action=listIdentityProviders&federation=CZ" 2>/dev/null | jq --arg inst_name "$inst_name" '.data[] | select(.display == $inst_name)')

  if [[ -n "$inst" ]]
  then
    get_profile $1       # if institution is listed, always download its profile
    return 0
  else
    return 1
  fi
}
# =============================================================================
# download_profile
# params:
# 1) realm
# 2) profile id
# =============================================================================
function download_profile()
{
  if [[ ! -e $db/${1}_${2}_eap_config.xml ]]      # no eap config exists, write it directly
  then
    # TODO - what happens if API is unavailable?
    # TODO this should be handled somehow

    wget "${API_url}?action=downloadInstaller&profile=${2}&device=eap-config" -O $db/${1}_${2}_eap_config.xml 2>/dev/null
  else      # config exists, overwrite it only it if differs
    tmp=$(mktemp)

    # TODO - what happens if API is unavailable?
    # TODO this should be handled somehow
    wget "${API_url}?action=downloadInstaller&profile=${2}&device=eap-config" -O $tmp 2>/dev/null

    diff -q $tmp $db/${1}_${2}_eap_config.xml &>/dev/null     # diff files

    if [[ $? -ne 0 ]]
    then
      cp $tmp $db/${1}_${2}_eap_config.xml    # copy tmp to dest
    fi

    rm $tmp
  fi
}
# =============================================================================
# get institution's CAT profile
# params:
# 1) realm
# =============================================================================
function get_profile()
{
  # get inst_id
  id=$(echo "$inst" | jq '.id')       # inst_id

  all_profiles=$(curl "${API_url}?action=listProfiles&idp=$id" 2>/dev/null | jq '.data[].id' | tr -d '"')

  # iterate all profiles
  for i in $all_profiles
  do
    download_profile $1 $i

    if [[ "$(grep "\"$1\"" $db/${1}_${i}_eap_config.xml)" != "" ]]    # grep "realm" in config
    then
      profile_id=$i       # this is the correct profile
    fi
  done

  # profile id still not set after iterating all available profiles so
  # script was probably called with realm alias - we set the profile id to the profile of primary realm
  if [[ -z "$profile_id" ]]
  then
    # iterate all profiles
    for i in $all_profiles
    do
      if [[ "$(grep "\"$primary_realm\"" $db/${1}_${i}_eap_config.xml)" != "" ]]    # grep "realm" in config
      then
        profile_id=$i       # this is the correct profile
        # link alias to "primary" realm

        # TODO - what if the file exists?
        ln -sf "$db/${primary_realm}_${i}_eap_config.xml" "$db/${1}_${i}_eap_config.xml"
      fi
    done
  fi
}
# =============================================================================
# print additional ouput based on script options
# =============================================================================
function verbose_output()
{
  if [[ "$idp" == true ]]
  then
    echo "$inst"
  fi

  if [[ "$profile" == true && -n "$profile_id" ]]
  then
    echo "$profile_id"
  fi
}
# =============================================================================
# check institution's profile
# params:
# 1) realm
# =============================================================================
function check_profile()
{
  # no profile_id set - check EAPIdentityProvider ID value

  if [[ -z "$profile_id" ]] # profile_id is not set, something is most likely set incorrectly in institution's eap_config.xml
  then

    # This part requires that all realm aliases would be explicitly set in CAT, otherwise it does not make sense
    # Is it even possible to set it in CAT or by hand?

    for i in $all_profiles
    do
      provider_id=$(echo -n "$db/${1}_${i}_eap_config.xml" | python3 -c 'import sys; import lxml.objectify; f = sys.stdin.read(); data = lxml.objectify.parse(f).getroot(); id = data.EAPIdentityProvider.get("ID"); print(id)')

      profile_out=$profile_out"EAPIdentityProvider ID: \"$provider_id\" for profile $i\n"
    done

    profile_out=$profile_out"cannot determine profile id for realm $1"
    return 1
  fi

  # check that cert is present in eap_config.xml
  # some EAP methods do not even require cert
  out=$(echo -n "$db/${1}_${profile_id}_eap_config.xml" | $plugin_path/parse_eap_config.py)
  ret=$?

  if [[ $ret -ne 0 ]]
  then
    profile_out="$out"
    return 1
  fi
}
# =============================================================================
# get download links for all profiles of inst
# =============================================================================
function get_profile_links()
{
  echo ""
  echo "links for all profiles related to realm $1 for further investigation:"

  for i in $all_profiles
  do
    echo "${API_url}?action=downloadInstaller&profile=${i}&device=eap-config"
  done
}
# =============================================================================
# check state of institution's profile in eduroam CAT
# params:
# 1) realm
# =============================================================================
function check_inst_state()
{
  check_profile $1

  if [[ $? -ne 0 ]]
  then
    echo "WARNING: something is wrong with the profile of $1"
    echo "$profile_out"
    get_profile_links $1
    exit 1
  fi


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
# params:
# 1) realm
# =============================================================================
function main()
{
  get_inst_name $1
  find_inst $1

  if [[ $? -eq 0 ]]     # inst found in CAT, do furher checks
  then
    check_inst_state $1
    if [[ -n "$primary_realm" ]]
    then
      echo "OK: assuming $1 is present eduroam CAT as $primary_realm"
    else
      echo "OK: $1 present in eduroam CAT"
    fi
    verbose_output
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
plugin_path="/usr/lib/nagios/plugins"
# =============================================================================
# global variables
declare -g idp
declare -g profile
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
    esac
done
shift "$((OPTIND-1))"
# =============================================================================
main "$@"

