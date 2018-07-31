<!--
# ==========================================================================================================================================
-->

## ping

Uses the standard icinga2 `ping4` check. Tests whether the server is reachable by response to ICMP echo request.
Ping is assigned to all RADIUS servers regardless of their role.


### check intervals

- normal check period is 5 minutes
- check period is 1 minute in case of outage
- CRITICAL-HARD state is reached after 10 failed checks (maximum 5 + 9 * 1 = 14 minutes from outage)

### notifications

Notifications for this test are enabled.
Notification interval it set to 24 hours.

<!--
# ==========================================================================================================================================
-->

## radsec

This test checks the state of RadSec connection between servers.
Test is assigned only to servers which are part of the infrastructure and are connected using the RadSec protocol.
Test is not available on servers only used for monitoring.

Test is run remotely on radius1.eduroam.cz (national top level server).
Test checks if the connection is active in both ways (from radius1.eduroam.cz to server and from server to radius1.eduroam.cz).
The test actually works by searching the target server ip address in established connections.
For IdP+SP server there has to be two connections - one from the server and one to the server.
For SP server there has to be one connection from the server.

For servers with IdP only role, this check does not work. TODO

There is slight problem with this check because a lot a participating organizations use freeradius.
Freeradius actively closes connections to national RADIUS server, when there is no traffic.
When there is not enough monitoring activity, it could result in an incorrect test state.
A solution for this could be to write some better test which could hold information for each server
for last hour or so and test this.  TODO

The command in icinga2 is set in two variants - for IdP+SP servers and for SP only servers (see parameters below).

### dependencies
- depends on ping

### check intervals

- normal check period is 5 minutes
- check period is 1 minute in case of outage
- CRITICAL-HARD state is reached after 10 failed checks (maximum 5 + 9 * 1 = 14 minutes from outage)

### parameters

The script takes 1 parameter for IdP+SP servers:
- (key -H) RADIUS server ip address

The first parameter uses host variable `radius_ip`.

The script takes 2 parameters for SP only servers:
- indication that, the server is sp only. There is actually only key `--SPonly` at this parameter.
- (key -H) RADIUS server ip address

The first parameter uses host variable `radius_ip`.
The second parameter is fixed and is set to `--SPonly`.

### notifications

Notifications for this test are enabled.
Notification interval it set to 24 hours.

<!--
# ==========================================================================================================================================
-->

## ipsec

This test checks the state of IPSec connection between servers. Tests whether the server is reachable by response to ICMP echo request though ipsec tunnel.
Test is assigned only to servers which are part of the infrastructure and are connected using the IPSec protocol.
Test is not available on servers only used for monitoring.

Test is run remotely on radius1.eduroam.cz (national top level server).
In case the ping succeeds, it is assumed, that the ipsec tunnel is assembled.
It is also assumed, that radius1.eduroam.cz has kernel policies which disallows it to ping
the target server without assembled ipsec tunnel.
It would be better to check that the SA has been agreed on and the ping, but that would be quite complicated.

### dependencies
- depends on ping

### check intervals

- normal check period is 5 minutes
- check period is 1 minute in case of outage
- CRITICAL-HARD state is reached after 10 failed checks (maximum 5 + 9 * 1 = 14 minutes from outage)

### parameters

The script takes 1 parameter:
- RADIUS server ip address

The first parameter uses host variable `radius_ip`.

### notifications

Notifications for this test are enabled.
Notification interval it set to 24 hours.

<!--
# ==========================================================================================================================================
-->

## calling station id

### notifications

Notifications for this test are enabled.
Notification interval it set to 24 hours.

<!--
# ==========================================================================================================================================
-->

## vcelka maja

### notifications

Notifications for this test are enabled.
Notification interval it set to 24 hours.

<!--
# ==========================================================================================================================================
-->

## operator name

### notifications

Notifications for this test are **NOT** enabled.
Notifications are disabled for this test because operator-name attribute is not set as mandatory by czech eduroam policy.
It is recommended to implement this attribute.


<!--
# ==========================================================================================================================================
-->

## chargeable user identity

This test 

### notifications

Notifications for this test are **NOT** enabled.
Notifications are disabled for this test because chargeable-user-identity attribute is not set as mandatory by czech eduroam policy.
It is recommended to implement this attribute.

<!--
# ==========================================================================================================================================
-->

## institution.xml

### notifications

Notifications for this test are enabled.
Notification interval it set to 24 hours.

<!--
# ==========================================================================================================================================
-->
## fake uid

### notifications

Notifications for this test are enabled.
Notification interval it set to 24 hours.

<!--
# ==========================================================================================================================================
-->

## home realm

This test uses `rad_eap_test` to check if the testing user from the organization can be authenticated on corresponding server.
The server on which the test is ran autenticates users with the corresponding (home) realm.
There may be multiple home realms on one server.

### parameters

The script takes 10 parameters:
- (key -H) RADIUS server ip address
- (key -M) MAC address
- (key -P) port number, set to '1812'
- (key -S) shared secret
- (key -e) method, set to 'PEAP'
- (key -i) connection info
- (key -m) method, set to 'WPA-EAP'
- (key -p) user password
- (key -t) timeout, set to '50'
- (key -u) username

The first parameter uses host variable `radius_ip`.
The second parameter uses service variable `mac_address`.
The third parameter is fixed and is set to `1812`.
The fourth parameter uses host variable `mon_radius_secret`.
The fifth parameter is fixed and is set to `PEAP`.
The sixth parameter uses service variable `info`.
The seventh parameter is fixed and is set to `WPA-EAP`.
The eighth parameter uses service variable `testing_password`.
The ninth parameter is fixed and is set to `50`.
The tenth parameter uses service variable `testing_id`.

### dependencies
- depends on ping

### check intervals

- normal check period is 5 minutes
- check period is 10 minutes in case of outage
- CRITICAL-HARD state is reached after 3 failed checks

### notifications

Notifications for this test are enabled.
Notification interval it set to 24 hours.

<!--
# ==========================================================================================================================================
-->

## visitors' realms

### notifications

Notifications for this test are **NOT** enabled.
Notifications are disabled for this test because the administrator(s) of the corrensponding server can not affect if the home server
authenticates the user correctly. That is also the reason why notifications are enabled for home realm.


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
Notification interval it set to 24 hours.

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
Notification interval it set to 24 hours.

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
Notifications are disabled for this test because the would be redundant to notification for home realm.

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
Notification interval it set to 24 hours.

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
Notification interval it set to 24 hours.

### TODO

This test does not reflect realm aliases. CESNET CAAS enables realm to use alias such `alias.realm.cz` for realm `realm.cz`. 
This test checks only users for "primary" realm.
