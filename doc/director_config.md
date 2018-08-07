# director configuration

This summarizes director configuration.
All the configuration is done via icingaweb2 director section. 
Because the configuration is done in gui, is is hard to document it. 
Director provides an export and import features through icingacli which help documentation process a lot.
Nevertheless it is also documented where to do this in icingaweb2.

![director module in icingaweb2](https://github.com/CESNET/eduroam-icinga/blob/master/doc/director.png "director module in icingaweb2")

Using director enables together with all tools in this setup enables
the configuration to be fully automated.
This means that when the source data changes,
it propagates all the changes to whole monitoring setup and deploys the changes made without any human interaction.

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
so we decided to add an extra "compatibility" layer in form of a database.
This database is filled by our synchronization [scripts](https://github.com/CESNET/eduroam-icinga/tree/master/sync).


This was a good way to overcome some of the problems with data transformations
and also this abstracts our evidence structure a lot, so anyone who undestrands the
designed database structure can use this.


The import sources themselves are highly tied to database structure used.
Please read carefully the documentation about database schema and follow it.


Our import sources [import_sources.json](https://github.com/CESNET/eduroam-icinga/blob/master/doc/example_config/director/import_sources.json)
You can use these exported data for import using:
```
icingacli director import importsource
```

There is no import source for services. This import source was the most problematic one.
The sync rule tied to this import source was constantly having serious problems (really long runs, errors, ...).
This import source and sync rule was replaced by [fileshipper](https://github.com/CESNET/eduroam-icinga/blob/master/doc/icinga2_config.md#fileshipper)
module and its [static](https://github.com/CESNET/eduroam-icinga/blob/master/doc/icinga2_config.md#static-configuration)
and [dynamic](https://github.com/CESNET/eduroam-icinga/blob/master/doc/icinga2_config.md#dynamic-configuration) configuration which does not have any of these problems.

### import source for hosts

This import source defines source data for synchronization of hosts.
A number of modifiers is used to transform some of the values to desired data types.
The most important modifier is the one, which fills variable `radius_ip`.
This modifier looks up host by name. It is not clear if there is IPv6 support. (see [this](https://github.com/CESNET/eduroam-icinga/blob/master/doc/tests.md#ipv6-support))
The modifier has always filled an IPv4 address, so no real problems arised, but this could potentially cause problems.

#### DNS failure

It sometimes happens, that some RADIUS host names are not resolvable from DNS. In case this happens TODO

### import source for realms

This import source defines source data for synchronization of hostgroups and servicegroups.

### import source for users

This import source defines source data for synchronization of users.

## Sync rules

Sync rules define how data from import sources are mapped to icinga2 objects.
The mapping is done for every row from the import source data.
For each row from import source data an object of selected type is created.
Object properties can be filled by selecting mapping of fields from import source data.

![sync rules](https://github.com/CESNET/eduroam-icinga/blob/master/doc/import_sources.png "sync rules")

Our sync rules [syncrules.json](https://github.com/CESNET/eduroam-icinga/blob/master/doc/example_config/director/syncurles.json)

You can use these exported data for import using:
```
icingacli director import syncrule
```

It is important that syncrules are ran in correct order.
If they are run in incorrect order, the dependent sync rule will fail with some error.
The order of rules should be clear to any experienced administrators.
The order is defined in synchronization scripts [configuration](https://github.com/CESNET/eduroam-icinga/blob/master/sync/config/config.sh#L6),
but it not very meaningful (the numbers are id's of single rules).

### sync rule for hostgroups

Uses import source for realms. Creates hostgroups which are named as realms which the servers handle.
This sync rule **must** be run before sync rule for hosts.

### sync rule for hosts

Uses import source for hosts. Creates hosts with DNS names of RADIUS servers.

### sync rule for servicegroups

Uses import source for realms. Creates servicegroups which are named as realms which the servers handle.

### sync rule for usergoups

Uses import source for hosts. Creates usergroups with DNS names of RADIUS servers.
This sync rule **must** be run before sync rule for users.

### sync rule for users

Uses import source for users. Creates users with their names. Names are set only to ascii (for more see [this](https://github.com/CESNET/eduroam-icinga/blob/master/sync/ldap_sync.js#L608)).

## Host templates

Host templates are used to simplify configuration by extracting common configuration to template.
We use just one host template for all the servers:

```
template Host "generic eduroam radius server" {
    check_command = "dummy"
    check_interval = 365d
}
```

This template uses a dummy check which does nothing and always returns successfull state.
This is done on purpose. We just want to monitor the services on the host specifically and not the host itself.
Check interval is set to 365 days, there is no need to do a dummy check every 5 minutes.

There is currently no way that this configuration can be exported or imported,
so this has to be done manually in the director.

## Service templates

TODO

### BIG-PACKET

```
template Service "big packet template" {
    check_command = "check_rad_eap"
    max_check_attempts = "3"
    check_interval = 1d
    retry_interval = 12h
    enable_notifications = true
    enable_flapping = true
    command_endpoint = null
}
```

### CHARGEABLE-USER-IDENTITY
```
template Service "chargeable user identity template" {
    check_command = "check_cui"
    max_check_attempts = "3"
    check_interval = 2d
    retry_interval = 3h
    enable_notifications = true
    enable_flapping = true
    command_endpoint = null
}
```

### COMPROMISED-USERS
```
template Service "compromised users template" {
    check_command = "check_compromised"
    max_check_attempts = "3"
    check_interval = 2d
    retry_interval = 12h
    enable_notifications = true
    command_endpoint = null
}
```

### CONCURRENT-INST
```
template Service "concurrent inst template" {
    check_command = "check_concurrent"
    max_check_attempts = "3"
    check_interval = 2d
    retry_interval = 12h
    enable_notifications = true
    command_endpoint = null
}
```

### CVE-2017-9148
```
template Service "cve-2017-9148 template" {
    check_command = "check_cve_2017_9148"
    max_check_attempts = "3"
    check_interval = 2d
    retry_interval = 3h
    enable_notifications = true
    enable_flapping = true
    command_endpoint = null
}
```

### FAKE-UID
```
template Service "fake uid template" {
    check_command = "check_fake_uid"
    max_check_attempts = "3"
    check_interval = 2d
    retry_interval = 3h
    enable_notifications = true
    enable_flapping = true
    command_endpoint = null
}
```

### HOME-REALM-ALIVE
```
template Service "home realm alive template" {
    check_command = "check_home_realm_alive"
    max_check_attempts = "3"
    check_interval = 5m
    retry_interval = 10m
}
```


### INSTITUTION-XML
```
template Service "institution xml template" {
    check_command = "check_institution_xml"
    max_check_attempts = "3"
    check_interval = 1d
    retry_interval = 3h
    enable_notifications = true
}
```


### PING
```
template Service "ping template" {
    check_command = "ping4"
    max_check_attempts = "10"
    check_interval = 5m
    retry_interval = 1m
    enable_notifications = true
    enable_flapping = true
    groups = [ "PING" ]
    command_endpoint = null
}
```


### VCELKA-MAJA
```
template Service "vcelka maja template" {
    check_command = "check_vcelka_maja"
    max_check_attempts = "3"
    check_interval = 2d
    retry_interval = 3h
    enable_notifications = true
    enable_flapping = true
    command_endpoint = null
}
```

### VISITORS
```
template Service "visitors template" {
    check_command = "check_visitors"
    max_check_attempts = "3"
    check_interval = 3h
    retry_interval = 2h
    command_endpoint = null
    vars.doc_url = "https://www.eduroam.cz/cs/spravce/monitoring/end2end_monitoring_new#visitors"
}
```


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


## Manually added hosts

TODO - client
