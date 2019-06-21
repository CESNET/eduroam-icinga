#!/bin/bash

# ===============================================================================
# param:
# file(s) to extract certs from
# ===============================================================================
function extract_certs()
{
  for i in "$1"
  do
    echo "processing file $i"
    certs=$(echo -n "$i" | python3 -c 'import sys; import lxml.objectify; f = sys.stdin.read(); data = lxml.objectify.parse(f).getroot(); [ print(i) for i in data.EAPIdentityProvider.AuthenticationMethods.AuthenticationMethod.ServerSideCredential.CA ]')
    while read line
    do
      echo -e "-----BEGIN CERTIFICATE-----\n$line\n-----END CERTIFICATE-----" | openssl x509 -text -noout
    done <<< "$certs"
  done

}
# ===============================================================================


if [[ -n "$1" ]]
then
  extract_certs "$1"
else
  extract_certs "*xml"
fi



