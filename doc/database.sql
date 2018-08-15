DROP TABLE IF EXISTS radius_server;
DROP TABLE IF EXISTS realm;
DROP TABLE IF EXISTS admin;
DROP TABLE IF EXISTS testing_id;
CREATE TABLE IF NOT EXISTS admin (admin_dn VARCHAR(191) NOT NULL, admin_cn VARCHAR(191) NOT NULL, mail VARCHAR(191) NOT NULL, uid VARCHAR(191) NOT NULL, PRIMARY KEY ( admin_dn ), INDEX admin_idx (admin_dn));
CREATE TABLE IF NOT EXISTS testing_id (id VARCHAR(191) NOT NULL, password VARCHAR(191) NOT NULL, INDEX testing_id_idx(id));
CREATE TABLE IF NOT EXISTS realm (id INT NOT NULL AUTO_INCREMENT, realm_dn VARCHAR(191) NOT NULL, realm_cn VARCHAR(191) NOT NULL, member_type VARCHAR(191) NOT NULL, xml_url VARCHAR(191) NOT NULL, realm_manager VARCHAR(191) NOT NULL, FOREIGN KEY (realm_manager) REFERENCES admin(admin_dn), testing_id VARCHAR(191), FOREIGN KEY (testing_id) REFERENCES testing_id(id), PRIMARY KEY ( id ), UNIQUE ( id ), INDEX realm_idx (realm_dn));
CREATE TABLE IF NOT EXISTS radius_server (id INT NOT NULL AUTO_INCREMENT, radius_dn VARCHAR(191) NOT NULL, radius_cn VARCHAR(191) NOT NULL, transport VARCHAR(191) NOT NULL, mon_radius_secret VARCHAR(191) NOT NULL, mon_realm VARCHAR(191), FOREIGN KEY (mon_realm) REFERENCES realm(realm_dn), inf_realm VARCHAR(191), FOREIGN KEY (inf_realm) REFERENCES realm(realm_dn), radius_manager VARCHAR(191) NOT NULL, FOREIGN KEY (radius_manager) REFERENCES admin(admin_dn), PRIMARY KEY ( id ), UNIQUE ( id ), INDEX radius_server_idx (radius_dn));

