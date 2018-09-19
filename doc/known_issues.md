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

