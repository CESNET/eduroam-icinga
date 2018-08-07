# director configuration

This summarizes director configuration.
All the configuration is done via icingaweb2 director section. 
Because the configuration is done in gui, is is hard to document it. 
Director provides an export and import features through icingacli which help documentation process a lot.
Nevertheless it is also documented where to do this in icingaweb2.

![director module in icingaweb2](https://github.com/CESNET/eduroam-icinga/blob/master/doc/director.png "director module in icingaweb2")

## Import sources

Import sources are available in the automation section in director section.

![import sources](https://github.com/CESNET/eduroam-icinga/blob/master/doc/import_sources.png "import sources")

Import sources are the most important part of director configuration.
Import sources define a source (icingaweb2 resource).
Import source type can be ldap, sql, core api or fileshipper.
After defining the import source define a sync rule which used to synchronize the data.

For our import sources we chose the sql type.
At first we tried to use ldap type because our evidence uses ldap.
There were several problems with ldap import source and data transformations,
so we decided to add an extra "compatibility" layer in form of database.
This database is filled by our synchronization [scripts](https://github.com/CESNET/eduroam-icinga/tree/master/sync).


This was a good way to overcome some of the problems with data transformations
and also this abstracts our evidence structure a lot, so anyone who undestrands the
designed database structure can use this.


The import sources themselves are highly tied to database structure used.
Please read carefully the documentation about database schema and follow it.


There is no import source for services. This import source was the most problematic one.
The sync rule tied to this import source was constantly having serious problems (really long runs, errors, ...).
This import source and sync rule was replaced by [fileshipper](https://github.com/CESNET/eduroam-icinga/blob/master/doc/icinga2_config.md#fileshipper)
module and its [static](https://github.com/CESNET/eduroam-icinga/blob/master/doc/icinga2_config.md#static-configuration)
and [dynamic](https://github.com/CESNET/eduroam-icinga/blob/master/doc/icinga2_config.md#dynamic-configuration) configuration which does not have any of these problems.

### import source for hosts

TODO

#### DNS failure

TODO

### import source for realms

TODO

### import source for users

TODO


Our import sources [import_sources.json](https://github.com/CESNET/eduroam-icinga/blob/master/doc/example_config/director/import_sources.json)
You can use these exported data for import using:
```
icingacli director import importsource
```

## Sync rules

TODO

Our sync rules [syncrules.json](https://github.com/CESNET/eduroam-icinga/blob/master/doc/example_config/director/syncurles.json)
You can use these exported data for import using:
```
icingacli director import syncrule
```

### sync rule for hostgroups

TODO

### sync rule for hosts

TODO

### sync rule for servicegroups

TODO

### sync rule for usergoups

TODO

### sync rule for users

TODO

## Host templates

TODO

## Service templates

TODO

## Service groups

TODO

## Service apply rules

TODO

## Commands

TODO

## Notification templates

TODO

## Endpoints

TODO

## Zones

TODO

## Data fields

TODO


