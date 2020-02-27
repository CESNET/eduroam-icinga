#!/bin/bash
# ========================================================================
# check that IdP can authenticate users users when
# attribute NAS-Port-Type is not present in initial
# Access-Request packet
# ========================================================================
# ========================================================================
# params:
#   1: RADIUS server IP address
#   2: shared secret
#   3: testing id
#   4: MAC address
# ========================================================================

# ========================================================================
# main
# ========================================================================
function main
{
  cat << EOF > /tmp/check_nas_port_type.conf
User-Name=$3
EAP-Type-Identity=$3
EAP-Code = Response
Message-Authenticator=0x00
Calling-Station-Id=$4
Framed-MTU=1400
EAP-Id = 210
EAP-Type = 25
EOF

  radeapclient -x -4 -f /tmp/check_nas_port_type.conf -D /tmp/freeradius/ $1:1812 auth $2
  rm /tmp/check_nas_port_type.conf
}
# ========================================================================
#main $@
exit 0

