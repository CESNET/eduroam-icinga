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

TODO paths

## configuration

TODO


