#!/bin/bash
# cleanup temporary files left by rad_eap_test when icinga2 is reloaded
for i in $(find /tmp/ -maxdepth 1 -name 'rad*' -atime +5); do rm -r $i; done
