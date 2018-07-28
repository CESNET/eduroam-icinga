## chargeable user identity

This test 

## calling station id

## vcelka maja

## radsec

## ipsec

## operator name

## institution.xml

## fake uid

## check_rad_eap

## big packet

## concurrent inst

This test is based on the data from system [etlog](https://github.com/CESNET/etlog). 
This test identifies users which successfully authenticated in short time in distant locations with same MAC addresses.
These events could signalize that the source data from institution.xml could be outdated.
This test is done by [concurrent_inst.sh](https://github.com/CESNET/eduroam-icinga/blob/master/tests/concurrent_inst.sh).
This test is based on source data from institution.xml from all institutions that are connected to czech eduroam infrastructure.

### parameters

The script takes four parameters:
- realm
- time difference
- warning threshold
- critical threshold

The first parameter specifies the realm for which events are retrieved.
The second parameter specifies minimal time difference between time needed to travel from first visited insitution to second at specified speed (set to 100 km/h) and the time actually reached. It is set to 20 seconds.
The third parameter specifies threshold for warning state. It is set to 10.
The fourth parameter specifies threshold for critical state. It is set to 20.

## compromised users

This test is based on the data from system [etlog](https://github.com/CESNET/etlog). 
This test identifies users which successfully authenticated in short time in distant locations with different MAC addresses.
These user identites are considered compromised (shared/stolen identity, ...).
This test is done by [compromised_users.sh](https://github.com/CESNET/eduroam-icinga/blob/master/tests/compromised_users.sh).
This test is based on source data from institution.xml from all institutions that are connected to czech eduroam infrastructure.

### parameters

The script takes two parameters:
- realm
- time difference

The first parameter specifies the realm for which compromised users are retrieved.
The second parameter specifies minimal time difference between time needed to travel from first visited insitution to second at specified speed (set to 100 km/h) and the time actually reached. It is set to 60 seconds.

### TODO

This test does not reflect realm aliases. CESNET CAAS enables realm to use alias such `alias.realm.cz` for realm `realm.cz`. 
This test checks only users for "primary" realm.
