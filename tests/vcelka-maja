#!/bin/bash

ID=$1
PASS=$2

HOSTNAME=$3
SECRET=$4
REALM=$5

MAC1=$6
MAC2=$7

output=`/usr/local/rad_eap_test/rad_eap_test -H $HOSTNAME -P 1812 -S $SECRET -m WPA-EAP -e TTLS -u $ID -p $PASS -t 25 -A vcelka-maja@$REALM -M $MAC1 2>/dev/null`
ttls_code=$?
ttls_out="TTLS: vcelka-maja@$REALM $output"
if [ $ttls_code -eq 0 ]
then
  # test byl uspesny, nema smysl to dal testovat
  echo $ttls_out
  exit 2;
else
  output=`/usr/local/rad_eap_test/rad_eap_test -H $HOSTNAME -P 1812 -S $SECRET -m WPA-EAP -e PEAP -u $ID -p $PASS -t 25 -A vcelka-maja@$REALM -M $MAC2 2>/dev/null`
  peap_code=$?
  peap_out="PEAP: vcelka-maja@$REALM $output"
  if [ $peap_code -eq 0 ]
  then
    # test byl uspesny
    echo $peap_out;
    exit 2;
  fi 
fi

if [ $ttls_code -eq 1 ] || [ $peap_code -eq 1 ]
then
  # reject
  echo "$ttls_out; $peap_out; this is OK";
  exit 0
fi

echo "$ttls_out; $peap_out; problem?"
exit 1;
