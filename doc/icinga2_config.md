## icinga2 configuration

The icinga2 configuration which is applied with director deployment is located in several locations:
- `/etc/icinga2/`
- `/etc/icingaweb2/modules/fileshipper/`
- icingaweb2 - director
- (client configuration [it actually does not affect deployment, but only client tests])

### icinga2

All the configration files in `/etc/icinga2/`:
```
/etc/icinga2/conf.d/api-users.conf
/etc/icinga2/conf.d/satellite.conf
/etc/icinga2/conf.d/downtimes.conf
/etc/icinga2/conf.d/hosts.conf
/etc/icinga2/conf.d/users.conf
/etc/icinga2/conf.d/templates.conf
/etc/icinga2/conf.d/app.conf
/etc/icinga2/conf.d/notifications.conf
/etc/icinga2/conf.d/commands.conf
/etc/icinga2/conf.d/services.conf
/etc/icinga2/conf.d/groups.conf
/etc/icinga2/conf.d/timeperiods.conf
/etc/icinga2/conf.d/apt.conf
/etc/icinga2/conf.d/dependencies.conf
/etc/icinga2/zones.d/README
/etc/icinga2/repository.d/README
/etc/icinga2/icinga2.conf
/etc/icinga2/zones.conf
/etc/icinga2/init.conf
/etc/icinga2/features-available/debuglog.conf
/etc/icinga2/features-available/mainlog.conf
/etc/icinga2/features-available/opentsdb.conf
/etc/icinga2/features-available/command.conf
/etc/icinga2/features-available/graphite.conf
/etc/icinga2/features-available/syslog.conf
/etc/icinga2/features-available/influxdb.conf
/etc/icinga2/features-available/api.conf
/etc/icinga2/features-available/compatlog.conf
/etc/icinga2/features-available/elasticsearch.conf
/etc/icinga2/features-available/perfdata.conf
/etc/icinga2/features-available/checker.conf
/etc/icinga2/features-available/gelf.conf
/etc/icinga2/features-available/livestatus.conf
/etc/icinga2/features-available/notification.conf
/etc/icinga2/features-available/statusdata.conf
/etc/icinga2/features-available/ido-mysql.conf
/etc/icinga2/constants.conf
/etc/icinga2/scripts/mail-service-notification.sh
/etc/icinga2/scripts/mail-host-notification.sh
```

From all these files, these are the important ones which should be modified:
```
/etc/icinga2/conf.d/api-users.conf                  - define director api user here
/etc/icinga2/conf.d/templates.conf                  - define client service templates here, details below
/etc/icinga2/conf.d/notification.conf               - define notifications here, details below
/etc/icinga2/conf.d/services.conf                   - define client services here, details below
/etc/icinga2/conf.d/dependencies.conf               - define dependencies here, details below
/etc/icinga2/conf.d/groups.conf                     - define service groups here, details below
/etc/icinga2/conf.d/commands.conf                   - modify mail notification here, details below
/etc/icinga2/scripts/mail-service-notification.sh   - modify service mail notification script, details below
```

#### Templates
Client service templates are defined in `/etc/icinga2/conf.d/templates.conf`.
Additional file contents:
```
template Service "ipsec template" {
    check_command = "check_ipsec"
    max_check_attempts = "10"
    check_interval = 5m
    retry_interval = 1m
    enable_notifications = true
    enable_flapping = true
    command_endpoint = "radius1.eduroam.cz"
}

template Service "radsec template" {
    check_command = "check_radsec"
    max_check_attempts = "10"
    check_interval = 5m
    retry_interval = 1m
    enable_notifications = true
    enable_flapping = true
    command_endpoint = "radius1.eduroam.cz"
}

template Service "radsec_sp_only template" {
    check_command = "check_radsec_sp"
    max_check_attempts = "10"
    check_interval = 5m
    retry_interval = 1m
    enable_notifications = true
    enable_flapping = true
    command_endpoint = "radius1.eduroam.cz"
}

template Service "calling station id template" {
    check_command = "check_csi"
    max_check_attempts = "3"
    check_interval = 1d
    retry_interval = 12h
    enable_notifications = true
    enable_flapping = true
    command_endpoint = "radius1.eduroam.cz"
}

template Service "operator name template" {
    check_command = "check_operator_name"
    max_check_attempts = "3"
    check_interval = 1d
    retry_interval = 12h
    enable_notifications = true
    enable_flapping = true
    command_endpoint = "radius1.eduroam.cz"
}

```

