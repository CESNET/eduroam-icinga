# motivation

The monitoring setup needs to work with all the relevant eduroam data the NREN has.
To acomplish this, the data needs to be synchronized from the source to the monitoring somehow.
The actual method of synchronization depends on the source form of data.

Our source data are stored in LDAP, so we made a script for synchronization from LDAP.
Our structure is probably unique, so anyone else should create their own tools to handle synchronization from source.

We also created an extra compatibility layer in form of database and configuration files.
Both have precisely defined structure.
Anyone who wishes to use this monitoring setup needs just to transform source data
to these two forms. Additional synchronization to icinga2 is done by icigaweb2 modules.
Any experienced administrator should not have many problems transforming the source data.

## Data synchronization

Configuration data about Czech eduroam infrastructure are stored in an LDAP in a quite complex structure, this includes hostnames of RADIUSes, shared secrets, testing accounts, assignment of realms to RADIUS servers and more. How to get the configuration data from the LDAP to the icinga2 was the tricky part of this implementation.

Director is able to work with various data sources. At first we wanted to sync our LDAP data source directly to the director.
Our structure is was too problematic for director to be used directly. There were big data transformation problems.
To use director directly with LDAP, we would have to change our structure or rewrite some parts of the director synchronization code.
None of this seemed to us as a good option, so we decided to look for another path to take.

The newer method used LDAP synchronization [script](https://github.com/CESNET/eduroam-icinga/blob/master/sync/ldap_sync.js) to get the data.
All the transformations needed were now very simple, because all the logic needed was much easier to express in programming language.
The data were lastly stored in a database where director could read them.
This solution was much better that the direct LDAP interaction, but it still had some problems.
The biggest problem was the number of synchronized services. We currently have about 200 active RADIUS servers and about 150 realms.
This generated more than 30 k services in the database.
Director gathered all the data from the database and created all the services.
The problem was this was taking really long time (several hours).
There were no problems with server hardware or load, it was just a bad design and usage.

Our final tried to avoid synchronization of too many objects.
Fileshipper module seemed to be what we really needed.
It allowed us to keep all the previous objects in the database and focus on the services in another way.
The new way of configuring services was to use apply rules which were really the correct way to solve this.
The fileshipper configuration was split in two parts - static and dynamic.
With static and dynanimc part of the configuration this worked really well.
Only the dynamic configuration changes, it is also very small, so there should be less space for errors.
It has a minor drawback which is generated configuration.
It fits all the other configuration we have and works flawlessly.

The diagram below shows how the data are transfered to icinga2.

![data flow diagram](https://github.com/CESNET/eduroam-icinga/blob/master/doc/data_flow_explained.png "data flow diagram")

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


## source synchronization

## CESNET specific part

## mysql

### database structure

## director
