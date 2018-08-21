#!/bin/bash
# cleanup temporary files left by ead_eap_test
for i in $(find /tmp/ -name 'rad*' -atime +5); do rm -r $i; done
