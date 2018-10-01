# clients' purpose

Some of the tests cannot be examined at he monitoring server, 
bacause is has no direct connection to the infrastructure of the servers, in only has acess to all the servers as an wireless access point.
This is where clients can help. Icinga2 enables distributed setup, where some tests can be run on specific machines.
Some specific tests are run at czech top level RADIUS server, where all other organization servers are connected.

## data synchronization

Data can be synchronized automatically, but this has a drawback that a lot of configuration is synchronized.
Since the configuration is stable and there was no need to synchronize all relevant parts of configuration from master
to clients, we decided to disable automatic configuration synchronization.
The configuration is transferred manually and it could be done just once.

The commands configured on the master node should be copied to the client to:

```
/var/lib/icinga2/api/zones/top.level.eduroam.radius.tld/director/commands.conf
```

The advantage of this solution is that the top level RADIUS server has only the command definitions configured locally.

## configuration

Initial configuration is done using the setup script from [director](https://github.com/CESNET/eduroam-icinga/blob/master/doc/director_config.md#client-setup).
After this setup, the client should be almost fully set up.

Configuration synchronization is disabled in `/etc/icinga2/features-available/api.conf` by:
```
accept_config = false
```

The notifications on the client are disabled.
Just the monitoring server itself should notify the administrators about service problems.
This can be done by:
```
icinga2 feature disable notification
```

In case there are multiple servers which use the same IP address/hostname and some high availability
solution is used, it must be somehow assured, that icinga2 is running only on the active node.
