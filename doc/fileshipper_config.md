# fileshipper
Fileshipper configuration is located in directory `/etc/icingaweb2/modules/fileshipper/`.
There is only one configuration file for the module itself, which is `/etc/icingaweb2/modules/fileshipper/directories.ini` (see [module configuration](https://github.com/CESNET/eduroam-icinga/blob/master/doc/icingaweb2_modules.md#configuration) for explanation).
The rest of the files in `/etc/icingaweb2/modules/fileshipper/` are plain icinga2 configuration files,
which are shipped to icinga2 when director configuration is deployed.

List of icinga2 plain config files:
```
/etc/icingaweb2/modules/fileshipper/static_config.conf
/etc/icingaweb2/modules/fileshipper/secrets.conf
/etc/icingaweb2/modules/fileshipper/mac_address.conf
/etc/icingaweb2/modules/fileshipper/dynamic_config.conf
```

## static configuration
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


## dynamic configuration
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
