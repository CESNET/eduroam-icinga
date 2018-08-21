# director configuration

Director is a config management module for icingaweb2.
Icingaweb2 enhanched with director enables users to use it to create icinga2 configuration.

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

One of really good features of this setup is that the configuration management can
be either automated or the monitoring server administrator can deploy configuration manually
when needed. All the configuration director modifications are tracked in activity log.
The deployment log can provide a diff between specific files from deployed configurations.
This can also be used on some fileshipper configuration in case that there would be any changes.
This could help diagnose any encountered problems with apply rules or so.

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
This modifier looks up host by name. It returns IPv4 address. (see [this](https://github.com/CESNET/eduroam-icinga/blob/master/doc/tests.md#ipv6-support))

#### DNS failure

It sometimes happens, that some RADIUS host names are not resolvable from DNS.
When this happens someone should be notified about this.

In case this happens without any deployments,
all the tests except PING will be working fine.
In case this happens with new configuration deployment,
the modifier mentioned above will set variable `radius_ip` as null.
All the tests which use this variable will get to state UNKNOWN since
the variable will not be available.

In both cases the PING test will return someting like:
```
Invalid hostname/address - radius.domain.tld
```

To be able to notify administrators about this, simple [script](https://github.com/CESNET/eduroam-icinga/blob/master/other/check_dns.sh) was created.
This script should be run at regular intervals by cron daemon.
It checks all the ping services using `icingacli`.
If there are some services which report the error message mentioned above,
the script notifies administrators about this.

### import source for realms

This import source defines source data for synchronization of hostgroups and servicegroups.

### import source for users

This import source defines source data for synchronization of users.

## Sync rules

Sync rules define how data from import sources are mapped to icinga2 objects.
The mapping is done for every row from the import source data.
For each row from import source data an object of selected type is created.
Object properties can be filled by selecting mapping of fields from import source data.

![sync rules](https://github.com/CESNET/eduroam-icinga/blob/master/doc/sync_rules.png "sync rules")

Our sync rules [syncrules.json](https://github.com/CESNET/eduroam-icinga/blob/master/doc/example_config/director/syncrules.json)

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

Service templates are assigned to service definitions.
This is used in [static_config](https://github.com/CESNET/eduroam-icinga/blob/master/doc/example_config/fileshipper/static_config.conf),
in [services.conf](https://github.com/CESNET/eduroam-icinga/blob/master/doc/example_config/icinga2/templates.conf)
and in director service apply rules.

![service templates](https://github.com/CESNET/eduroam-icinga/blob/master/doc/service_templates.png "service templates")

Some of the templates may indicate that the are not in use when viewed in icingaweb2.
This may not be completely true, because some files from fileshipper may still use these templates.
Director has no way of knowing if some fileshipper configration uses these or not.

There is currently no way that this configuration can be exported or imported,
so this has to be done manually in the director.

All the used templates are defined below.

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

### CALLING-STATION-ID
```
template Service "calling station id template" {
    check_command = "check_csi"
    max_check_attempts = "3"
    check_interval = 1d
    retry_interval = 12h
    enable_notifications = true
    enable_flapping = true
    command_endpoint = null
}
```

### OPERATOR-NAME
```
template Service "operator name template" {
    check_command = "check_operator_name"
    max_check_attempts = "3"
    check_interval = 1d
    retry_interval = 12h
    enable_notifications = true
    enable_flapping = true
    command_endpoint = null
}
```

## Service groups

Most of the service groups are defined in [groups.conf](https://github.com/CESNET/eduroam-icinga/blob/master/doc/example_config/icinga2/groups.conf).
Only two groups are defined in director, because service apply rules for these services are also configured in director.

Servicegroup for PING service:

```
object ServiceGroup "PING" {
    display_name = "PING"
}
```

Servicegroup for VISITORS service:
```
object ServiceGroup "VISITORS" {
    display_name = "VISITORS"
}
```

Export of our service groups [servicegroups.json](https://github.com/CESNET/eduroam-icinga/blob/master/doc/example_config/director/servicegroups.json)
The import is not possible currently.

## Service apply rules

Most of the service apply rules are defined in [static_config.conf](https://github.com/CESNET/eduroam-icinga/blob/master/doc/example_config/fileshipper/static_config.conf).
Only two service apply rules are defined in director.


Service apply rule for PING:
```
apply Service "PING" {
    import "ping template"

    assign where host.name

    import DirectorOverrideTemplate
}
```

Service apply rule for VISITORS:
```
apply Service "VISITORS" {
    import "visitors template"

    assign where host.vars.mon_realm
    groups = [ "VISITORS" ]

    import DirectorOverrideTemplate
}
```

There is currently no way that this configuration can be exported or imported,
so this has to be done manually in the director.


## Commands

Commands represent the plugins used for checks.

![commands](https://github.com/CESNET/eduroam-icinga/blob/master/doc/commands.png "commands")

There is currently no way that this configuration can be exported or imported,
so this has to be done manually in the director.

Some of the commands will show that they are not used when viewed in icingaweb2.
This is because they are used in icinga2 configuration. Director has no way of knowing this.

All the used commands are defined below.

### CHECK-COMPROMISED
```
object CheckCommand "check_compromised" {
    import "plugin-check-command"
    command = [ PluginDir + "/compromised_users.sh" ]
    arguments += {
        "(no key)" = {
            order = 2
            required = true
            skip_key = true
            value = "$host.vars.all_realms$"
        }
        "(no key.2)" = {
            order = 1
            required = true
            skip_key = true
            value = "60"
        }
    }
}
```

### CHECK-CONCURRENT
```
object CheckCommand "check_concurrent" {
    import "plugin-check-command"
    command = [ PluginDir + "/concurrent_inst.sh" ]
    arguments += {
        "(no key)" = {
            order = 1
            required = true
            skip_key = true
            value = "$service.vars.realm$"
        }
        "(no key.2)" = {
            order = 2
            required = true
            skip_key = true
            value = "20"
        }
        "(no key.3)" = {
            order = 3
            required = true
            skip_key = true
            value = "10"
        }
        "(no key.4)" = {
            order = 4
            required = true
            skip_key = true
            value = "20"
        }
    }
}
```

### CALLING-STATION-ID
```
object CheckCommand "check_csi" {
    import "plugin-check-command"
    command = [ PluginDir + "/test-Calling-Station-Id-v2.pl" ]
    timeout = 1m
    arguments += {
        "-F" = {
            required = true
            value = " /var/log/radius1edu-radius.ON_CSI"
        }
        "-H" = {
            required = true
            value = "$host.vars.radius_ip$"
        }
    }
}
```

### CHARGEABLE-USER-IDENTITY
```
object CheckCommand "check_cui" {
    import "plugin-check-command"
    command = [ PluginDir + "/test-Chargeable-User-Identity.pl" ]
    arguments += {
        "-H" = {
            required = true
            value = "$host.vars.radius_ip$"
        }
        "-M" = {
            required = true
            value = "$service.vars.mac_address$"
        }
        "-P" = {
            required = true
            value = "1812"
        }
        "-S" = "$host.vars.mon_radius_secret$"
        "-p" = {
            required = true
            value = "$service.vars.testing_password$"
        }
        "-u" = {
            required = true
            value = "$service.vars.testing_id$"
        }
    }
}
```

### CVE-2017-9148
```
object CheckCommand "check_cve_2017_9148" {
    import "plugin-check-command"
    command = [ PluginDir + "/tls-resume-expl" ]
    arguments += {
        "(no key)" = {
            order = 1
            required = true
            skip_key = true
            value = "$service.vars.testing_id$"
        }
        "(no key.2)" = {
            order = 2
            required = true
            skip_key = true
            value = "$host.vars.radius_ip$"
        }
        "(no key.3)" = {
            order = 3
            required = true
            skip_key = true
            value = "$host.vars.mon_radius_secret$"
        }
        "(no key.4)" = {
            order = 4
            required = true
            skip_key = true
            value = "$service.vars.mac_address1$"
        }
        "(no key.5)" = {
            order = 5
            required = true
            skip_key = true
            value = "$service.vars.mac_address2$"
        }
    }
}
```

### FAKE-UID
```
object CheckCommand "check_fake_uid" {
    import "plugin-check-command"
    command = [ PluginDir + "/check-fake-id" ]
    arguments += {
        "-A" = {
            required = true
            value = "$service.vars.anon_id$"
        }
        "-H" = {
            required = true
            value = "$host.vars.radius_ip$"
        }
        "-M" = {
            required = true
            value = "$service.vars.mac_address$"
        }
        "-P" = {
            required = true
            value = "1812"
        }
        "-S" = {
            required = true
            value = "$host.vars.mon_radius_secret$"
        }
        "-e" = {
            required = true
            value = "PEAP"
        }
        "-m" = {
            required = true
            value = "WPA-EAP"
        }
        "-p" = {
            required = true
            value = "$service.vars.testing_password$"
        }
        "-t" = {
            required = true
            value = "50"
        }
        "-u" = {
            required = true
            value = "$service.vars.testing_id$"
        }
    }
}
```

### HOME-REALM-ALIVE
```
object CheckCommand "check_home_realm_alive" {
    import "plugin-check-command"
    command = [ PluginDir + "/home_realm_alive.sh" ]
    arguments += {
        "(no key)" = {
            order = 1
            required = true
            skip_key = true
            value = "$service.vars.realm$"
        }
        "(no key.2)" = {
            order = 2
            required = true
            skip_key = true
            value = "$service.vars.home_servers$"
        }
    }
}
```

### INSTITUTION-XML
```
object CheckCommand "check_institution_xml" {
    import "plugin-check-command"
    command = [ PluginDir + "/check_institution_xml.sh" ]
    arguments += {
        "(no key)" = {
            order = 1
            required = true
            skip_key = true
            value = "$host.vars.realm_aliases$"
        }
        "--sni" = {
            order = 6
            required = false
            set_if = "$service.vars.xml_https$"
        }
        "-H" = {
            order = 5
            required = true
            value = "$service.vars.xml_host$"
        }
        "-S" = {
            order = 4
            required = false
            set_if = "$service.vars.xml_https$"
        }
        "-s" = {
            order = 3
            required = true
            value = "inst_realm"
        }
        "-u" = {
            order = 2
            required = true
            value = "$service.vars.xml_url_part$"
        }
    }
}
```

### IPSEC
```
object CheckCommand "check_ipsec" {
    import "plugin-check-command"
    command = [ "/usr/local/bin/check_ipsec" ]
    timeout = 1m
    arguments += {
        "(no key)" = {
            order = 1
            required = true
            skip_key = true
            value = "$host.vars.radius_ip$"
        }
    }
}
```

### OPERATOR-NAME
```
object CheckCommand "check_operator_name" {
    import "plugin-check-command"
    command = [ PluginDir + "/test-Operator-Name.pl" ]
    arguments += {
        "-F" = {
            required = true
            value = "/var/log/radius1edu-radius.ON_CSI"
        }
        "-H" = {
            required = true
            value = "$host.vars.radius_ip$"
        }
        "-R" = {
            required = true
            value = "$host.vars.all_realms$"
        }
    }
}
```

### RADSEC

RADSEC command is configured twice - once for servers with IdP+SP role
and once for server with SP only role.

```
object CheckCommand "check_radsec" {
    import "plugin-check-command"
    command = [ "/usr/local/bin/check_radsec.pl" ]
    timeout = 1m
    arguments += {
        "-H" = {
            order = 1
            required = true
            value = "$host.vars.radius_ip$"
        }
    }
}
```

```
object CheckCommand "check_radsec_sp" {
    import "plugin-check-command"
    command = [ "/usr/local/bin/check_radsec.pl" ]
    timeout = 1m
    arguments += {
        "--SPonly" = {}
        "-H" = {
            order = 1
            required = true
            value = "$host.vars.radius_ip$"
        }
    }
}
```


### home realm / vistors realm
```
object CheckCommand "check_rad_eap" {
    import "plugin-check-command"
    command = [ PluginDir + "/rad_eap_test" ]
    timeout = 1m
    arguments += {
        "-H" = {
            required = true
            value = "$host.vars.radius_ip$"
        }
        "-M" = {
            required = true
            value = "$service.vars.mac_address$"
        }
        "-P" = {
            required = true
            value = "1812"
        }
        "-S" = {
            required = true
            value = "$host.vars.mon_radius_secret$"
        }
        "-e" = {
            required = true
            value = "PEAP"
        }
        "-i" = {
            required = false
            value = "$service.vars.info$"
        }
        "-m" = {
            required = true
            value = "WPA-EAP"
        }
        "-p" = {
            required = true
            value = "$service.vars.testing_password$"
        }
        "-t" = {
            required = true
            value = "50"
        }
        "-u" = {
            required = true
            value = "$service.vars.testing_id$"
        }
    }
}
```

### VCELKA-MAJA
```
object CheckCommand "check_vcelka_maja" {
    import "plugin-check-command"
    command = [ PluginDir + "/vcelka-maja" ]
    arguments += {
        "(no key)" = {
            order = 1
            required = true
            skip_key = true
            value = "test001@cesnet.cz"
        }
        "(no key.2)" = {
            order = 2
            required = true
            skip_key = true
            value = "password"      // password removed for being sensitive infomation
        }
        "(no key.3)" = {
            order = 3
            required = true
            skip_key = true
            value = "$host.vars.radius_ip$"
        }
        "(no key.4)" = {
            order = 4
            required = true
            skip_key = true
            value = "$host.vars.mon_radius_secret$"
        }
        "(no key.5)" = {
            order = 5
            required = true
            skip_key = true
            value = "$service.vars.realm$"
        }
        "(no key.6)" = {
            order = 6
            required = true
            skip_key = true
            value = "$service.vars.mac_address1$"
        }
        "(no key.7)" = {
            order = 7
            required = true
            skip_key = true
            value = "$service.vars.mac_address2$"
        }
    }
}
```

### VISITORS
```
object CheckCommand "check_visitors" {
    import "plugin-check-command"
    command = [ PluginDir + "/check_visitors.sh" ]
    arguments += {
        "(no key)" = {
            order = 1
            required = true
            skip_key = true
            value = "$host.name$"
        }
    }
}
```


## Notification templates

We only use notifications for services.
Only one notification template is used:

```
template Notification "generic notification" {
    command = "mail-service-notification"
    interval = 1d
    states = [ Critical, OK, Unknown, Warning ]
    types = [ Acknowledgement, Custom, Problem, Recovery ]
}
```

## Endpoints

![endpoints](https://github.com/CESNET/eduroam-icinga/blob/master/doc/endpoints.png "endpoints")

We defined two endpoints - one for czech top level RADIUS server and for for monitoring itself:

Monitoring endpoint:
```
object Endpoint "ermon2.cesnet.cz" {
    host = "ermon2.cesnet.cz"
    port = "5665"
    log_duration = 1d
}
```

Czech top level RADIUS server endpoint:
```
object Endpoint "radius1.eduroam.cz" {
    host = "radius1.eduroam.cz"
    port = "5665"
}
```

There is currently no way that this configuration can be exported or imported,
so this has to be done manually in the director.

## Zones

We defined two zones - one for czech top level RADIUS server and for for monitoring itself:

Monitoring zone:
```
object Zone "ermon2.cesnet.cz" {
    endpoints = [ "ermon2.cesnet.cz" ]
}
```

Czech top level RADIUS server zone:
```
object Zone "radius1.eduroam.cz" {
    parent = "ermon2.cesnet.cz"
    endpoints = [ "radius1.eduroam.cz" ]
}
```

There is currently no way that this configuration can be exported or imported,
so this has to be done manually in the director.

## Data fields

Data fields enable icinga objects to be to have custom variables.
These variables may be set using director.

![data fields](https://github.com/CESNET/eduroam-icinga/blob/master/doc/data_fields.png "data fields")

Our sync rules [datafields.json](https://github.com/CESNET/eduroam-icinga/blob/master/doc/example_config/director/datafields.json)
The import is not possible currently.

## Manually added hosts

The national top level RADIUS server needs to be added manually using director.
This host is not in our evidence.

The top level national RADIUS server represents a client in icinga cluster protocol.
Some of the tests must be ran on the client, because the monitoring server itself does not have data needed for the tests.
For more info see [tests](https://github.com/CESNET/eduroam-icinga/blob/master/doc/tests.md#remote-tests)

The host is added manualy in icingaweb2 director menu.
No special settings are set.

### Client setup

Client setup may be done using script provided in icingaweb2.
Download this script on client a run it.
It should do all the work and the master and the client should be able to communicate.

