#!/bin/bash
# ==============================================================================
# check eap certificate properties 
# params:
# 1) realm
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
  out=$($plugin_path/eduroam_cat.sh -p $1 | tail -1)
  ret=$?
  realm=$1      # save realm

  shift         # shift params

  if [[ $ret -eq 0 ]]       # found
  then
    parse_eap_config $out
    run_rad_eap_test "$@"
  elif [[ $ret -eq 1 ]]
  then
    # TODO
    :
  elif [[ $ret -eq 2 ]]     # NOT found
  then
    run_rad_eap_test "$@"
  else  # UNKNOWN
    # TODO
    :
  fi
}
# ==============================================================================
# analyze server cert
# ==============================================================================
function analyze_cert()
{
  if [[ -n "$chain" && -n "$hostname" ]]
  then
    :
    # check cert against CAT info
  fi

  #do regular cert checks
  cert_info=$(openssl x509 -nameopt utf8 -in $1 -text -noout)
  echo "$cert_info"


  # TODO - drzet certy (jak chainy, tak eap) v gitu?
}
# ==============================================================================
# run rad_eap_test
# ==============================================================================
function run_rad_eap_test()
{
  cert=$(mktemp)
  echo "cert: $cert"

  $plugin_path/rad_eap_test "$@" -B $cert >/dev/null   # dont need this output

  # TODO - check return code of rad_eap_test?

  if [[ ! -e $db/${realm}_eap.pem ]]    # eap cert does not exist
  then
     write_cert $realm "eap"
  elif [[ "$(diff -q $cert $db/${realm}_eap.pem)" != "" ]]    # cert differs from current cert
  then
    # TODO - notify admins ?
     write_cert $realm "eap"
  fi

  rm $cert
  analyze_cert $db/${realm}_eap.pem
}
# ==============================================================================
# write given cert to "db"
# params:
# 1) realm
# 2) cert type
# ==============================================================================
function write_cert()
{
  echo "-----BEGIN CERTIFICATE-----" > "$db/${1}_${2}.pem"
  echo $chain >> "$db/${1}_${2}.pem"
  echo "-----END CERTIFICATE-----" >> "$db/${1}_${2}.pem"
}
# ==============================================================================
# parse eap config
# params:
# 1) realm
# 2) profile id
# ==============================================================================
function parse_eap_config()
{
  # read CA chain from xml
  chain=$(echo -n "$db/${realm}_${1}_eap_config.xml" | python3 -c 'import sys; import lxml.objectify; f = sys.stdin.read(); data = lxml.objectify.parse(f).getroot(); print(data.EAPIdentityProvider.AuthenticationMethods.AuthenticationMethod.ServerSideCredential.CA)')

  # read server hostname from xml
  hostname=$(echo -n "$db/${realm}_${1}_eap_config.xml" | python3 -c 'import sys; import lxml.objectify; f = sys.stdin.read(); data = lxml.objectify.parse(f).getroot(); print(data.EAPIdentityProvider.AuthenticationMethods.AuthenticationMethod.ServerSideCredential.ServerID)')

  # no cert exists
  if [[ ! -e "$db/${realm}_chain.pem" ]]
  then
    write_cert $1 "chain"

  # rewrite the cert only if it changed
  # TODO - some notification?
  elif [[ $(diff -q <(echo "-----BEGIN CERTIFICATE-----" ; echo $chain ; echo "-----END CERTIFICATE-----" ;) "$db/${realm}_chain.pem") != "" ]]
  then
    write_cert $1 "chain"
  fi

}
# ==============================================================================
db="/var/lib/nagios/eap_cert_db"
plugin_path="/usr/lib/nagios/plugins"
# ==============================================================================
main "$@"

