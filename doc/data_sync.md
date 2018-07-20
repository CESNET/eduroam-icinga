## Data synchronization

Configuration data about Czech eduroam infrastructure are stored in an LDAP in a quite complex structure, this includes hostnames of RADIUSes, shared secrets, testing accounts, assignment of realms to RADIUS servers and more. How to get the configuration data from the LDAP to the icinga2 was the tricky part of this implementation.

TODO: Zminka ze director umi cist LDAP ale nase struktura mu delala potize. Zalezi co si vzpomenes. 

The diagram below shows how the data are transfered to icinga2.

![diagram](https://github.com/CESNET/eduroam-icinga/blob/master/doc/data_flow.png "Diagram")

The diagram could be described as follows:
1. The sychronization script gets the data from the data source.
(In our case this is done by https://github.com/CESNET/eduroam-icinga/blob/master/sync/ldap_sync.js ,
but this is highly tied to our environment so anyone else trying to implement this
should create sync tool suited for their environment.)

2. The data are transferred to the synchronization script.

3. The script generates dynanic icinga2 configuration for fileshipper module to import in director.
The script generates database data for director.

4. (Not shown in the diagram)
This step is needed to apply all the prepared configuration to icinga2.
Synchronize icinga director import sources & sync rules.

5. (Not shown in the diagram)
This step is needed to apply all the prepared configuration to icinga2
Deploy icinga director configuration.


- director
- plain config in /etc/icinga2
- client config
- fileshipper

