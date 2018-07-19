## icingaweb2 modules

For our setup two additional icingaweb2 modules are used:
- director
- fileshipper

### director ([module home](https://github.com/Icinga/icingaweb2-module-director))

This module enables configuration management through web browser.
The main functionality we use is synchronization from database sources.

This module is cloned directly from git repository. Revision used is `ef2d1983282bc18bb4b1a6829398404eecbb76c6`.

For installation see official [instructions](https://github.com/Icinga/icingaweb2-module-director/blob/master/doc/02-Installation.md)

### filehsipper ([module home](https://github.com/Icinga/icingaweb2-module-fileshipper))
This module extends the director module in certain ways. It enables director to synchronize
file formats XML, YAML, CSV, XSLX, JSON and plain icinga2 configuration.
We use this module ty synchronize plain icinga2 configuration because it cannot be done in director itself.
Our hand crafted configuration also is speeds up the whole sync-deploy process a lot.

This module is cloned directly from git repository. Revision used is `fd2c797eede60ae7875bb8a7ee24fd1a35dce338`.

For installation see official [instructions](https://github.com/Icinga/icingaweb2-module-fileshipper/blob/master/doc/02-Installation.md)

#### configuration

You need to create file `/etc/icingaweb2/modules/fileshipper/directories.ini` with contents:
```
[sync hand crafted configuration]
source = /etc/icingaweb2/modules/fileshipper
target = zones.d/director-global/service_apply_rules
```

This configuration defines where the source and target directories are. The source
directory contains hand crafted icinga2 configuration. On deploy it is shipped to the
target directory and deployed along with the director generated configuration.
