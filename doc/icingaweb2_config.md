# icingaweb2 configuration

This summarizes whole icingaweb2 configuration.
A lot of configuration is also done in icingaweb2, but that configuration is part of [director](https://github.com/CESNET/eduroam-icinga/blob/master/doc/director_config.md).

## roles

Icingaweb2 enables administrators to setup roles to determine what users can do.
For more information about this, see [official documentation](https://www.icinga.com/docs/icingaweb2/latest/doc/06-Security/#security-roles).
Roles are defined in `/etc/icingaweb2/roles.ini`

We made our configuration of roles simple:
- There is global admin which is authenticated locally. Webserver configuration actually prevents this user from logging in,
- There are more global admins from CESNET which can log in. Usernames match `REMOTE_USER` variable set by shibboleth.
- Everyone else has permissions to view everything in module monitoring and to work with services.

Our roles file:
```
[Administrators]
users = "admin"
permissions = "*"
groups = "Administrators"

[Admins]
users = "machv@cesnet.cz, semik@cesnet.cz, dans@cesnet.cz"
permissions = "*"

[realm_admins]
users = "*"
permissions = "module/monitoring, monitoring/command/schedule-check, monitoring/command/acknowledge-problem, monitoring/command/remove-acknowledgement, monitoring/command/comment/*, monitoring/command/downtime/*"
```

## protected variables

Some of our services contain custom variables with sensitive data.
We decided that we want to protect all sensitive data, because everyone who is able to log in to icingaweb2 is able to see any service.
Configuration is done in `/etc/icingaweb2/modules/monitoring/config.ini`

The configuration is:
```
[security]
protected_customvars = "*pw*,*pass*,community,*secret*"
```

All variables' names that match these definitions will be masked in icingaweb2.

## resources

These are several resources set up:
- director database
- icinga IDO database
- icingaweb2 database
- database for data synchronization

All these database resoures us local mysql database server.

## authentication

There are two authentication user backends set up. The first one is for local users. 
This authentication backend is actually not usable because of webserver setup.

The second user backend is set as External.
External user backends are based on REMOTE\_USER environment variable. 
If the request to icingaweb2 provide this variable, user can access it with this type of authentication set up.
The user backend itself does not handle any rules or restrictions for users.

## enabled modules

List of enabled modules:
- director
- fileshipper
- monitoring

## logging

Icingaweb2 logging type is set to file.
Logging level is set to Error.
File path is set to `/var/log/icingaweb2/icingaweb2.log`.

## custom dashboards

In our setup we decided that it would be nice to have custom dashboard for every realm administator.
This is done by [dashboard.sh](https://github.com/CESNET/eduroam-icinga/blob/master/sync/dashboard.sh) within the synchronization process.
Created dashboards are working fine but there still were default dashroard which were displayed as default. To get rid of these
(their information value did not seem valuable to us) some parts of icingaweb2 code needed to be commented out.
These [lines](https://github.com/Icinga/icingaweb2/blob/master/modules/monitoring/configuration.php#L290-L369) need to be commented out.
Using this approach means that anytime the icingaweb2 package is upgraded this breaks down and default dashboards will be displayed again.

Use of custom dashboards is totally optional.
