## permissions
All the users which can access icingaweb have same permissions and can actively schedule checks, ack problems and so on.
The problem is that an admin of any server can ack any service which belongs to server which he does not manage.
This could probably be solved by permission filters, but we do not consider this a big problem at the moment.

## deployments
When doing a manual deployment the administrator should check that the cron based deployment is not currently running or doing
deployment, so the deployments do not interfere with each other.
When we encountered this interference, is was not a huge problem, but is depends on precise timing.
If the administrator deploys new configuration right at the "incorrect" moment, for example when fileshipper dynamic configuration
is being generated, it could result in a some state, when a lot of services is missing.
When doing a manual deployment the administrator should always check that the current time is not same is cronjob run time.

### notification about deployment problems

When the deploy fails or there are warnings in the startup log, the administators should be notified about this.
This is done [here](https://github.com/CESNET/eduroam-icinga/blob/master/sync/main.sh#L55)
and [here](https://github.com/CESNET/eduroam-icinga/blob/master/sync/main.sh#L61).
Notifications about failed deploy sometimes contain just empty mail body because the information
if Icinga 2 started up successfully is not available in the database (see [this](https://github.com/CESNET/eduroam-icinga/blob/master/sync/main.sh#L42))
before deploy timer expires. It is not clear why this happens. Further debug is needed to resolve this issue.

## mixing realm types
When a server should handle different types of realms (eg. IdPSP and SP) at once, problems could arise.
This is due to director synchronization for hosts from multiple sources.
Custom host variable `type` must always have the the highest available value based on the priorities.
The priorities are set as IdPSP > SP.
There is an open [issue](https://github.com/Icinga/icingaweb2-module-director/issues/1636) for that.

