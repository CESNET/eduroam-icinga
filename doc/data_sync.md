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
| uid      | varchar(191) | NO   |     | NULL    |       |
+----------+--------------+------+-----+---------+-------+
```

Example data:
```
+----------------------------------------+----------------+-----------------------------+----------+
| admin_dn                               | admin_cn       | mail                        | uid      |
+----------------------------------------+----------------+-----------------------------+----------+
| uid=user1,ou=People,dc=org,dc=cz       | John Doe       | user1-email@company.cz      | user1    |
| uid=user2,ou=People,dc=org,dc=cz       | Jan Novak      | user2-email@company.cz      | user2    |
| uid=user3,ou=People,dc=org,dc=cz       | Jane Doe       | user3-email@google.com      | user3    |
| uid=user4,ou=People,dc=org,dc=cz       | Real User      | user4-email@yahoo.com       | user4    |
| uid=user5,ou=People,dc=org,dc=cz       | Somebody Else  | user5-email@company.cz      | user5    |
+----------------------------------------+----------------+-----------------------------+----------+
```

The column `admin_dn` is the primary key of this table. Is it also used to identify
users in other tables. A unique user identifier should be used here.

The column `admin_cn` holds the user full name. It is advised to keep this in ASCII only values.


The column `admin_cmail` holds the user email address. This is used for notifications.

The column `uid` holds user identifier. This is currently not used. TODO

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
| inf_radius_secret | varchar(191) | NO   |     | NULL    |                |
| transport         | varchar(191) | NO   |     | NULL    |                |
| mon_radius_secret | varchar(191) | NO   |     | NULL    |                |
| mon_realm         | varchar(191) | YES  | MUL | NULL    |                |
| inf_realm         | varchar(191) | YES  | MUL | NULL    |                |
| radius_manager    | varchar(191) | NO   | MUL | NULL    |                |
+-------------------+--------------+------+-----+---------+----------------+
```

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
| status        | varchar(191) | NO   |     | NULL    |                |
| member_type   | varchar(191) | NO   |     | NULL    |                |
| xml_url       | varchar(191) | NO   |     | NULL    |                |
| realm_manager | varchar(191) | NO   | MUL | NULL    |                |
| testing_id    | varchar(191) | YES  | MUL | NULL    |                |
+---------------+--------------+------+-----+---------+----------------+
```

##### table testing\_id

This table contains information about testing accounts.
table structure:
```
+----------+--------------+------+-----+---------+-------+
| Field    | Type         | Null | Key | Default | Extra |
+----------+--------------+------+-----+---------+-------+
| id       | varchar(191) | NO   | MUL | NULL    |       |
| password | varchar(191) | NO   |     | NULL    |       |
+----------+--------------+------+-----+---------+-------+
```

## clients

## director