`/etc/icingaweb2/modules/icinga2/templates.conf` contents [here](https://github.com/CESNET/eduroam-icinga/blob/master/doc/example_config/icinga2/templates.conf)

In icinga cluster terminology the client is an icinga2 node, which has only one parent node.
A client node will either run its own configured checks or receive command execution events from the parent node.
We chose scenario when the client only recieves commdna execution events from the parent node.

[Official documentation](https://www.icinga.com/docs/icinga2/latest/doc/06-distributed-monitoring/) on this topic.


#### Notifications
Notifications are defined in `/etc/icinga2/conf.d/notifications.conf`.
Notifications are only setup for services, because we use dummy checks for hosts.

No notifications will be sent unless notification feature is enabled.

Additional file contents:
```
apply Notification "Send Mails for Services to their contact groups" to Service {
  import "generic notification"
  user_groups = [ host.name ]
  assign where host.vars.type
}
```

`/etc/icingaweb2/modules/icinga2/notifications.conf` contents [here](https://github.com/CESNET/eduroam-icinga/blob/master/doc/example_config/icinga2/notifications.conf)


#### Services
Some of client services are defined in `/etc/icinga2/conf.d/services.conf`.
Additional file contents:
```
apply Service "IPSEC" {
    import "ipsec template"
    assign where host.vars.transport == "IPSEC"
}

apply Service "RADSEC" {
    import "radsec template"
    assign where host.vars.transport == "RADSEC" && host.vars.type != "SP"
}

apply Service "RADSEC" {
    import "radsec_sp_only template"
    assign where host.vars.transport == "RADSEC" && host.vars.type == "SP"
}

apply Service "CALLING-STATION-ID" {
    import "calling station id template"
    assign where host.vars.transport && host.vars.transport != "undefined"
}

apply Service "OPERATOR-NAME" {

  import "operator name template"
  assign where host.vars.transport && host.vars.transport != "undefined"
}
```

`/etc/icingaweb2/modules/icinga2/services.conf` contents [here](https://github.com/CESNET/eduroam-icinga/blob/master/doc/example_config/icinga2/services.conf)


#### Dependencies
Dependencies are defined in `/etc/icinga2/conf.d/dependencies.conf`.
Configuration is commented and should be self-explanatory.

TODO - add whole file

#### Groups
Service groups are defined in `/etc/icinga2/conf.d/groups.conf`.
Additional file contents:

```
object ServiceGroup "CONCURRENT-INST" {
  display_name = "CONCURRENT-INST"
}

object ServiceGroup "RADSEC" {
  display_name = "RADSEC"
}

object ServiceGroup "IPSEC" {
  display_name = "IPSEC"
}

object ServiceGroup "VCELKA-MAJA" {
  display_name = "VCELKA-MAJA"
}

object ServiceGroup "HOME-REALM-ALIVE" {
  display_name = "HOME-REALM-ALIVE"
}

object ServiceGroup "CALLING-STATION-ID" {
  display_name = "CALLING-STATION-ID"
}

object ServiceGroup "CHARGEABLE-USER-IDENTITY" {
  display_name = "CHARGEABLE-USER-IDENTITY"
}

object ServiceGroup "FAKE-UID" {
  display_name = "FAKE-UID"
}

object ServiceGroup "BIG-PACKET" {
  display_name = "BIG-PACKET"
}

object ServiceGroup "COMPROMISED-USERS" {
  display_name = "COMPROMISED-USERS"
}

object ServiceGroup "OPERATOR-NAME" {
  display_name = "OPERATOR-NAME"
}

object ServiceGroup "INSTITUTION-XML" {
  display_name = "INSTITUTION-XML"
}

object ServiceGroup "CVE-2017-9148" {
  display_name = "CVE-2017-9148"
}
```

TODO - add whole file

#### Commands
We modified default configuration for our mail notifications. To do this, part of `/etc/icinga2/conf.d/commands.conf` needs to be modified:

```
object NotificationCommand "mail-service-notification" {
  command = [ SysconfDir + "/icinga2/scripts/mail-service-notification.sh" ]

  arguments += {
    "-4" = "$notification_address$"
    "-6" = "$notification_address6$"
    "-b" = "$notification_author$"
    "-c" = "$notification_comment$"
    "-d" = {
      required = true
      value = "$notification_date$"
    }
    "-e" = {
      required = true
      value = "$notification_servicename$"
    }
    "-f" = {
      value = "$notification_from$"
      description = "Set from address. Requires GNU mailutils (Debian/Ubuntu) or mailx (RHEL/SUSE)"
    }
    "-i" = "$notification_icingaweb2url$"
    "-k" = "$notification_docurl$"
    "-l" = {
      required = true
      value = "$notification_hostname$"
    }
    "-n" = {
      required = true
      value = "$notification_hostdisplayname$"
    }
    "-o" = {
      required = true
      value = "$notification_serviceoutput$"
    }
    "-r" = {
      required = true
      value = "$notification_useremail$"
    }
    "-s" = {
      required = true
      value = "$notification_servicestate$"
    }
    "-t" = {
      required = true
      value = "$notification_type$"
    }
    "-u" = {
      required = true
      value = "$notification_servicedisplayname$"
    }
    "-v" = "$notification_logtosyslog$"
  }

  vars += {
    //notification_address = "$address$"
    notification_address6 = "$address6$"
    notification_author = "$notification.author$"
    notification_comment = "$notification.comment$"
    notification_type = "$notification.type$"
    notification_date = "$icinga.long_date_time$"
    notification_hostname = "$host.name$"
    notification_hostdisplayname = "$host.display_name$"
    notification_servicename = "$service.name$"
    notification_serviceoutput = "$service.output$"
    notification_servicestate = "$service.state$"
    notification_useremail = "$user.email$"
    notification_servicedisplayname = "$service.display_name$"
    notification_icingaweb2url = "https://" + NodeName
    notification_docurl = "$service.vars.doc_url$"
    notification_from = "nagios@" + NodeName
  }
}
```

`/etc/icingaweb2/modules/icinga2/commands.conf` contents [here](https://github.com/CESNET/eduroam-icinga/blob/master/doc/example_config/icinga2/commands.conf)

The script which creates notifications must me modified too.
`/etc/icinga2/scripts/mail-service-notification.sh` contents [here](https://github.com/CESNET/eduroam-icinga/blob/master/doc/example_config/mail-service-notification.sh)


### fileshipper
Fileshipper configuration is located in directory `/etc/icingaweb2/modules/fileshipper/`.
There is only one configuration file for the module itself, which is `/etc/icingaweb2/modules/fileshipper/directories.ini` (see [above](https://github.com/CESNET/eduroam-icinga#configuration) for explanation).
The rest of the files in `/etc/icingaweb2/modules/fileshipper/` are plain icinga2 configuration files,
which are shipped to icinga2 when director configuration is deployed.

List of icinga2 plain config files:
```
/etc/icingaweb2/modules/fileshipper/static_config.conf
/etc/icingaweb2/modules/fileshipper/secrets.conf
/etc/icingaweb2/modules/fileshipper/mac_address.conf
/etc/icingaweb2/modules/fileshipper/dynamic_config.conf
```

#### static configuration
Static configuration is not changed by any part of the data synchronation tools.
It should only be modified by hand a it should not be necessary.

`/etc/icingaweb2/modules/fileshipper/static_config.conf` contents [here](https://github.com/CESNET/eduroam-icinga/blob/master/doc/example_config/fileshipper/static_config.conf)


The second part of the static configuration is file `/etc/icingaweb2/modules/fileshipper/mac_address.conf`
This file only exists to ease assignment of mac address variables to services.
The file contains 65536 hex strings in range from `70:6f:6c:69:00:00` to `70:6f:6c:69:ff:ff`.

`/etc/icingaweb2/modules/fileshipper/mac_address.conf` contents [here](https://github.com/CESNET/eduroam-icinga/blob/master/doc/example_config/fileshipper/mac_address.conf)


The third part of the static configuration is file `/etc/icingaweb2/modules/fileshipper/secrets.conf`
This file contains sensitive data, so the contents of the file are not part of this repository.
The file contains definition of variable `big_packet_testing_password`.


#### dynamic configuration
Dynamic configuration is created when source of the data changes somehow.
In our specific case it is created by https://github.com/CESNET/eduroam-icinga/blob/master/sync/ldap_sync.js.

The configration only contains two variables which are used in `/etc/icingaweb2/modules/fileshipper/static_config.conf`.

Variables in `/etc/icingaweb2/modules/fileshipper/dynanic_config.conf` have the following structure.

Variable `realms` is an array of objects. Each object has a dynamic key which is its realm.
The value of the key is an object with keys:
- `testing_id`
- `testing_password`
- `xml_url`
- `home_servers`

All values of these keys except `home_servers` are strings.
Variable `home_servers` is always an array even if there is only one server.

Sample of data from file:
```
const realms = [
	{ "cesnet.cz" =   { testing_id = "user@cesnet.cz",   testing_password = "password", xml_url = "http://eduroam.cesnet.cz/institution.xml",       home_servers = ["radius1.cesnet.cz", "radius2.cesnet.cz", ] } },
	{ "fel.cvut.cz" = { testing_id = "user@fel.cvut.cz", testing_password = "password", xml_url = "http://eduroam.feld.cvut.cz/institution.xml",    home_servers = ["reu5.feld.cvut.cz", "radius.felk.cvut.cz", ] } },
	{ "tul.cz" =      { testing_id = "user@tul.cz",      testing_password = "password", xml_url = "http://eduroam.tul.cz/institution.xml",          home_servers = ["radius1.tul.cz", "radius2.tul.cz", ] } },
	{ "faf.cuni.cz" = { testing_id = "user@faf.cuni.cz", testing_password = "password", xml_url = "http://www.faf.cuni.cz/eduroam/institution.xml", home_servers = ["radius1.hknet.cz", "radius2.hknet.cz", ] } },
	{ "prf.cuni.cz" = { testing_id = "user@prf.cuni.cz", testing_password = "password", xml_url = "http://eduroam.prf.cuni.cz/institution.xml",     home_servers = [ "eduroam.prf.cuni.cz" ]  } },
    .....
```

Variable `radius_servers` is an array of objects. Each object has a dynamic key which is server dns name.
The value of each key is an array of realms, for which the server authenticates users.

Sample of data from file:
```
const radius_servers = [
{ "radius1.tul.cz" = [ "tul.cz", ] },
{ "radius2.tul.cz" = [ "tul.cz", ] },
{ "radius.zcu.cz" = [ "zcu.cz", ] },
{ "radius2.zcu.cz" = [ "zcu.cz", ] },
{ "radius1.osu.cz" = [ "osu.cz", ] },
{ "radius2.osu.cz" = [ "osu.cz", ] },
{ "radius.sssvt.cz" = [ "sssvt.cz", ] },
{ "radius1.hknet.cz" = [ "faf.cuni.cz", "uhk.cz", ] },
{ "radius2.hknet.cz" = [ "faf.cuni.cz", "uhk.cz", ] },
....
```

This structure has been chosen for easier and cleaner implementation of static configuration part.

You should create your own script, which creates this file according to the rules mentioned above.

This file contains sensitive data, so the contents of the file are not part of this repository.

- director
- plain config in /etc/icinga2
- client config
- fileshipper

