# Tests

This page sumarizes all the tests that used for czech eduroam monitoring.

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

Test is done by [check_radsec.pl](https://github.com/CESNET/eduroam-icinga/blob/master/tests/check_radsec.pl).

### parameters

The script takes 1 parameter for IdP+SP servers:
- (key -H) RADIUS server ip address

The first parameter uses host variable `radius_ip`.

The script takes 2 parameters for SP only servers:
- indication, that the server is sp only. There is actually only key `--SPonly` at this parameter.
- (key -H) RADIUS server ip address

The first parameter uses host variable `radius_ip`.
The second parameter is fixed and is set to `--SPonly`.

### dependencies
- depends on ping

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

## ipsec

This test checks the state of IPSec connection between servers. Tests whether the server is reachable by response to ICMP echo request though ipsec tunnel.
Test is assigned only to servers which are part of the infrastructure and are connected using the IPSec protocol.
Test is not available on servers only used for monitoring.

Test is run remotely on radius1.eduroam.cz (national top level server).
In case the ping succeeds, it is assumed, that the ipsec tunnel is assembled.
It is also assumed, that radius1.eduroam.cz has kernel policies which disallows it to ping
the target server without assembled ipsec tunnel.
It would be better to check that the SA has been agreed on and the ping, but that would be quite complicated.

Test is done by [check_ipsec](https://github.com/CESNET/eduroam-icinga/blob/master/tests/check_ipsec).

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

This test checks that the RADIUS server is sending Calling-Station-Id attribute.
Test is implemented on the base of logs from national RADIUS server. Source data are refreshed once an hour.
Test is run remotely on radius1.eduroam.cz.
This test only applies to servers that are directly connected to national RADIUS server.

Test is done by [test-Calling-Station-Id-v2.pl](https://github.com/CESNET/eduroam-icinga/blob/master/tests/test-Calling-Station-Id-v2.pl).

### parameters

The script takes 2 parameters:
- (key -F) source data file
- (key -H) radius ip address

The first parameter is fixed and is set to `/var/log/arch/radiator/ON_CSI.last`.
The second parameter uses host variable `radius_ip`.

### dependencies

- depends on ping

### check intervals

- normal check period is 24 hours
- check period is 12 hours in case of outage
- CRITICAL-HARD state is reached after 3 failed checks

### notifications

Notifications for this test are enabled.
Notification interval it set to 24 hours.

<!--
# ==========================================================================================================================================
-->

## vcelka maja

Tests sending the inner EAP identity. The outer identity is `vcelka-maja@realm`, the inner identity is `test001@cesnet.cz`.
If Access-accept is sent for this test, it means failure.
Technical report on this is available [here](http://archiv.cesnet.cz/doc/techzpravy/2008/incorrect-eap-termination-in-eduroam/).

Test is done by [vcelka-maja](https://github.com/CESNET/eduroam-icinga/blob/master/tests/vcelka-maja).

This test is multiplied by number of home realms for each server. So if the server has two home realms, it has the test for each of them.

### parameters

The script takes 7 parameters:
- username
- password
- RADIUS ip address
- shared secret
- realm
- MAC address 1
- MAC address 2

The first parameter is fixed and is set to `test001@cesnet.cz`.
The second parameter is fixed.
The third parameter uses host variable `radius_ip`.
The fourth parameter uses host variable `mon_radius_secret`.
The fifth parameter uses service variable `realm`.
The sixth parameter uses service variable `mac_address1`.
The seventh parameter uses service variable `mac_address2`.

### dependencies

- depends on home realm

### check intervals

- normal check period is 48 hours
- check period is 3 hours in case of outage
- CRITICAL-HARD state is reached after 3 failed checks

### notifications

Notifications for this test are enabled.
Notification interval it set to 24 hours.

<!--
# ==========================================================================================================================================
-->

## operator name

This test checks that the RADIUS server is sending Operator-Name attribute. Existence of attribute and syntax are checked.
Test is implemented on the base of logs from national RADIUS server. Source data are refreshed once an hour.
Test is run remotely on radius1.eduroam.cz.
This test only applies to servers that are directly connected to national RADIUS server.

Test is done by [test-Operator-Name.pl](https://github.com/CESNET/eduroam-icinga/blob/master/tests/test-Operator-Name.pl).

### parameters

The script takes 2 parameters:
- (key -F) source data file
- (key -H) radius ip address

The first parameter is fixed and is set to `/var/log/arch/radiator/ON_CSI.last`.
The second parameter uses host variable `radius_ip`.

### dependencies

- depends on ping

### check intervals

- normal check period is 24 hours
- check period is 12 hours in case of outage
- CRITICAL-HARD state is reached after 3 failed checks

### notifications

Notifications for this test are **NOT** enabled.
Notifications are disabled for this test because operator-name attribute is not set as mandatory by czech eduroam policy.
It is recommended to implement this attribute.


<!--
# ==========================================================================================================================================
-->

## chargeable user identity

This test checks that the RADIUS server is sending Chargeable-User-Idenity attribute.
The test is run from CESNET's RADIUS servers with the organization's testing account.

Test is done by [test-Chargeable-User-Identity.pl](https://github.com/CESNET/eduroam-icinga/blob/master/tests/test-Chargeable-User-Identity.pl).

This test is multiplied by number of home realms for each server. So if the server has two home realms, it has the test for each of them.

### parameters

The script takes 6 parameters:
- (key -H) radius ip address
- (key -M) MAC address
- (key -P) port number
- (key -S) shared secret
- (key -p) testing password
- (key -u) username

The first parameter uses host variable `radius_ip`.
The second parameter uses service variable `mac_address`.
The third parameter is fixed and is set to `1812`.
The fourth parameter uses host variable `mon_radius_secret`.
The fifth parameter uses service variable `testing_password`.
The sixth parameter uses service variable `testing_id`.

### dependencies

- depends on home realm

### check intervals

- normal check period is 48 hours
- check period is 3 hours in case of outage
- CRITICAL-HARD state is reached after 3 failed checks

### notifications

Notifications for this test are **NOT** enabled.
Notifications are disabled for this test because chargeable-user-identity attribute is not set as mandatory by czech eduroam policy.
It is recommended to implement this attribute.

<!--
# ==========================================================================================================================================
-->

## institution.xml

Tests existence of the institution.xml file. The file is tested for existence of string "inst\_realm".

Test is done by icinga standard plugin `check_http`. The command line is set as `check_http --onredirect=follow`.

This test is multiplied by number of home realms for first home server. So if the server has two home realms, it has the test for each of them.

### parameters

The script takes 5 parameters:
- indication, that hostname extension support is needed. There is actually only key `--sni` at this parameter. Only set if service variable `xml_https` is set to 1.
- (key -H) host name
- indication, that https must be used. There is actually only key `-S` at this parameter. Only set if service variable `xml_https` is set to 1.
- (key -s) string to search in downloaded file
- (key -u) part of the url after /

The second parameter uses service variable `xml_host`.
The fourth parameter is fixed and is set to `inst_realm`.
The fifth parameter uses service variable `xml_url_part`.

### dependencies

- depends on ping

### check intervals

- normal check period is 24 hours
- check period is 3 hours in case of outage
- CRITICAL-HARD state is reached after 3 failed checks

### notifications

Notifications for this test are enabled.
Notification interval it set to 24 hours.

<!--
# ==========================================================================================================================================
-->

## fake uid

Tests if the organization forces inner and outer identity to be equal. Randomized identity is used as outer idenity.
Organiyzation's testing id is used as inner identity. The IdP must not evaluate this request positively.

Test is done by [check-fake-id](https://github.com/CESNET/eduroam-icinga/blob/master/tests/check-fake-id).

This test is multiplied by number of home realms for each server. So if the server has two home realms, it has the test for each of them.

### parameters

The script takes 5 parameters:
- (key -A) anonymous identity
- (key -H) RADIUS ip address
- (key -M) MAC address
- (key -P) port number
- (key -S) shared secret
- (key -e) type
- (key -m) type
- (key -p) testing password
- (key -t) timeout
- (key -u) username

The first parameter uses service variable `anon_id`.
The second parameter uses host variable `radius_ip`.
The third parameter uses service variable `mac_address`.
The fourth parameter is fixed and is set to `1812`.
The fifth parameter uses host variable `mon_radius_secret`.
The sixth parameter is fixed and is set to `PEAP`.
The seventh parameter is fixed and is set to `WPA-EAP`.
The eight parameter uses host service `testing_password`.
The ningth parameter is fixed and is set to `50`.
The tenth parameter uses service variable `testing_id`.

### dependencies

- depends on home realm

### check intervals

- normal check period is 48 hours
- check period is 3 hours in case of outage
- CRITICAL-HARD state is reached after 3 failed checks

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
This is actually special case of visitors' realms test.
Service has a dynamic name in form `@realm`.

Test is done by [rad_eap_test](https://github.com/CESNET/eduroam-icinga/blob/master/tests/rad_eap_test).

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

The configuration must assure that two tests with with the same username must always have different MAC address (-M key).
Timeouts also apply in this condition.

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

This test uses `rad_eap_test` to check if the testing user from the organization can be authenticated on server.
All testing users are tested on all servers.

Test is done by [rad_eap_test](https://github.com/CESNET/eduroam-icinga/blob/master/tests/rad_eap_test).

### parameters

Same as for [home-realm](#home-realm).

### dependencies

- each visitor's realm depends on authentication on home servers

There can be two cases:
- multiple home servers
- single home server

In case of multiple home servers, the visitor's realm check depends on service `HOME-REALM-ALIVE` on one of home servers (`HOME-REALM-ALIVE` service exists only on one of home servers).
In case of single home server, the visitor's realm check depends on home realm check on home server.

TODO - other realms should depend on home realm on server

### check intervals

- normal check period is 180 minutes
- check period is 120 minutes in case of outage
- CRITICAL-HARD state is reached after 3 failed checks

### notifications

Notifications for this test are **NOT** enabled.
Notifications are disabled for this test because the administrator(s) of the corrensponding server can not affect if the home server
authenticates the user correctly. That is also the reason why notifications are enabled for home realm.

<!--
# ==========================================================================================================================================
-->

## big packet

Test of relaying fragmented UDP packets. Test is realized by user big-test@cesnet.cz on every RADIUS server.
User big-test@cesnet.cz sends Access-accept stuffed with Reply-Message so it surely overflows 1500B.

The path tested by this test depends on connection protocol used.
In case of ipsec:
national RADIUS -> institution RADIUS -> AP

In case of radsec:
institution RADIUS -> AP

This is path of the answer from CESNET RADIUS server.

In both cases it also tests path institution RADIUS -> ermon (monitoring) for response which does to ermon (monitoring) instead of AP,
which could be seen as ability to send fragmented packet over large portion of Internet.

Test is done by [rad_eap_test](https://github.com/CESNET/eduroam-icinga/blob/master/tests/rad_eap_test).

### parameters

Almost the same as [home-realm](#home-realm).
Username is set to fixed value `big-test@cesnet.cz`.
Testing password is also set to a fixed value.
All other parameters are same as for [home-realm](#home-realm).

### dependencies

- depends on home realm

### check intervals

- normal check period is 24 hours
- check period is 12 hours in case of outage
- CRITICAL-HARD state is reached after 3 failed checks

### notifications

Notifications for this test are **NOT** enabled.

reason TODO

<!--
# ==========================================================================================================================================
-->

## cve-2017-9148

TODO

This test is multiplied by number of home realms for each server. So if the server has two home realms, it has the test for each of them.

### parameters
TODO

### dependencies
TODO

### check intervals
TODO

### notifications

Notifications for this test are enabled.
Notification interval it set to 24 hours.

<!--
# ==========================================================================================================================================
-->

## visitors

The purpose of this test is to inform the administrator(s) of the server, that visitors can have issues with authentication.
The problem is, that there are always several realms that currently do not work at some servers.

The test checks how many of visitors' realms is able to authenticate. If there is more than 80% of realms, that can authenticate,
the state is OK. If there is more than 70% of realms, that can authenticate, the state is WARNING.
If there is less than 70%, the state is CRITICAL.

Test is done by [check_visitors.sh](https://github.com/CESNET/eduroam-icinga/blob/master/tests/check_visitors.sh).

### parameters

The script takes 1 parameter:
- name of the host

The first parameter uses host variable `name`.

### dependencies
- home realm

### check intervals

- normal check period is 180 minutes
- check period is 120 minutes in case of outage
- CRITICAL-HARD state is reached after 3 failed checks

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

This test was created just to represent state of home realm authentication on all home servers.
It has no other actual usefull value than as a dependency parent service.
The test was designed because icinga2 can not deal with multi parent dependencies.
These dependencies need to be evaluated with use of or logic. Icinga2 is not able to do that at the moment.

Test is done by [home_realm_alive.sh](https://github.com/CESNET/eduroam-icinga/blob/master/tests/home_realm_alive.sh).

This test is multiplied by number of home realms for first home server. So if the server has two home realms, it has the test for each of them.

### parameters

The script takes 2 or more parameters:
- realm
- home servers (1 or more parameters)

The first parameter uses host variable `name`.
All the other parameters are expanded from service variable `home_servers`.

### dependencies
no dependencies

### check intervals
- normal check period is 5 minutes
- check period is 10 minutes in case of outage
- CRITICAL-HARD state is reached after 3 failed checks

### modifications needed

This test internally uses the `icingacli` tool to get data.
For this plugin to work under nagios user, the user needs to be added to icingaweb2 group.
This is done by `usermod -a -G icingaweb2 nagios`.

### notifications

Notifications for this test are **NOT** enabled.
Notifications are disabled for this test because they would be redundant to notifications for home realm.

<!--
# ==========================================================================================================================================
-->

## concurrent inst

This test is based on the data from system [etlog](https://github.com/CESNET/etlog). 
This test identifies users which successfully authenticated in short time in distant locations with same MAC addresses.
These events could signalize that the source data from institution.xml could be outdated.
This test is based on source data from institution.xml from all institutions that are connected to czech eduroam infrastructure.

This test is done by [concurrent_inst.sh](https://github.com/CESNET/eduroam-icinga/blob/master/tests/concurrent_inst.sh).

This test is multiplied by number of home realms for first home server. So if the server has two home realms, it has the test for each of them.

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
This test is based on source data from institution.xml from all institutions that are connected to czech eduroam infrastructure.

This test is done by [compromised_users.sh](https://github.com/CESNET/eduroam-icinga/blob/master/tests/compromised_users.sh).

This test is multiplied by number of home realms for first home server. So if the server has two home realms, it has the test for each of them.

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

<!--
# ==========================================================================================================================================
-->

## notification settings

Notification are sent for all bad states (WARNING, CRITICAL, UNKNOWN), they are also sent for service recovery.

<!--
# ==========================================================================================================================================
-->

## IPv6 support

There is currently no IPv6 support. This is done on purpose.
Enabling ipv6 withing monitoring and RADIUS infrastructure ifself could cause a totally new problems and it would also
mean solving current problems in new manner and maybe twice for both ipv4 and ipv6.

Support of ipv6 in director - TODO
Most of the tests use host variable `radius_ip` which is filled by icinga-director import source.

<!--
# ==========================================================================================================================================
-->

## remote tests

Remote tests are run on radius1.eduroam.cz. The tests are run using icinga cluster protocol.
The client (radius1.eduroam.cz) only needs to know the definotion of the tests to run them.
Parameter relaying is done using the icinga cluster protocol.
