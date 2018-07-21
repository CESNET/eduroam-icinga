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
/etc/icinga2/conf.d/api-users.conf          - define director api user here
/etc/icinga2/conf.d/templates.conf          - define client service templates here, details below
TODO - nofitications?
/etc/icinga2/conf.d/services.conf           - define client services here, details below
/etc/icinga2/conf.d/dependencies.conf       - defined dependencies here, details below
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

TODO - add whole file?

TODO - explain what is client according to icinga2 terminology

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

TODO - add whole file?


#### Dependencies
Dependencies seare defined in `/etc/icinga2/conf.d/dependencies.conf`.
Configuration is commented and should be self-explanatory.
File contents:
```
/* definition of dependencies for monitored services */

// ========================================================================================================================
// ipsec

// dependency of ipsec on ping
apply Dependency "ipsec_ping" to Service {
  parent_service_name = "PING"
  disable_checks = true
  assign where host.vars.transport == "IPSEC" && service.name == "IPSEC"
}

// ========================================================================================================================
// radsec

// dependency of radsec na ping
apply Dependency "radsec_ping" to Service {
  parent_service_name = "PING"
  disable_checks = true
  assign where host.vars.transport == "RADSEC" && host.vars.type != "SP" && service.name == "RADSEC"
}

// dependency of radsec sp only on ping
apply Dependency "radsec_sp_ping" to Service {
  parent_service_name = "PING"
  disable_checks = true
  assign where host.vars.transport == "RADSEC" && host.vars.type == "SP" && service.name == "RADSEC"
}

// ========================================================================================================================
// home realm

// dependency of home realm on ping
apply Dependency "home_realm_ping" to Service {
  parent_service_name = "PING"
  disable_checks = true
  assign where service.vars.home_realm_check == 1
}

// ========================================================================================================================
// visitors' realms

// in current state icinga2 is not able to do OR between multiple 
// services which the child servervice should depend on
// for more see https://github.com/Icinga/icinga2/issues/1869
//
// for this purpose an aggerated check service HOME-REALM-ALIVE was made
// it represents state of all home servers with home users
// the service is critical only if none of the home servers cannot authenticate the user

// dependency of visitors' realms on home servers
apply Dependency "visitor_realms_home_servers" for (server in service.vars.home_servers) to Service {
  parent_host_name = server

  if(typeof(service.vars.home_servers) == Array) {      // multiple home servers
    parent_service_name = "HOME-REALM-ALIVE-" + service.vars.visitors_realm     // "virtual" service which represent states of all home servers
  }

  if(typeof(service.vars.home_servers) == String) {     // one home server
    parent_service_name = "@" + service.vars.visitors_realm                     // one home server only, so only one service
  }

  disable_checks = true
  assign where service.vars.home_realm_check == 0
}

// ========================================================================================================================
// visitors

// dependency of visitors on home realm
apply Dependency "visitors_home_realm" for (realm in host.vars.mon_realm) to Service {
    parent_service_name = "@" + realm
    disable_checks = true
    assign where service.name == "VISITORS" && host.vars.type != "SP" && get_service(host.name, "@" + realm) != null
}

// ========================================================================================================================
// big packet

// dependency of big_packet on radsec
apply Dependency "big_packet_radsec" to Service {
    parent_service_name = "RADSEC"
    disable_checks = true
    assign where host.vars.transport == "RADSEC" && host.vars.type != "SP" && service.name == "BIG-PACKET"
}

// dependency of big_packet on radsec sp only
apply Dependency "big_packet_radsec_sp_only" to Service {
    parent_service_name = "RADSEC"
    disable_checks = true
    assign where host.vars.transport == "RADSEC" && host.vars.type == "SP" && service.name == "BIG-PACKET"
}

// dependency of big_packet on ipsec
apply Dependency "big_packet_ipsec" to Service {
    parent_service_name = "IPSEC"
    disable_checks = true
    assign where host.vars.transport == "IPSEC" && service.name == "BIG-PACKET"
}

// dependency of big_packet on cesnet.cz@homeservers
// icinga2 cannot do an OR dependency between two (or multiple) services
// because of this, service HOME-REALM-ALIVE was implemented and is used here

apply Dependency "big_packet_cesnet.cz@radius1.cesnet.cz" to Service {
    parent_service_name = "HOME-REALM-ALIVE-cesnet.cz"
    parent_host_name = "radius1.cesnet.cz"
    disable_checks = true
    assign where service.name == "BIG-PACKET"
}

// dependency of big_packet on cesnet.cz@homeservers
apply Dependency "big_packet_cesnet.cz@radius2.cesnet.cz" to Service {
    parent_service_name = "HOME-REALM-ALIVE-cesnet.cz"
    parent_host_name = "radius2.cesnet.cz"
    disable_checks = true
    assign where service.name == "BIG-PACKET"
}

// ========================================================================================================================
// calling station id

// dependency of calling station id on ping
apply Dependency "calling_station_id_ping" to Service {
    parent_service_name = "PING"
    disable_checks = true
    assign where service.name == "CALLING-STATION-ID"
}

// ========================================================================================================================
// chargeable user identity

// dependency of chargeable user identity on home realm
apply Dependency "chargeable_user_identity_home_realm" for (realm in host.vars.mon_realm) to Service {
    parent_service_name = "@" + realm
    disable_checks = true
    assign where service.name == "CHARGEABLE-USER-IDENTITY" && host.vars.type != "SP"
}

// ========================================================================================================================
// cve-2017-9148

// dependency of cve on home realm
apply Dependency "cve_2017_9148_home_realm" for (realm in host.vars.mon_realm) to Service {
    parent_service_name = "@" + realm
    disable_checks = true
    assign where service.name == "CVE-2017-9148" && host.vars.type != "SP" && get_service(host.name, "@" + realm) != null
}

// ========================================================================================================================
// fake-uid

// dependency of fake uid on home realm
apply Dependency "fake_uid_home_realm" for (realm in host.vars.mon_realm) to Service {
    parent_service_name = "@" + realm
    disable_checks = true
    assign where service.name == "FAKE-UID" && host.vars.type != "SP"
}

// ========================================================================================================================
// operator name

// dependency of operator name on ping
apply Dependency "operator_name_ping" to Service {
    parent_service_name = "PING"
    disable_checks = true
    assign where service.name == "OPERATOR-NAME"
}

// ========================================================================================================================
// vcelka maja

// dependency of vcelka-maja on home relam
apply Dependency "vcelka_maja_home_realm" for (realm in host.vars.mon_realm) to Service {
    parent_service_name = "@" + realm
    disable_checks = true
    assign where service.name == "VCELKA-MAJA" && host.vars.type != "SP"
}

// ========================================================================================================================
// institution-xml

// dependency of institution-xml on ping
apply Dependency "institution_xml_ping" to Service {
    parent_service_name = "PING"
    disable_checks = true
    assign where match("INSTITUTION-XML*", service.name)
}
// ========================================================================================================================
```

