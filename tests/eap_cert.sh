#!/bin/bash
# ==============================================================================
# check eap certificate properties 
# params:
# 1) realm
# 2) hostname
# 
# other params:
# this program internally uses rad_eap_test to get remote RADIUS server certificate
# so all the necesarry params for rad_eap_test are required
# ==============================================================================

# ==============================================================================
# main function
# ==============================================================================
function main()
{
  realm=$1                  # save realm
  shift                     # shift params
  radius_hostname=$1        # save hostname
  shift                     # shift params

  # check if realm_eap_config.xml exists
  if [[ -e "$cat_db/${realm}_eap_config.xml" ]]     # if it exists, then the institution is present in CAT
  then
    parse_eap_config
    run_rad_eap_test "$@" -d "$eap_hostnames" -a "$db/${realm}_chain.pem"   # run rad_eap_test, check cert against CA and EAP server certificate subject
  else
    run_rad_eap_test "$@"     # run rad_eap_test
  fi
}
# ==============================================================================
# analyze eapol_test output
# ==============================================================================
function analyze_output()
{
  local proposed
  local unsafe=false
  declare -A unsafe_methods
  unsafe_methods["4"]="MD5-Challenge"
  unsafe_methods["17"]="Cisco-LEAP"

  proposed=$(echo "$eapol_test_out" | grep "CTRL-EVENT-EAP-PROPOSED-METHOD")

  for i in ${!unsafe_methods[@]}
  do
    if [[ $(echo "$proposed" | grep "CTRL-EVENT-EAP-PROPOSED-METHOD vendor=0 method=$i") != "" ]]
    then
      echo "WARNING: server is offering unsafe method ${unsafe_methods[$i]}"
      unsafe=true
    fi
  done

  if [[ $unsafe == "true" ]]
  then
    exit 1
  fi
}
# ==============================================================================
# analyze server cert
# ==============================================================================
function analyze_cert()
{
  #do regular cert checks
  cert_info=$(openssl x509 -nameopt utf8 -in $1 -text -noout)
  echo "$cert_info"


  # TODO
}
# ==============================================================================
# run rad_eap_test
# ==============================================================================
function run_rad_eap_test()
{
  local ret
  local out
  local linenum=1
  local first_line
  local second_line

  cert=$(mktemp)

  eapol_test_out=$($plugin_path/rad_eap_test "$@" -B $cert -g)   # write cert to temp file & run in debug
  ret=$?

  # ==============================================================================
  # eapol_test extracts certs in strange format, we want to use the standard format
  # this extract just the first certificate in standard format
  sed -n -i '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/p' $cert

  if [[ ! -e "$db/${realm}_${radius_hostname}_eap.pem" ]]    # eap cert does not exist
  then
    write_cert "$(cat $cert)"
    commit_changes "added EAP certificate for realm $realm for server $radius_hostname" "${realm}_${radius_hostname}_eap.pem"

  elif [[ "$(diff -q $cert $db/${realm}_${radius_hostname}_eap.pem)" != "" ]]    # cert differs from current cert
  then
    write_cert "$(cat $cert)"
    commit_changes "changed EAP certificate for realm $realm for server $radius_hostname" "${realm}_${radius_hostname}_eap.pem"
  fi

  rm $cert      # remove temp file

  # ==============================================================================

  # check eapol_test return code and output
  if [[ $ret -ne 0 ]]       # if rad_eap_test returned any error, display it and exit immediately
  then

    # extract just the status output with potential errors
    # read two lines at once in one iteration, increment linenum by 1 in next iteration
    while :
    do
      first_line=$(sed -n "$linenum,${linenum}p; $((linenum + 1))q" <<< "$eapol_test_out")
      ((linenum++))
      second_line=$(sed -n "$linenum,${linenum}p; $((linenum + 1))q" <<< "$eapol_test_out")

      if [[ $first_line =~ ^$ && "$second_line" =~ ^"Reading configuration file".* ]]
      then
        break
      fi

      out="${out}\n${first_line}"
    done

    echo -e "$out"
    exit $ret
  fi

  check_cert_changes "$db/${realm}_${radius_hostname}_eap.pem"     # check when the file was last added/changed

  if [[ $? -ne 0 ]]
  then
    echo "WARNING: RADIUS server EAP certificate changed recently"
    show_cert_changes "$db/${realm}_${radius_hostname}_eap.pem"
    exit 1
  fi

  analyze_output
  analyze_cert $db/${realm}_${radius_hostname}_eap.pem
}
# ==============================================================================
# show details about certificate changes
# params:
# 1) file
# ==============================================================================
function show_cert_changes()
{
  cd $db
  local filename=$(basename "$1")

  echo ""
  echo "current certificate:"
  cat "$filename"          # just show the file contents

  echo ""
  echo "earlier certificate:"
  rev=$(git log --pretty=oneline "$filename" | head -2 | tail -1 | cut -d ' ' -f1)      # get second newest commit
  git show ${rev}:"$filename"                                                           # get file contents at specific commit

  cd - &>/dev/null
}
# ==============================================================================
# get last modification time of specified file from git repostitory in seconds
# if the specified file has only 1 commit, no changes are assumed
# params:
# 1) file
# ==============================================================================
function get_last_modify_time()
{
  cd $db
  local filename=$(basename "$1")

  count=$(git rev-list --count master "$filename")

  if [[ $count -eq 1 ]]
  then
    return 0
  fi

  last_modify_time=$(git log -1 --format=%cd --date=iso-strict "$filename")        # get last modify time from git for file
  last_modify_time=$(date -d $last_modify_time "+%s")                              # convert to seconds

  cd - &>/dev/null
}
# ==============================================================================
# check changes in certificates based on git repository
# params:
# 1) file to check
# ==============================================================================
function check_cert_changes()
{
  local curr_date=$(date "+%s")
  local time_since_last_change=259200       # 3 days in seconds

  get_last_modify_time "$1"

  if [[ $(($last_modify_time + $time_since_last_change)) -ge $curr_date ]]
  then
    return 1        # the file changed recently
  else
    return 0        # no changes
  fi
}
# ==============================================================================
# write given cert to "db"
# params:
# 1) cert content
# ==============================================================================
function write_cert()
{
  echo "$1" > "$db/${realm}_${radius_hostname}_eap.pem"
}
# ==============================================================================
# write given chain to "db"
# params:
# 1) realm
# ==============================================================================
function write_chain()
{
  echo "$chain" > "$db/${1}_chain.pem"
}
# ==============================================================================
# parse eap config
# ==============================================================================
function parse_eap_config()
{
  local certs
  # TODO - this should be done specifically for method 25
  # this just takes the first method and extracts all the certs

  # read CA chain from xml
  chain=$(echo -n "$cat_db/${realm}_eap_config.xml" | python3 -c 'import sys; import lxml.objectify; f = sys.stdin.read(); data = lxml.objectify.parse(f).getroot(); [ print(i) for i in data.EAPIdentityProvider.AuthenticationMethods.AuthenticationMethod.ServerSideCredential.CA ]' 2>&1)

  if [[ $? -ne 0 ]]         # no chain was extracted, probably incomplete profile
  then
    return
  fi

  # transform chain to pem format
  while read line
  do
    if [[ -n "$certs" ]]
    then
      certs=$(echo -e "$certs\n-----BEGIN CERTIFICATE-----\n$line\n-----END CERTIFICATE-----")
    else
      certs=$(echo -e "-----BEGIN CERTIFICATE-----\n$line\n-----END CERTIFICATE-----")
    fi
  done <<< "$chain"

  chain=$certs

  # read all server hostnames from xml
  eap_hostnames=$(echo -n "$cat_db/${realm}_eap_config.xml" | python3 -c 'import sys; import lxml.objectify; f = sys.stdin.read(); data = lxml.objectify.parse(f).getroot(); [ print(i) for i in data.EAPIdentityProvider.AuthenticationMethods.AuthenticationMethod.ServerSideCredential.ServerID ]' | awk '
    BEGIN { cnt = 0 }
    { a[cnt++] = $0 }       # save every row to array
    END { for(i = 0; i < cnt - 1; i++) { printf("%s;", a[i]) } printf("%s", a[cnt - 1]); }      # print all but last in loop separated by ";" then print last
    ')

  # no cert exists
  if [[ ! -e "$db/${realm}_chain.pem" ]]
  then
    write_chain $realm
    commit_changes "added certificate chain from CAT for realm $realm" "${realm}_chain.pem"

  elif [[ $(diff -q <(echo "$chain") "$db/${realm}_chain.pem") != "" ]]
  then
    write_chain $realm
    commit_changes "changed certificate chain from CAT for $realm" "${realm}_chain.pem"
  fi

  check_cert_changes "$db/${realm}_chain.pem"   # check when the file was last added/changed

  if [[ $? -ne 0 ]]
  then
    echo "WARNING: CA certificate from CAT changed recently"
    show_cert_changes "$db/${realm}_chain.pem"
    exit 1
  fi
}
# ======================================================================
# commit all changes
# params:
# 1) commit message
# 2) file to add
# ======================================================================
function commit_changes()
{
  cd $db
  git add "$2"

  count=0
  while [[ -e ".git/index.lock" && count -lt 30 ]]      # wait for other git processes to finish
  do
    sleep 1
    ((count++))
  done

  git commit -m "$1" --author "info@eduroam.cz <info@eduroam.cz>" &>/dev/null
  cd - &>/dev/null
}
# ==============================================================================
db="/var/lib/nagios/eap_cert_db"
cat_db="/var/lib/nagios/CAT_db/"
plugin_path="/usr/lib/nagios/plugins"
# ==============================================================================
# ==============================================================================
main "$@"
# ==============================================================================

