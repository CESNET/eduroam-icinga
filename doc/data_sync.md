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

1. The sychronization [script](https://github.com/CESNET/eduroam-icinga/blob/master/sync/main.sh) script is running at regular intervals by cron daemon.
Once a day reconfiguration of whole icinga setup if forced even if there are no changes in the source data.
Our evidence is partly based on DNS, so if anything changes in DNS, our configration remain the same.
The script runs another [script](https://github.com/CESNET/eduroam-icinga/blob/master/sync/ldap_sync.js).

2. The script checks the source of the data for changes.
If there are no changes, the script does no changes and the configuration attempt is terminated in main script.
If there are changes, the script gets the data from the data source.
(Our sync [script](https://github.com/CESNET/eduroam-icinga/blob/master/sync/ldap_sync.js) is highly tied to our environment so anyone else trying to implement this
should create sync tool suited for their environment.)

3. The script generates database data for director.

4. The script generates dynanic icinga2 configuration for fileshipper module to import in director.
The script's work ends here.

5. The main script synchronizes all director import sources.

6. Director import sources get data from previously filled database.

7. The main script synchronizes all director sync rules.

8. Director sync rules get data from director import sources.

9. New configuration is deployed.
Newly deployed configuration takes configratuion from several sources:
  - director config
  - director sync rules (could be viewed as part of director config)
  - fileshipper dynamic config
  - fileshipper static config
  - icinga2 configuration

The main script can send notification if something fails during the deployment process.


### database structure

The database layer used in data synchronization process has strictly defined structure.
The structure is tied to the director sync rules and import source.
In case anyone implements this while **NOT** respecting the database structure,
the director part of the synchronization will not work correctly.

We used the mysql database for this as well as for icinga2, but postgresql may surely be used too.
In case you would like to use postgresql, make sure the table design works fine.

The structure is ivailable in sql [form](https://github.com/CESNET/eduroam-icinga/blob/master/doc/database.sql).

#### tables

The database contains these tables:
- admin
- radius\_server
- realm
- testing\_id

##### table admin

This table contains information about realms' and servers' administators.
table structure:
```
+----------+--------------+------+-----+---------+-------+
| Field    | Type         | Null | Key | Default | Extra |
+----------+--------------+------+-----+---------+-------+
| admin_dn | varchar(191) | NO   | PRI | NULL    |       |
| admin_cn | varchar(191) | NO   |     | NULL    |       |
| mail     | varchar(191) | NO   |     | NULL    |       |
+----------+--------------+------+-----+---------+-------+
```

Example data:
```
+----------------------------------------+----------------+-----------------------------+
| admin_dn                               | admin_cn       | mail                        |
+----------------------------------------+----------------+-----------------------------+
| uid=user1,ou=People,dc=org,dc=cz       | John Doe       | user1-email@company.cz      |
| uid=user2,ou=People,dc=org,dc=cz       | Jan Novak      | user2-email@company.cz      |
| uid=user3,ou=People,dc=org,dc=cz       | Jane Doe       | user3-email@google.com      |
| uid=user4,ou=People,dc=org,dc=cz       | Real User      | user4-email@yahoo.com       |
| uid=user5,ou=People,dc=org,dc=cz       | Somebody Else  | user5-email@company.cz      |
+----------------------------------------+----------------+-----------------------------+
```

The column `admin_dn` is the primary key of this table. Is it also used to identify
users in other tables. A unique user identifier should be used here.

The column `admin_cn` holds the user full name. It is advised to keep this in ASCII only values.


The column `admin_cmail` holds the user email address. This is used for notifications.

##### table radius\_server

This table contains information about RADIUS servers.
table structure:
```
+-------------------+--------------+------+-----+---------+----------------+
| Field             | Type         | Null | Key | Default | Extra          |
+-------------------+--------------+------+-----+---------+----------------+
| id                | int(11)      | NO   | PRI | NULL    | auto_increment |
| radius_dn         | varchar(191) | NO   | MUL | NULL    |                |
| radius_cn         | varchar(191) | NO   |     | NULL    |                |
| transport         | varchar(191) | NO   |     | NULL    |                |
| mon_radius_secret | varchar(191) | NO   |     | NULL    |                |
| mon_realm         | varchar(191) | YES  | MUL | NULL    |                |
| inf_realm         | varchar(191) | YES  | MUL | NULL    |                |
| radius_manager    | varchar(191) | NO   | MUL | NULL    |                |
+-------------------+--------------+------+-----+---------+----------------+
```

The column `id` is the primary key of this table. The value has no other real meaning.

The column `radius_dn` fully identifies the radius server.

The column `radius_cn` is the domain name of the RADIUS server.

The column `transport` is the transport type that is used to connected to the national top level eduroam server.
There can be only two values in this field - "RADSEC" or "IPSEC".

The column `mon_radius_secret` is the secret shared between the RADIUS server and the monitoring server.

The column `mon_realm` is the realm which is monitored on this RADIUS server.
This column is a foreing key to the realm table. The column refenced is `realm_dn`.

The column `inf_realm` is the realm for which this RADIUS server handles the requests.
This column is a foreing key to the realm table. The column refenced is `realm_dn`.
This column is used to determine all expected values of Operator-Name attribute.

The column `radius_manager` is the administrator of this RADIUS server.
This column is a foreing key to the admin table. The column refenced is `admin_dn`.


Example data:
```
*************************** 1. row ***************************
               id: 1
        radius_dn: cn=radius.some.company.cz,ou=radius servers,o=eduroam,o=apps,dc=org,dc=cz
        radius_cn: radius.some.company.cz
inf_radius_secret: testing123
        transport: RADSEC
mon_radius_secret: some_monitoring_password
        mon_realm: cn=some.company.cz,ou=realms,o=eduroam,o=apps,dc=org,dc=cz
        inf_realm: cn=some.company.cz,ou=realms,o=eduroam,o=apps,dc=org,dc=cz
   radius_manager: uid=admin1,ou=People,dc=org,dc=cz
*************************** 2. row ***************************
               id: 2
        radius_dn: cn=radius.university1.cz,ou=radius servers,o=eduroam,o=apps,dc=org,dc=cz
        radius_cn: radius.university1.cz
inf_radius_secret: testing123
        transport: RADSEC
mon_radius_secret: some_monitoring_password
        mon_realm: cn=university1.cz,ou=realms,o=eduroam,o=apps,dc=org,dc=cz
        inf_realm: cn=university1.cz,ou=realms,o=eduroam,o=apps,dc=org,dc=cz
   radius_manager: uid=admin2,ou=People,dc=org,dc=cz
*************************** 3. row ***************************
               id: 3
        radius_dn: cn=radius.university2.cz,ou=radius servers,o=eduroam,o=apps,dc=org,dc=cz
        radius_cn: radius.university2.cz
inf_radius_secret: testing123
        transport: RADSEC
mon_radius_secret: some_monitoring_password
        mon_realm: cn=university2.cz,ou=realms,o=eduroam,o=apps,dc=org,dc=cz
        inf_realm: cn=university2.cz,ou=realms,o=eduroam,o=apps,dc=org,dc=cz
   radius_manager: uid=admin3,ou=People,dc=org,dc=cz
*************************** 4. row ***************************
               id: 4
        radius_dn: cn=radius.university3.cz,ou=radius servers,o=eduroam,o=apps,dc=org,dc=cz
        radius_cn: radius.university3.cz
inf_radius_secret: testing123
        transport: RADSEC
mon_radius_secret: some_monitoring_password
        mon_realm: cn=university3.cz,ou=realms,o=eduroam,o=apps,dc=org,dc=cz
        inf_realm: cn=university3.cz,ou=realms,o=eduroam,o=apps,dc=org,dc=cz
   radius_manager: uid=admin4,ou=People,dc=org,dc=cz
*************************** 5. row ***************************
               id: 5
        radius_dn: cn=radius.university3.cz,ou=radius servers,o=eduroam,o=apps,dc=org,dc=cz
        radius_cn: radius.university3.cz
inf_radius_secret: testing123
        transport: RADSEC
mon_radius_secret: some_monitoring_password
        mon_realm: cn=university3.cz,ou=realms,o=eduroam,o=apps,dc=org,dc=cz
        inf_realm: cn=university3.cz,ou=realms,o=eduroam,o=apps,dc=org,dc=cz
   radius_manager: uid=admin5,ou=People,dc=org,dc=cz
```

Each RADIUS server is stored individually for each administrator.
This is done on purpose. This can be solved by better sql schema of the whole database.
This was done just to ease the implementation.

##### table realm

This table contains information about realms.
table structure:
```
+---------------+--------------+------+-----+---------+----------------+
| Field         | Type         | Null | Key | Default | Extra          |
+---------------+--------------+------+-----+---------+----------------+
| id            | int(11)      | NO   | PRI | NULL    | auto_increment |
| realm_dn      | varchar(191) | NO   | MUL | NULL    |                |
| realm_cn      | varchar(191) | NO   |     | NULL    |                |
| member_type   | varchar(191) | NO   |     | NULL    |                |
| xml_url       | varchar(191) | NO   |     | NULL    |                |
| realm_manager | varchar(191) | NO   | MUL | NULL    |                |
+---------------+--------------+------+-----+---------+----------------+
```

The column `id` is the primary key of this table. The value has no other real meaning.

The column `realm_dn` full identifies the realm.

The column `realm_cn` is the domain name of the realm.

The column `member_type` represents the type of this server.
Only three values can be used here:
- "IdPSP" - can authenticate own users and also provides eduroam service
- "SP" - only provides eduroam service
- "IdP" - can only authenticate own users

The column `xml_url` is the url of the institution.xml file for this realm.
All realms must provide institution.xml files with the information about eduroam service coverage.

The column `realm_manager` is the realm administrator.
This column is a foreing key to the admin table. The column refenced is `admin_dn`.


Example data:
```
*************************** 1. row ***************************
           id: 1
     realm_dn: cn=org.cz,ou=realms,o=eduroam,o=apps,dc=org,dc=cz
     realm_cn: org.cz,org.eu,guest.org.cz
       status: connected
  member_type: IdPSP
      xml_url: http://eduroam.org.cz/institution.xml
realm_manager: uid=admin1,ou=People,dc=org,dc=cz
*************************** 2. row ***************************
           id: 2
     realm_dn: cn=org.cz,ou=realms,o=eduroam,o=apps,dc=org,dc=cz
     realm_cn: org.cz,org.eu,guest.org.cz
       status: connected
  member_type: IdPSP
      xml_url: http://eduroam.org.cz/institution.xml
realm_manager: uid=admin2,ou=People,dc=org,dc=cz
*************************** 3. row ***************************
           id: 3
     realm_dn: cn=org.cz,ou=realms,o=eduroam,o=apps,dc=org,dc=cz
     realm_cn: org.cz,org.eu,guest.org.cz
       status: connected
  member_type: IdPSP
      xml_url: http://eduroam.org.cz/institution.xml
realm_manager: uid=admin3,ou=People,dc=org,dc=cz
*************************** 4. row ***************************
           id: 4
     realm_dn: cn=org.cz,ou=realms,o=eduroam,o=apps,dc=org,dc=cz
     realm_cn: org.cz,org.eu,guest.org.cz
       status: connected
  member_type: IdPSP
      xml_url: http://eduroam.org.cz/institution.xml
realm_manager: uid=admin4,ou=People,dc=org,dc=cz
*************************** 5. row ***************************
           id: 5
     realm_dn: cn=university1.cz,ou=realms,o=eduroam,o=apps,dc=org,dc=cz
     realm_cn: university1.cz
       status: connected
  member_type: IdPSP
      xml_url: http://eduroam.university1.cz/institution.xml
realm_manager: uid=admin5,ou=People,dc=org,dc=cz
```

Each realm is stored individually for each administrator.
This is done on purpose. This can be solved by better sql schema of the whole database.
This was done just to ease the implementation.


## ER diagram

![entity relationship diagram](https://github.com/CESNET/eduroam-icinga/blob/master/doc/database_schema.png "ER diagram")

![entity relationship diagram 2](https://github.com/CESNET/eduroam-icinga/blob/master/doc/database_schema2.png "ER diagram 2")

## director

Data synchronization to director is done using combination of import sources and sync rules.
These are defined in [director config](https://github.com/CESNET/eduroam-icinga/blob/master/doc/director_config.md).
The synchronization itself means synchronizing all the sync rules in correct order.
This can be done automatically (for example by [script](https://github.com/CESNET/eduroam-icinga/blob/master/sync/main.sh#L54)) or manually in icingaweb2.

