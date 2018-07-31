## ping
<!--
# ==========================================================================================================================================
-->


### notifications

Notifications for this test are enabled.

## radsec

<!--
# ==========================================================================================================================================
-->

### notifications

Notifications for this test are enabled.

## ipsec

### notifications

Notifications for this test are enabled.


<!--
# ==========================================================================================================================================
-->

## calling station id

### notifications

Notifications for this test are enabled.

<!--
# ==========================================================================================================================================
-->

## vcelka maja

<!--
# ==========================================================================================================================================
-->

## operator name

### notifications

Notifications for this test are **NOT** enabled.


<!--
# ==========================================================================================================================================
-->

## chargeable user identity

This test 

### notifications

Notifications for this test are **NOT** enabled.

<!--
# ==========================================================================================================================================
-->

## institution.xml

### notifications

Notifications for this test are enabled.

<!--
# ==========================================================================================================================================
-->
## fake uid

### notifications

Notifications for this test are enabled.

<!--
# ==========================================================================================================================================
-->

## home realm

### notifications

Notifications for this test are enabled.

<!--
# ==========================================================================================================================================
-->

## visitors' realms

### notifications

Notifications for this test are **NOT** enabled.


<!--
# ==========================================================================================================================================
-->

## big packet

### notifications

Notifications for this test are **NOT** enabled.

reason TODO

<!--
# ==========================================================================================================================================
-->

## cve-2017-9148

### notifications

Notifications for this test are enabled.

<!--
# ==========================================================================================================================================
-->

## visitors

This check

### modifications needed

This test internally uses the `icingacli` tool to get data.
For this plugin to work under nagios user, the user needs to be added to icingaweb2 group.
This is done by `usermod -a -G icingaweb2 nagios`.

### notifications

Notifications for this test are enabled.

<!--
# ==========================================================================================================================================
-->

## home realm alive

### modifications needed

This test internally uses the `icingacli` tool to get data.
For this plugin to work under nagios user, the user needs to be added to icingaweb2 group.
This is done by `usermod -a -G icingaweb2 nagios`.

### notifications

Notifications for this test are **NOT** enabled.

<!--
# ==========================================================================================================================================
-->

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

### notifications

Notifications for this test are enabled.

<!--
# ==========================================================================================================================================
-->

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

### notifications

Notifications for this test are enabled.

### TODO

This test does not reflect realm aliases. CESNET CAAS enables realm to use alias such `alias.realm.cz` for realm `realm.cz`. 
This test checks only users for "primary" realm.