TODO - add whole file (as link?)?

### fileshipper
Fileshipper configuration is located in directory `/etc/icingaweb2/modules/fileshipper/`.
There is only one configuration file for the module itself, which is `/etc/icingaweb2/modules/fileshipper/directories.ini` (see [above](https://github.com/CESNET/eduroam-icinga#configuration) for explanation).
The rest of the files in `/etc/icingaweb2/modules/fileshipper/` are plain icinga2 configuration files,
which are shipped to icinga2 when director configuration is deployed.

List of icinga2 plain config files:
```
/etc/icingaweb2/modules/fileshipper/static_config.conf
/etc/icingaweb2/modules/fileshipper/mac_address.conf
/etc/icingaweb2/modules/fileshipper/dynamic_config.conf
```

#### static configuration
Static configuration is not changed by any part of the data synchronation tools.
It should only be modified by hand a it should not be necessary.

`/etc/icingaweb2/modules/fileshipper/static_config.conf` contents:
```
/* --------------------------------------------------------------------------------------------------------- */
/* --------------------------------------------------------------------------------------------------------- */
// icinga2 static configuration for eduroam.cz
//
//
/* --------------------------------------------------------------------------------------------------------- */
/* --------------------------------------------------------------------------------------------------------- */

index = 0

for(realm in realms) {
  key = keys(realm)[0]                // get realm

  /* --------------------------------------------------------------------------------------------------------- */
  // institution-xml

  if(typeof(realm[key].home_servers) == Array && realm[key].xml_url != "undefined") {
    apply Service "INSTITUTION-XML-" + key use(realm, key) {
      import "institution xml template"

      vars.xml_url = realm[key].xml_url
      vars.temp = vars.xml_url.replace("https://", "").replace("http://", "")
      vars.xml_host = vars.temp.split("/")[0]

      vars.xml_url_part = vars.temp.substr(vars.temp.find("/"))

      if(match(vars.xml_url, "https://.*")) {
        vars.xml_https = 1
      }

      if(match(vars.xml_url, "http://.*")) {
        vars.xml_https = 0
      }

      assign where host.name == realm[key].home_servers[0]
    }
  }

  if(typeof(realm[key].home_servers) != Array && realm[key].xml_url != "undefined") {
    apply Service "INSTITUTION-XML-" + key use(realm, key) {
      import "institution xml template"

      vars.xml_url = realm[key].xml_url
      vars.temp = vars.xml_url.replace("https://", "").replace("http://", "")
      vars.xml_host = vars.temp.split("/")[0]

      vars.xml_url_part = vars.temp.substr(vars.temp.find("/"))

      if(match(vars.xml_url, "https://.*")) {
        vars.xml_https = 1
      }

      if(match(vars.xml_url, "http://.*")) {
        vars.xml_https = 0
      }

      assign where host.name == realm[key].home_servers
    }
  }
  /* --------------------------------------------------------------------------------------------------------- */
  // compromised users
  if(typeof(realm[key].home_servers) == Array) {
    apply Service "COMPROMISED-USERS-" + key use(realm, key) {
      import "compromised users template"
      vars.realm = key
      assign where host.name == realm[key].home_servers[0]
    }
  }

  if(typeof(realm[key].home_servers) != Array) {
    apply Service "COMPROMISED-USERS-" + key use(realm, key) {
      import "compromised users template"
      vars.realm = key
      assign where host.name == realm[key].home_servers
    }
  }

  /* --------------------------------------------------------------------------------------------------------- */
  // concurrent inst
  if(typeof(realm[key].home_servers) == Array) {
    apply Service "CONCURRENT-INST-" + key use(realm, key) {
      import "concurrent inst template"
      vars.realm = key
      assign where host.name == realm[key].home_servers[0]
    }
  }

  if(typeof(realm[key].home_servers) != Array) {
    apply Service "CONCURRENT-INST-" + key use(realm, key) {
      import "concurrent inst template"
      vars.realm = key
      assign where host.name == realm[key].home_servers
    }
  }
  /* --------------------------------------------------------------------------------------------------------- */

  // skip if visitor's realm does not have testing user
  // or no home server exists where testing user should be authenticated
  if(realm[key].testing_id == "undefined" || realm[key].home_servers == "undefined") {
    continue
  }

  /* --------------------------------------------------------------------------------------------------------- */
  // home realm alive
  if(typeof(realm[key].home_servers) == Array) {
    for(home_server in realm[key].home_servers) {
      apply Service "HOME-REALM-ALIVE-" + key use(realm, home_server, key) {

        import "home realm alive template"
        vars.home_servers = realm[key].home_servers
        vars.realm = key
        assign where host.name == home_server
      }
    }
  }
  /* --------------------------------------------------------------------------------------------------------- */

  for(radius in radius_servers) {
    server = keys(radius)[0]

    /* --------------------------------------------------------------------------------------------------------- */
    // check_rad_eap / matrix of visits
    apply Service "@" + key use(realm, server, radius, index, key) {

      display_name = "@" + key
      check_command = "check_rad_eap"
      vars.home_servers = realm[key].home_servers           // visitor's home servers
      vars.testing_id = realm[key].testing_id               // visitor's testind id
      vars.testing_password = realm[key].testing_password   // visitor's testing password
      vars.mac_address = mac_address[index]
      vars.visitors_realm = key
      groups = [ key ]

      if((typeof(realm[key].home_servers) == Array && server in realm[key].home_servers) || (typeof(realm[key].home_servers) == String && server == realm[key].home_servers)) {
        vars.home_realm_check = 1
        check_interval = 300
        retry_interval = 600
      }
      if((typeof(realm[key].home_servers) == Array && server !in realm[key].home_servers) || (typeof(realm[key].home_servers) == String && server != realm[key].home_servers)) {
        vars.home_realm_check = 0
        check_interval = 10800
        retry_interval = 7200
      }

      max_check_attempts = 3

      assign where host.name == server
    }
    index += 1
    /* --------------------------------------------------------------------------------------------------------- */

    // key in not matching the first monitored realm of server
    if(key != radius[server][0]) {              // suitable for services which should be applied only once to every server in case there are multiple monitored realms on one server
      continue
    }

    /* --------------------------------------------------------------------------------------------------------- */
    // chargeable user identity
    apply Service "CHARGEABLE-USER-IDENTITY" use(realm, server, radius, index, key) {

      import "chargeable user identity template"
      vars.testing_id = realm[key].testing_id
      vars.testing_password = realm[key].testing_password
      vars.mac_address = mac_address[index]

      assign where host.name == server
    }
    index += 1
    /* --------------------------------------------------------------------------------------------------------- */
    // fake uid
    apply Service "FAKE-UID" use(realm, radius, index, server, key) {

      import "fake uid template"
      vars.testing_id = realm[key].testing_id
      vars.testing_password = realm[key].testing_password
      vars.mac_address = mac_address[index]

      assign where host.name == server && host.vars.type != "SP"
    }
    index += 1
    /* --------------------------------------------------------------------------------------------------------- */
    // big packet
    // TODO - tohle je nejake rozbite
    apply Service "BIG-PACKET" use(realm, radius, index, server, key) {

      import "big packet template"
      vars.testing_id = "big-test@cesnet.cz"
      vars.testing_password = "password"
      vars.mac_address = mac_address[index]

      assign where host.name == server && host.vars.type != "SP"
    }
    index += 1
    /* --------------------------------------------------------------------------------------------------------- */
    // vcelka maja
    apply Service "VCELKA-MAJA" use(realm, radius, index, server, key) {

      import "vcelka maja template"

      vars.testing_id = realm[key].testing_id
      vars.testing_password = realm[key].testing_password
      vars.mac_address1 = mac_address[index]
      vars.mac_address2 = mac_address[index + 1]
      vars.realm = host.vars.mon_realm[0]       // TODO ?

      assign where host.name == server && host.vars.type != "SP"
    }
    index += 2
    /* --------------------------------------------------------------------------------------------------------- */
  }
}
```

The second part of the static configuration is file `/etc/icingaweb2/modules/fileshipper/mac_address.conf`
This file only exists to ease assignment of mac address variables to services.
The file contains 65536 hex strings in range from `70:6f:6c:69:00:00` to `70:6f:6c:69:ff:ff`.

`/etc/icingaweb2/modules/fileshipper/mac_address.conf` contents:
```
const mac_address = [
"70:6f:6c:69:00:00",
"70:6f:6c:69:00:01",
"70:6f:6c:69:00:02",
...
```

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
Variable `home_servers` is a string if there is only one home server.
If there are multiple home servers variable `home_servers` is an array.

Sample of data from file:
```
const realms = [
	{ "cesnet.cz" =   { testing_id = "user@cesnet.cz",   testing_password = "password", xml_url = "http://eduroam.cesnet.cz/institution.xml",       home_servers = ["radius1.cesnet.cz", "radius2.cesnet.cz", ] } },
	{ "fel.cvut.cz" = { testing_id = "user@fel.cvut.cz", testing_password = "password", xml_url = "http://eduroam.feld.cvut.cz/institution.xml",    home_servers = ["reu5.feld.cvut.cz", "radius.felk.cvut.cz", ] } },
	{ "tul.cz" =      { testing_id = "user@tul.cz",      testing_password = "password", xml_url = "http://eduroam.tul.cz/institution.xml",          home_servers = ["radius1.tul.cz", "radius2.tul.cz", ] } },
	{ "faf.cuni.cz" = { testing_id = "user@faf.cuni.cz", testing_password = "password", xml_url = "http://www.faf.cuni.cz/eduroam/institution.xml", home_servers = ["radius1.hknet.cz", "radius2.hknet.cz", ] } },
	{ "prf.cuni.cz" = { testing_id = "user@prf.cuni.cz", testing_password = "password", xml_url = "http://eduroam.prf.cuni.cz/institution.xml",     home_servers = "eduroam.prf.cuni.cz",  } },
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

- director
- plain config in /etc/icinga2
- client config
- fileshipper

