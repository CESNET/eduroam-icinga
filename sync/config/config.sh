# order of sync rules
# get this list by 'icingacli director syncrule list'
# the order here is important
# users depends on synced user groups
# hosts depeneds on synced host groups
sync_rules="15 14 16 17 19"
# admin mail
admin="root"
# ldap bind dn
bind_dn='uid=pokryti.eduroam.cz,ou=Special Users,dc=cesnet,dc=cz'
