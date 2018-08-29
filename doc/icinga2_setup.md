## icinga2 setup
Icinga2 is set up on server ermon2.cesnet.cz. The server is running Debian stretch (9.4).
Icinga2 has been installed from official icinga2 package repositories ([documentation](https://www.icinga.com/docs/icinga2/latest/doc/02-getting-started/#package-repositories)).
To add package repositories do:

```
# wget -O - https://packages.icinga.com/icinga.key | apt-key add -
# echo 'deb https://packages.icinga.com/debian icinga-stretch main' >/etc/apt/sources.list.d/icinga.list
# apt-get update
# apt-get install icinga2
```

Be aware, that during installation some of icinga2 features are automatically enabled.
You can view enabled features by:
```
icinga2 feature list
```

We suggest that you turn off notifications before your icinga2 is fully set up and configured properly.
You can do that by:
```
icinga2 feature disable notification
```

These specific versions of packages are used and work without problems:
```
icinga2                              2.8.4-1.stretch
icinga2-bin                          2.8.4-1.stretch
icinga2-common                       2.8.4-1.stretch
icinga2-doc                          2.8.4-1.stretch
icinga2-ido-mysql                    2.8.4-1.stretch
icingacli                            2.5.3-1.stretch
icingaweb2                           2.5.3-1.stretch
icingaweb2-common                    2.5.3-1.stretch
icingaweb2-module-doc                2.5.3-1.stretch
icingaweb2-module-monitoring         2.5.3-1.stretch
libicinga2                           2.8.4-1.stretch
php-icinga                           2.5.3-1.stretch
```

### Package versions

We noticed, that in icinga-users mailing list several people complained about errors when
using newest icinga2 packages from official icinga repositories.
Although we did not encouner any problems, we decided to mark all related packages as held.
This ensured that when upgrading packages, these will stay on currently installed version.
Marking packages for hold is done by:
```
for i in $(dpkg -l | grep icinga | awk '{ print $2 }'); do apt-mark hold $i; done
```

List of held packages can be verified by:
```
apt-mark showhold
```

Held packages should be:
```
icinga2
icinga2-bin
icinga2-common
icinga2-doc
icinga2-ido-mysql
icingacli
icingaweb2
icingaweb2-common
icingaweb2-module-doc
icingaweb2-module-monitoring
libicinga2
php-icinga
```

In case no futher complaints appear in icinga-users list after several days since the updates are
available, it should be safe to install these updates.


Unhold of the packages can be done by:
```
for i in $(dpkg -l | grep icinga | awk '{ print $2 }'); do apt-mark unhold $i; done
```

After unholding the packages you can upgrade them and put them on hold again.

### icingaweb2
For simple interaction with icinga2 through web browser, icingaweb2 is needed. This package
has been also taken from official icinga2 package repositories (see [icinga2 setup](#icinga2-setup)).

To use icingaweb2 with icinga2 a database is also needed. Icingaweb2 supports mysql and postgresql.
Mysql has been chosen as database for our setup for historical reasons and compatilibity with other tools.

Mysql has been installed from official debian repositories. Mysql setup is not covered in this guide.
No specific settings have been set for mysql.

For icingaweb2 icinga2 feature IDO needs to be enabled. You can do this by:
```
icinga2 feature enable ido-mysql
```

#### Webserver configuration

Apache is used as webserver because of it's support with shibboleth module.

By default icingaweb2 is located at url /icingaweb2.
With the configuration below, icingaweb2 is available at url /.

```
<VirtualHost *:80>
        ServerAdmin machv@cesnet.cz
        ServerName ermon2.cesnet.cz
        ServerAlias ermon.cesnet.cz
        Redirect permanent "/" "https://ermon2.cesnet.cz/"
</VirtualHost>

<IfModule mod_ssl.c>
        <VirtualHost _default_:443>
                ServerAdmin machv@cesnet.cz
                ServerName ermon2.cesnet.cz
                ServerAlias ermon.cesnet.cz
                DocumentRoot "/usr/share/icingaweb2/public"

                ErrorLog ${APACHE_LOG_DIR}/ermon_error.log
                CustomLog ${APACHE_LOG_DIR}/ermon_access.log combined
                SSLEngine on

                SSLProtocol All -SSLv2 -SSLv3
                SSLCipherSuite EECDH+AESGCM:EDH+AESGCM:AES256+EECDH:AES256+EDH
                SSLCertificateFile      /etc/ssl/certs/ermon.cesnet.cz.crt.pem
                SSLCertificateKeyFile /etc/ssl/private/ermon.cesnet.cz.key.pem

                BrowserMatch "MSIE [2-6]" \
                                nokeepalive ssl-unclean-shutdown \
                                downgrade-1.0 force-response-1.0
                # MSIE 7 and newer should be able to use keepalive
                BrowserMatch "MSIE [17-9]" ssl-unclean-shutdown

                # HSTS
                Header always set Strict-Transport-Security "max-age=63072000; includeSubdomains;"

                ## PHP
                #<FilesMatch "\.(cgi|shtml|phtml|php)$">
                #               SSLOptions +StdEnvVars
                #</FilesMatch>

                <Directory "/usr/share/icingaweb2/public">
                    Options SymLinksIfOwnerMatch
                    AllowOverride None

                    SetEnv ICINGAWEB_CONFIGDIR "/etc/icingaweb2"

                    EnableSendfile Off

                    <IfModule mod_rewrite.c>
                        RewriteEngine on
                        RewriteBase /
                        RewriteCond %{REQUEST_FILENAME} -s [OR]
                        RewriteCond %{REQUEST_FILENAME} -l [OR]
                        RewriteCond %{REQUEST_FILENAME} -d
                        RewriteRule ^.*$ - [NC,L]
                        RewriteRule ^.*$ index.php [NC,L]
                    </IfModule>

                    <IfModule !mod_rewrite.c>
                        DirectoryIndex error_norewrite.html
                        ErrorDocument 404 /error_norewrite.html
                    </IfModule>
                </Directory>

                # external auth
                <Location />
                  AuthType shibboleth

                  <RequireAll>
                    Require shibboleth
                    ShibRequestSetting requireSession 1
                    Require shib-attr perunUniqueGroupName cesnet:members eduroam:eduroam-admin
                  </RequireAll>
                </Location>
        </VirtualHost>
</IfModule>

```

Sbibboleth module is used to handle authentication to icingaweb2.
Sbibboleth setup is not covered in this guide.

It is required that only specific users can access icingaweb2.
This is done by part of the configuration also mentioned above:
```
                  <RequireAll>
                    Require shibboleth
                    ShibRequestSetting requireSession 1
                    Require shib-attr perunUniqueGroupName cesnet:members eduroam:eduroam-admin einfra:eduroamAdmins
                  </RequireAll>
```

This configuration sets up authorization in a way, that only users which provide sbibboleth attribute
perunUniqueGroupName with value `cesnet:members`, `eduroam:eduroam-admin` or `einfra:eduroamAdmins` are allowed in.

#### icingaweb2 setup

The setup is done by pointing the browser to your icingaweb2 instance and going through the wizard.
All the steps should be clear with the database correctly set up.
After correctly setting icingaweb2, you should be able to access it.

