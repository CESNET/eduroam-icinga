#!/usr/bin/env node

// --------------------------------------------------------------------------------------
// run this script as:
// ./ldap_sync.js > /tmp/ldap_sync
// mysql ldap_to_icinga < /tmp/ldap_sync
// rm /tmp/ldap_sync
// --------------------------------------------------------------------------------------
const ldap = require('ldapjs');
const async = require('async');
const fs = require('fs');
const assert = require('assert');
const secrets = require('./config/secrets.js');
const config = require('./config/config.js');
const ldap2date = require('ldap2date');
// --------------------------------------------------------------------------------------
// global variables
var force_sync;
var latest_realm;
var latest_admin;
var latest_radius;
// --------------------------------------------------------------------------------------
// main
// --------------------------------------------------------------------------------------
function main()
{
  if(process.argv.length > 2 && process.argv[2] == "force")
    force_sync = true;
  else
    force_sync = false;

  synchronize_data();
}
// --------------------------------------------------------------------------------------
// synchronize data
// --------------------------------------------------------------------------------------
function synchronize_data() {
  var client = ldap.createClient({
    url: 'ldaps://' + config.ldap_host
  });

  client.bind(config.bind_dn, secrets.ldap_pass, function(err) {
    assert.ifError(err)
  })

  var realms = {};
  var radius_servers = {};
  var admins = {};
  var testing_ids = {};

  async.series([
    function(callback) {
      // ldap check is needed always regardless of force_sync
      check_ldap_changes(client, callback);       // everything is skipped if sync is not needed
    },
    function(callback) {
      create_db_structure(callback);
    },
    function(callback) {
      search_admins(client, admins, config.search_base_admins, callback);
    },
    function(callback) {
      print_admins(admins, callback);
    },
    function(callback) {
      search_realms(client, realms, testing_ids, config.search_base_realms, callback);
    },
    function(callback) {
      print_testing_ids(testing_ids, callback);
    },
    function(callback) {
      print_realms(realms, callback);
    },
    function(callback) {
      search_radius_servers(client, radius_servers, config.search_base_radius, callback);
    },
    function(callback) {
      print_radius_servers(radius_servers, callback);
    },
  ],
  // optional callback
  function(err, results) {
    save_latest();

    client.unbind(function(err) {
      assert.ifError(err);
    });
  });
};
// --------------------------------------------------------------------------------------
// write specific variable to specific file
// --------------------------------------------------------------------------------------
function save_latest_to_file(file, variable)
{
  fs.writeFileSync(file, variable);
}
// --------------------------------------------------------------------------------------
// save all latest timestamps
// --------------------------------------------------------------------------------------
function save_latest()
{
  save_latest_to_file(config.temp_file + 'latest_realm', latest_realm);
  save_latest_to_file(config.temp_file + 'latest_radius', latest_radius);
  save_latest_to_file(config.temp_file + 'latest_admin', latest_admin);
}
// --------------------------------------------------------------------------------------
// save latest to global variable based on search base
// --------------------------------------------------------------------------------------
function set_latest_output(latest, search_base)
{
  if(search_base == config.search_base_admins)
    latest_admin = latest;

  if(search_base == config.search_base_radius)
    latest_radius = latest;

  if(search_base == config.search_base_realms)
    latest_realm = latest;
}
// --------------------------------------------------------------------------------------
// check generic ldap object based on params
// --------------------------------------------------------------------------------------
function generic_ldap_check(client, temp_file, object_class, search_base, callback)
{
  var latest;

  // read latest realm timestamp from file
  try {
    latest = fs.readFileSync(temp_file, 'utf8');
  }
  catch(err) {
    latest = '20100214130606Z';
  }

  var opts = {
    filter: '(objectClass=' + object_class + ')',
    scope: 'sub',
    attributes: [ '*', 'modifyTimeStamp' ]
  };

  client.search(search_base, opts, function(err, res) {
    assert.ifError(err);

    res.on('searchEntry', function(entry) {
      if(entry.object.modifyTimeStamp > latest) {                // some new item is available
        force_sync = true;
        latest = entry.object.modifyTimeStamp;
      }
    });

    res.on('error', function(err) {
      console.error('error: ' + err.message);
      callback(false);
    });

    res.on('end', function(result) {
      set_latest_output(latest, search_base);        // save latest to output for next check

      //if(force_sync)
      //  callback("sync IS required");           // signalize that force sync IS required
      //else

      callback();       // all other ldap entities need to be checked too, so it is not possible to "end" here with callback forcing sync
    });
  });
}
// --------------------------------------------------------------------------------------
// check ldap for changes
// --------------------------------------------------------------------------------------
function check_ldap_changes(client, done)
{
  async.series([
    function(callback) {
      generic_ldap_check(client, config.temp_file + 'latest_realm', "eduroamRealm", config.search_base_realms, callback);    // realms
    },
    function(callback) {
      generic_ldap_check(client, config.temp_file + 'latest_radius', "eduroamRadius", config.search_base_radius, callback); // radius servers
    },
    function(callback) {
      generic_ldap_check(client, config.temp_file + 'latest_admin', "eduroamAdmin", config.search_base_admins, callback);    // admins
    },
  ],
  // optional callback
  function(err, results) {
    if(force_sync)
      done();
    else
      done("no error happened, sync is just NOT needed");         // signalize that force sync is NOT required
  });
}
// --------------------------------------------------------------------------------------
// search ldap for realms
// --------------------------------------------------------------------------------------
function search_realms(client, data, testing_ids, search_base, callback)
{
  // items which are registered for each realm
  var items = [ 'dn', 'cn', 'eduroamConnectionStatus', 'eduroamMemberType', 'manager', 'eduroamTestingId', 'eduroamTestingPassword', 'labeledUri' ];

  var opts = {
    // only connected or in-process realms
    filter: '(&(objectClass=eduRoamRealm)(|(eduroamConnectionStatus=connected)(eduroamConnectionStatus=in-process)))',
    scope: 'sub',
    attributes: items
  };

  client.search(search_base, opts, function(err, res) {
    assert.ifError(err);

    res.on('searchEntry', function(entry) {
      var key = entry.object['dn'].toLowerCase();

      data[key.toLowerCase()] = entry.object;          // save whole object as normalized dn value

      if(entry.object['eduroamTestingId'])
        testing_ids[entry.object['eduroamTestingId']] = { "id" : entry.object['eduroamTestingId'], "password" : entry.object['eduroamTestingPassword'] };

      data[key].dn = data[key].dn.toLowerCase();          // normalize dn
    });

    res.on('error', function(err) {
      console.error('error: ' + err.message);
      callback(null);
    });

    res.on('end', function(result) {
      callback(null);
    });
  });
}
// --------------------------------------------------------------------------------------
// print all available data
// --------------------------------------------------------------------------------------
function print_realms(data, callback)
{
  var out;
  var num = 1;
  console.log("INSERT INTO realm VALUES");

  for(var item in data) {
    // Nektere hodnoty budou vzdy definovane
    // pokud nektere hodnoty definovane nebudou, tak je treba, aby se s tim icinga vyrovnala

    if(typeof(data[item].manager) === 'object') {  // multiple managers
      for(var j in data[item].manager) {
        if(data[item].eduroamTestingId)
          out = "(" + num + ", '" + data[item].dn + "', '" + data[item].cn + "', '" + data[item].eduroamConnectionStatus + "', '" + data[item].eduroamMemberType + "', '" + data[item].manager[j] + "', '" + data[item].eduroamTestingId + "')";
        else
          out = "(" + num + ", '" + data[item].dn + "', '" + data[item].cn + "', '" + data[item].eduroamConnectionStatus + "', '" + data[item].eduroamMemberType + "', '" + data[item].manager[j] + "', NULL)";        // save as NULL


        if(Object.keys(data).indexOf(item) == Object.keys(data).length - 1 && j == data[item].manager.length - 1) // last item and last manager
          out += ";";
        else                       // not last item
          out += ",";

        console.log(out);
        num++;
      }
    }
    else {              // one manager only
      if(data[item].eduroamTestingId)
        out = "(" + num + ", '" + data[item].dn + "', '" + data[item].cn + "', '" + data[item].eduroamConnectionStatus + "', '" + data[item].eduroamMemberType + "', '" + data[item].manager + "', '" + data[item].eduroamTestingId + "')";
      else
        out = "(" + num + ", '" + data[item].dn + "', '" + data[item].cn + "', '" + data[item].eduroamConnectionStatus + "', '" + data[item].eduroamMemberType + "', '" + data[item].manager + "', NULL)";

      if(Object.keys(data).indexOf(item) == Object.keys(data).length - 1) // last item
        out += ";";
      else                       // not last item
        out += ",";

      console.log(out);
      num++;
    }
  }
  callback(null);
}
// --------------------------------------------------------------------------------------
// search ldap for radius servers
// --------------------------------------------------------------------------------------
function search_radius_servers(client, data, search_base, done)
{
  var opts = {
    //filter: '(&(objectClass=eduRoamRadius)(!(radiusDisabled=*)))',              // only active servers
    filter: '(&(objectClass=eduRoamRadius)(!(radiusDisabled=*))(eduroamIcingaEnabled=true))',              // only active servers, temporarily check if icinga enabled flag is present
    scope: 'sub',
    attributes: [ 'cn', 'eduroamInfRadiusSecret1', 'eduroamInfTransport', 'eduroamMonRadiusSecret', 'eduroamMonRealm', 'manager', 'eduroamInfRealm' ]
  };

  client.search(search_base, opts, function(err, res) {
    assert.ifError(err);

    res.on('searchEntry', function(entry) {
      var key = entry.object['dn'].toLowerCase();
      data[key] = entry.object;
      data[key].dn = data[key].dn.toLowerCase();                 // normalize dn

      // mon realms
      if(typeof(data[key].eduroamMonRealm) === 'object') {         // multiple mon realms
        var tmp = [];
        for(var realm in data[key].eduroamMonRealm)
          tmp.push(data[key].eduroamMonRealm[realm].toLowerCase());

        data[key].eduroamMonRealm = tmp;
      }
      else if(entry.object.eduroamMonRealm == undefined)              // set realm to NULL if it is undefined
        data[key].eduroamMonRealm = 'NULL';
      else                                                                        // single mon realm
        data[key].eduroamMonRealm = data[key].eduroamMonRealm.toLowerCase();

      // inf realms
      if(typeof(data[key].eduroamInfRealm) === 'object') {         // multiple inf realms
        var tmp = [];
        for(var realm in data[key].eduroamInfRealm)
          tmp.push(data[key].eduroamInfRealm[realm].toLowerCase());

        data[key].eduroamInfRealm = tmp;
      }
      else if(entry.object.eduroamInfRealm == undefined)              // set realm to NULL if it is undefined
        data[key].eduroamInfRealm = 'NULL';
      else                                                                        // single inf realm
        data[key].eduroamInfRealm = data[key].eduroamInfRealm.toLowerCase();
    });

    res.on('error', function(err) {
      console.error('error: ' + err.message);
    });

    res.on('end', function(result) {
      done();
    });
  });
}
// --------------------------------------------------------------------------------------
// print all available data
// --------------------------------------------------------------------------------------
function print_radius_servers(data, callback)
{
  var input = {};               // just to use pass by reference
  input.num = 1;

  console.log("INSERT INTO radius_server VALUES");

  for(var item in data) {               // iterate all data
    if(typeof(data[item].manager) === 'object')  // multiple managers
      print_radius_multiple_managers(data, data[item], input);

    else              // one manager only
      print_radius_one_manager(data, data[item], input);
  }
  callback(null);
}
// --------------------------------------------------------------------------------------
// print radius servers with multiple managers
// --------------------------------------------------------------------------------------
function print_radius_multiple_managers(data, item, input)
{
  var ret = {};
  ret.out = "";

  for(var j in item.manager) {
    if(typeof(item.eduroamMonRealm) == 'object') {            // multiple managers, multiple mon realms
      if(typeof(item.eduroamInfRealm) == 'object') {          // multiple managers, multiple mon realms, multiple inf realms
        for(var k in item.eduroamMonRealm) {
          for(var l in item.eduroamInfRealm) {
            check_null_values(item, input.num, ret, { "mon" : item.eduroamMonRealm[k], "inf" : item.eduroamInfRealm[l], "manager" : item.manager[j] });

            if(Object.keys(data).indexOf(item.dn) == Object.keys(data).length - 1 && j == item.manager.length - 1 && k == item.eduroamMonRealm.length - 1 && l == item.eduroamInfRealm.length - 1) // last item and last manager and last inf realm and last mon realm
              ret.out += ";";
            else                       // not last item
              ret.out += ",";

            console.log(ret.out);
            input.num++;
          }
        }
      }
    }
    else if(typeof(item.eduroamInfRealm) == 'object') {       // multiple managers, multiple inf realms
      for(var l in item.eduroamInfRealm) {
        check_null_values(item, input.num, ret, { "mon" : item.eduroamMonRealm, "inf" : item.eduroamInfRealm[l], "manager" : item.manager[j] });

        if(Object.keys(data).indexOf(item.dn) == Object.keys(data).length - 1 && j == item.manager.length - 1 && l == item.eduroamInfRealm.length - 1) // last item and last manager and last inf realm
          ret.out += ";";
        else                       // not last item
          ret.out += ",";

        console.log(ret.out);
        input.num++;
      }
    }
    else  {  // multiple managers, only one mon realm and only one inf realm
      check_null_values(item, input.num, ret, { "mon" : item.eduroamMonRealm, "inf" : item.eduroamInfRealm, "manager" : item.manager[j] });

      if(Object.keys(data).indexOf(item.dn) == Object.keys(data).length - 1 && j == item.manager.length - 1) // last item and last manager
        ret.out += ";";
      else                       // not last item
        ret.out += ",";

      console.log(ret.out);
      input.num++;
    }
  }
}
// --------------------------------------------------------------------------------------
// check radius server for null values
// --------------------------------------------------------------------------------------
function check_null_values(item, num, ret, obj)
{
  ret.out = "(" + num + ", '"  + item.dn + "', '" + item.cn + "', '" + item.eduroamInfRadiusSecret1 + "', '" + item.eduroamInfTransport + "', '" + item.eduroamMonRadiusSecret + "', ";

  if("mon" in obj && obj["mon"] == "NULL")
    ret.out += obj["mon"] + ", ";
  else
    ret.out += "'" + obj["mon"] + "', ";

  if("inf" in obj && obj["inf"] == "NULL")
    ret.out += obj["inf"] + ", ";
  else
    ret.out += "'" + obj["inf"] + "', ";

  ret.out += "'" + obj["manager"] + "')";
}
// --------------------------------------------------------------------------------------
// print radius servers record with one manager
// --------------------------------------------------------------------------------------
function print_radius_one_manager(data, item, input)
{
  var ret = {};
  ret.out = "";

  // iterate mon realms if needed
  if(typeof(item.eduroamMonRealm) == 'object') {      // one manager, multiple mon realms

    // also iterate inf realms if needed
    if(typeof(item.eduroamInfRealm) == 'object') {    // one manager, multiple mon realms, multiple inf realms
      for(var k in item.eduroamMonRealm) {
        for(var l in item.eduroamInfRealm) {
          check_null_values(item, input.num, ret, { "mon" : item.eduroamMonRealm[k], "inf" : item.eduroamInfRealm[l], "manager" : item.manager });

          if(Object.keys(data).indexOf(item.dn) == Object.keys(data).length - 1 && k == item.eduroamMonRealm.length - 1 && l == item.eduroamInfRealm.length - 1) // last item and last inf realm and last mon realm
            ret.out += ";";
          else                       // not last item
            ret.out += ",";

          console.log(ret.out);
          input.num++;
        }
      }
    }
  }
  else if(typeof(item.eduroamInfRealm) == 'object') { // one manager, multiple inf realms
    for(var l in item.eduroamInfRealm) {
      check_null_values(item, input.num, ret, { "mon" : item.eduroamMonRealm, "inf" : item.eduroamInfRealm[l], "manager" : item.manager });

      if(Object.keys(data).indexOf(item.dn) == Object.keys(data).length - 1 && l == item.eduroamInfRealm.length - 1) // last item and last inf realm
        ret.out += ";";
      else                       // not last item
        ret.out += ",";

      console.log(ret.out);
      input.num++;
    }
  }
  else {            // one manager only
    check_null_values(item, input.num, ret, { "mon" : item.eduroamMonRealm, "inf" : item.eduroamInfRealm, "manager" : item.manager });

    if(Object.keys(data).indexOf(item.dn) == Object.keys(data).length - 1) // last item
      ret.out += ";";
    else                       // not last item
      ret.out += ",";

    console.log(ret.out);
    input.num++;
  }
}
// --------------------------------------------------------------------------------------
// search ldap for admins
// --------------------------------------------------------------------------------------
function search_admins(client, data, search_base, done)
{
  var admins = [];
  var opts = {
    // filtr musi byt schopen reflektovat odpojene realmy a disablovane radius servery
    filter: '(&(manager=*)(|(&(objectClass=eduRoamRealm)(|(eduroamConnectionStatus=connected)(eduroamConnectionStatus=in-process)))(&(objectClass=eduRoamRadius)(!(radiusDisabled=*)))))',
    scope: 'sub',
    attributes: [ 'manager' ]
  };

  client.search(search_base, opts, function(err, res) {
    assert.ifError(err);

    res.on('searchEntry', function(entry) {
      admins.push(entry.object.manager);                // array or string
    });

    res.on('error', function(err) {
      console.error('error: ' + err.message);
    });

    res.on('end', function(result) {
      save_admins(client, admins, data, done);
    });
  });
}
// --------------------------------------------------------------------------------------
// save information about admins
// --------------------------------------------------------------------------------------
function save_admins(client, input, data, done)
{
  var opts = {
    filter: '(objectClass=*)',
    scope: 'sub',
    attributes: [ 'dn', 'eduPersonPrincipalNames', 'cn', 'mail', 'uid' ]                // TODO - EPPN
  };

  var admins = {};

  // create dict first
  for(var i in input) {
    if(typeof(input[i]) === 'object') {
      for(var j in input[i])
      admins[input[i][j]] = "a";           // use dummy value here, only the key is usefull
    }
    else
      admins[input[i]] = "a";           // use dummy value here, only the key is usefull
  }

  // do ldap search
  async.forEachOf(admins, function(value, key, callback) {
    client.search(key, opts, function(err, res) {
      assert.ifError(err);

      res.on('searchEntry', function(entry) {
        data[entry.object.dn] = entry.object;
      });

      res.on('error', function(err) {
        console.error('error: ' + err.message);
      });

      res.on('end', function(result) {
        callback();
      });
    });
  }, function(err) {
    done();
  });
}
// --------------------------------------------------------------------------------------
// print all available data
// --------------------------------------------------------------------------------------
function print_admins(data, callback)
{
  var out;
  console.log("INSERT INTO admin VALUES");             // insert

  for(var item in data) {
    // Pokud bude mail prazdny, tak chceme cloveka alespon evidovat a icinga by se s tim mela byt schopna nejak vyrovnat
    // TODO - tohle zkusit nejak rozumne otestovat?     - podminka v kodu na me

    // TODO - co kdyz bude mail prazdny?

    // icingaweb2 is not able to correctly handle czech characters, so cn;lang-en is used here
    // more info:
    // https://github.com/Icinga/icinga2/issues/5412
    // https://github.com/Icinga/icingaweb2/issues/2392
    // https://github.com/Icinga/icinga-web/issues/1346
    // https://github.com/Icinga/icingaweb2/issues/2788

    if(data[item].mail) {               // mail is defined
      if(typeof(data[item].mail) === 'object')
        out = "('" + data[item].dn + "', '" + data[item]['cn;lang-en'] + "', '" + data[item].mail[0] + "', '" + data[item].uid + "')";  // first mail
      else
        out = "('" + data[item].dn + "', '" + data[item]['cn;lang-en'] + "', '" + data[item].mail + "', '" + data[item].uid + "')";  // the only mail

      if(Object.keys(data).indexOf(item) == Object.keys(data).length - 1) // last item
        out += ";";
      else                       // not last item
        out += ",";

      console.log(out);
    }
  }
  callback(null);
}
// --------------------------------------------------------------------------------------
// print testing ids
// --------------------------------------------------------------------------------------
function print_testing_ids(data, callback)
{
  var out;
  console.log("INSERT INTO testing_id VALUES");             // insert

  for(var item in data) {
    out = "('" + data[item].id + "', '" + data[item].password + "')";

    if(Object.keys(data).indexOf(item) == Object.keys(data).length - 1) // last item
      out += ";";
    else                       // not last item
      out += ",";

    console.log(out);
  }
  callback(null);
}
// --------------------------------------------------------------------------------------
// create mysql database structure to store data
// --------------------------------------------------------------------------------------
function create_db_structure(callback)
{
  // drop tables first
  console.log("DROP TABLE IF EXISTS radius_server;");
  console.log("DROP TABLE IF EXISTS realm;");
  console.log("DROP TABLE IF EXISTS admin;");
  console.log("DROP TABLE IF EXISTS testing_id;");

  // max varchar size set to 191 - because of https://stackoverflow.com/questions/1814532/1071-specified-key-was-too-long-max-key-length-is-767-bytes
  // 191 * 4 = 764

  //console.log("DROP TABLE IF EXISTS realm_radius;");
  //console.log("DROP TABLE IF EXISTS radius_admin;");
  //console.log("DROP TABLE IF EXISTS radius_testing_id;");

  console.log("CREATE TABLE IF NOT EXISTS admin (admin_dn VARCHAR(191) NOT NULL, admin_cn VARCHAR(191) NOT NULL, mail VARCHAR(191) NOT NULL, uid VARCHAR(191) NOT NULL, PRIMARY KEY ( admin_dn ), INDEX admin_idx (admin_dn));");

  console.log("CREATE TABLE IF NOT EXISTS testing_id (id VARCHAR(191) NOT NULL, password VARCHAR(191) NOT NULL, INDEX testing_id_idx(id));");

  //console.log("CREATE TABLE IF NOT EXISTS realm (id INT NOT NULL AUTO_INCREMENT, realm_dn VARCHAR(191) NOT NULL, realm_cn VARCHAR(191) NOT NULL, status VARCHAR(191) NOT NULL, member_type VARCHAR(191) NOT NULL, realm_manager VARCHAR(191) NOT NULL, FOREIGN KEY (realm_manager) REFERENCES admin(admin_dn), testing_id VARCHAR(191) NOT NULL, testing_pass VARCHAR(191) NOT NULL, PRIMARY KEY ( id ), UNIQUE ( id ), INDEX realm_idx (realm_dn));");

  console.log("CREATE TABLE IF NOT EXISTS realm (id INT NOT NULL AUTO_INCREMENT, realm_dn VARCHAR(191) NOT NULL, realm_cn VARCHAR(191) NOT NULL, status VARCHAR(191) NOT NULL, member_type VARCHAR(191) NOT NULL, realm_manager VARCHAR(191) NOT NULL, FOREIGN KEY (realm_manager) REFERENCES admin(admin_dn), testing_id VARCHAR(191), FOREIGN KEY (testing_id) REFERENCES testing_id(id), PRIMARY KEY ( id ), UNIQUE ( id ), INDEX realm_idx (realm_dn));");

  console.log("CREATE TABLE IF NOT EXISTS radius_server (id INT NOT NULL AUTO_INCREMENT, radius_dn VARCHAR(191) NOT NULL, radius_cn VARCHAR(191) NOT NULL, inf_radius_secret VARCHAR(191) NOT NULL, transport VARCHAR(191) NOT NULL, mon_radius_secret VARCHAR(191) NOT NULL, mon_realm VARCHAR(191), FOREIGN KEY (mon_realm) REFERENCES realm(realm_dn), inf_realm VARCHAR(191), FOREIGN KEY (inf_realm) REFERENCES realm(realm_dn), radius_manager VARCHAR(191) NOT NULL, FOREIGN KEY (radius_manager) REFERENCES admin(admin_dn), PRIMARY KEY ( id ), UNIQUE ( id ), INDEX radius_server_idx (radius_dn));");

 
  //console.log("CREATE TABLE IF NOT EXISTS radius_server (id INT NOT NULL AUTO_INCREMENT, radius_dn VARCHAR(191) NOT NULL, radius_cn VARCHAR(191) NOT NULL, inf_radius_secret VARCHAR(191) NOT NULL, transport VARCHAR(191) NOT NULL, mon_radius_secret VARCHAR(191) NOT NULL, mon_realm VARCHAR(191), FOREIGN KEY (mon_realm) REFERENCES realm(realm_dn), inf_realm VARCHAR(191), FOREIGN KEY (inf_realm) REFERENCES realm(realm_dn), radius_manager VARCHAR(191) NOT NULL, FOREIGN KEY (radius_manager) REFERENCES admin(admin_dn), PRIMARY KEY ( id ), UNIQUE ( id ), INDEX radius_server_idx (radius_dn));");

 //console.log("CREATE TABLE IF NOT EXISTS realm_admin;");               // potrebujeme vubec evidovat adminy u realmu?
  // pokud ano, tak dalsi vazebni tabulky realm_admin?

  callback(null);
}
// --------------------------------------------------------------------------------------
main()
// --------------------------------------------------------------------------------------

