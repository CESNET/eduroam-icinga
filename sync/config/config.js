// confoguration file
// ==========================================================================================
module.exports = {
  ldap_host            : 'ldap.cesnet.cz',
  bind_dn              : 'uid=ermon.cesnet.cz,ou=Special Users,dc=cesnet,dc=cz',
  search_base_realms   : 'ou=Realms,o=eduroam,o=apps,dc=cesnet,dc=cz',
  search_base_radius   : 'ou=Radius Servers,o=eduroam,o=apps,dc=cesnet,dc=cz',
  search_base_orgs     : 'ou=Organizations,dc=cesnet,dc=cz',
  search_base_admins   : 'o=eduroam,o=apps,dc=cesnet,dc=cz',
  temp_file            : '/tmp/icinga/'
}
// ==========================================================================================
