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
  var disabled_realms = {};

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
      search_radius_servers(client, radius_servers, disabled_realms, config.search_base_radius, callback);
    },
    function(callback) {
      delete_disabled(realms, disabled_realms, testing_ids, callback);
    },
    function(callback) {
      print_radius_servers(radius_servers, callback);
    },
    function(callback) {
      print_services(radius_servers, realms, testing_ids, disabled_realms, callback);
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

      data[key] = entry.object;          // save whole object as normalized dn value

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
// TODO
// --------------------------------------------------------------------------------------
function set_disabled_realm(disabled_realms, realm, type)
{
  if(realm in disabled_realms) {
    if(type in disabled_realms[realm])          // type exists
      disabled_realms[realm][type]++;
    else
      disabled_realms[realm][type] = 1;         // key exists, but first of its type
  }
  else {
    disabled_realms[realm] = {};
    disabled_realms[realm][type] = 1;           // key does not exist
  }
}
// --------------------------------------------------------------------------------------
// TODO
// --------------------------------------------------------------------------------------
function store_radius_server(data, key, ldap_object, disabled_realms)
{
  var types = [ "eduroamMonRealm", "eduroamInfRealm" ];

  // radius is disabled, delete realm
  //                      // TODO - co kdyz nastane pripad, kdy by na jednom realmu byl zaroven aktivni a neaktivni server?
  //                      // spravne by to melo dopadnout tak, ze pouze pokud pro dany realm budou vsechny servery neaktivni, tak bude vymazan z dalsiho zpracovani
  if(ldap_object.radiusDisabled == 'true') {              // radius is disabled, delete realm
    // process realm types in loop
    for(var type in types) {
      if(typeof(ldap_object[types[type]]) === 'object') {         // multiple mon/inf realms
        for(var realm in ldap_object[types[type]])
          set_disabled_realm(disabled_realms, ldap_object[types[type]][realm].toLowerCase(), "disabled");
      }
      else if(ldap_object[types[type]] == undefined)              // set realm to NULL if it is undefined
        ;
      else                                                                      // single mon/inf realm
        set_disabled_realm(disabled_realms, ldap_object[types[type]].toLowerCase(), "disabled");
    }
  }
  else {
    data[key] = ldap_object;
    data[key].dn = data[key].dn.toLowerCase();                 // normalize dn

    // process realm types in loop
    for(var type in types) {
      if(typeof(data[key][types[type]]) === 'object') {         // multiple mon/inf realms
        var tmp = [];
        for(var realm in data[key][types[type]]) {
          set_disabled_realm(disabled_realms, data[key][types[type]][realm].toLowerCase(), "enabled");
          tmp.push(data[key][types[type]][realm].toLowerCase());
        }
        data[key][types[type]] = tmp;
      }
      else if(ldap_object[types[type]] == undefined)              // set realm to NULL if it is undefined
        data[key][types[type]] = 'NULL';
      else {                                                                      // single mon/inf realm
        data[key][types[type]] = data[key][types[type]].toLowerCase();
        set_disabled_realm(disabled_realms, data[key][types[type]].toLowerCase(), "enabled");
      }
    }
  }
}
// --------------------------------------------------------------------------------------
// search ldap for radius servers
// --------------------------------------------------------------------------------------
function search_radius_servers(client, data, disabled_realms, search_base, done)
{
  var opts = {
    //filter: '(&(objectClass=eduRoamRadius)(!(radiusDisabled=*)))',              // only active servers
    filter: '(objectClass=eduRoamRadius)',              // inactive servers are needed to filter realms!
    //filter: '(&(objectClass=eduRoamRadius)(!(radiusDisabled=*))(eduroamIcingaEnabled=true))',              // only active servers, temporarily check if icinga enabled flag is present
    scope: 'sub',
    attributes: [ 'cn', 'eduroamInfRadiusSecret1', 'eduroamInfTransport', 'eduroamMonRadiusSecret', 'eduroamMonRealm', 'manager', 'eduroamInfRealm', 'radiusDisabled' ]
  };

  client.search(search_base, opts, function(err, res) {
    assert.ifError(err);

    res.on('searchEntry', function(entry) {
      var key = entry.object['dn'].toLowerCase();
      store_radius_server(data, key, entry.object, disabled_realms);
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
// TODO
// --------------------------------------------------------------------------------------
function delete_disabled(realms, disabled_realms, testing_ids, callback)
{
  for(var i in disabled_realms) {
    // no radius servers enabled for realm i
    if("disabled" in disabled_realms[i] && disabled_realms[i].disabled > 0 && !("enabled" in disabled_realms[i])) {
      if(realms[i]) {     // realm is not disconnected
        delete testing_ids[realms[i].eduroamTestingId];  // delete testing id
        delete realms[i];       // delete realm
      }
    }
  }
  callback();
}
// --------------------------------------------------------------------------------------
// TODO
// --------------------------------------------------------------------------------------
function prepare_service_output(visitors_realm, mon_realm, j, home_server, realm)
{
  var out;
  out = "(";
  // key
  out += "'" + visitors_realm + "@" + mon_realm + "@" + j + "',";

  // visitors realm
  out += "'" + visitors_realm + "',";

  // visited realm
  out += "'" + mon_realm + "',";

  // radius hostname on which the test is being run
  out += "'" + j + "',";

  // home server for visitor's realm
  out += "'" + home_server + "',";

  // checking home realm [bool]
  if(visitors_realm == mon_realm)
    out += " " + 1 + ", ";
  else
    out += " " + 0 + ", ";
    //out += "'false', ";

  // inf radius
  // TODO

  // testing id, password
  out += "'" + realm.eduroamTestingId + "',";
  out += "'" + realm.eduroamTestingPassword + "'";

  out += "),";
  return out;
}
// --------------------------------------------------------------------------------------
// TODO
// --------------------------------------------------------------------------------------
function multiple_home_servers(realms_radius, primary_realm, mon_realm, j, realm)
{
  var out;

  if(typeof(realms_radius[primary_realm]) === 'object') {         // multiple home servers for visitor's realm
    var tmp = "";

    for(var m in realms_radius[primary_realm])
      tmp += realms_radius[primary_realm][m] + ','
    out = prepare_service_output(primary_realm, mon_realm, j, tmp, realm);
  }
  else
    out = prepare_service_output(primary_realm, mon_realm, j, realms_radius[primary_realm], realm);

  return out;
}
// --------------------------------------------------------------------------------------
// TODO
// --------------------------------------------------------------------------------------
function process_services(radius_servers, mon_realm, realms, realms_radius)
{
  var out;

  for(var l in realms) {
    if(realms[l].eduroamTestingId != undefined) {
      // key
      if(typeof(realms[l].cn) === 'object')
        var primary_realm = realms[l].cn[0];
      else
        var primary_realm = realms[l].cn;

      for(var j in mon_realm) {
        if(typeof(mon_realm[j]) === 'object') {         // multiple mon realms
          // debug
          //console.log("multiple mon realms for " + j);
          //console.log("multiple mon realms for " + j);

          for(var k in mon_realm[j]) {
            out = multiple_home_servers(realms_radius, primary_realm, mon_realm[j][k], j, realms[l]);
            console.log(out);
          }
        }
        else {
          out = multiple_home_servers(realms_radius, primary_realm, mon_realm[j], j, realms[l]);
          console.log(out);
        }
      }
    }
  }

  // spise nez out tisknout
  // out je potreba nasledne upravit, aby na poslednim radku nebyla posledni carka
}
// --------------------------------------------------------------------------------------
// TODO
// --------------------------------------------------------------------------------------
function reverse_mapping(mon_realm, realms_radius)
{
  // generate reverse mapping, always one realm as key
  for(var i in mon_realm) {
    if(typeof(mon_realm[i]) === 'object')       // get only one realm as key
      for(var j in mon_realm[i]) {
        var key = mon_realm[i][j];

        if(key in realms_radius) {   // key exists, convert to array and append to it
          var tmp = realms_radius[key];
          realms_radius[key] = [];
          realms_radius[key].push(tmp);
          realms_radius[key].push(i);
        }
        else
          realms_radius[key] = i;
      }
    else {
      var key = mon_realm[i];

      if(key in realms_radius) {   // key exists, convert to array and append to it
        var tmp = realms_radius[key];
        realms_radius[key] = [];
        realms_radius[key].push(tmp);
        realms_radius[key].push(i);
      }
      else
        realms_radius[key] = i;
    }
  }
}
// --------------------------------------------------------------------------------------
// print testing ids
// --------------------------------------------------------------------------------------
function print_services(radius_servers, realms, testing_ids, disabled_realms, callback)
{
  var out;
  var mon_realm = {};
  var inf_realm = {};
  var realms_radius = {};       // reverse mapping for better indexing

  console.log("INSERT INTO service VALUES");             // insert

  for(var i in radius_servers) {
    if(radius_servers[i].eduroamMonRealm != 'NULL') {      // not undefined
      if(typeof(radius_servers[i].eduroamMonRealm) === 'object')  // multiple mon realms
        for(var realm in radius_servers[i].eduroamMonRealm) {
          //console.log(typeof(realms[radius_servers[i].eduroamMonRealm[realm]].cn));
          //console.log(realms[radius_servers[i].eduroamMonRealm[realm]].cn);

          if(typeof(realms[radius_servers[i].eduroamMonRealm[realm]].cn) === 'object')
            var value = realms[radius_servers[i].eduroamMonRealm[realm]].cn[0];         // use primary realm only
          else
            var value = realms[radius_servers[i].eduroamMonRealm[realm]].cn;


          if(radius_servers[i].cn in mon_realm) // key exists, add
            mon_realm[radius_servers[i].cn].push(value)
          else {                                 // create key
            mon_realm[radius_servers[i].cn] = [];
            mon_realm[radius_servers[i].cn].push(value)
          }
        }
      else {
        if(typeof(realms[radius_servers[i].eduroamMonRealm].cn) === 'object')
          var value = realms[radius_servers[i].eduroamMonRealm].cn[0];         // use primary realm only
        else
          var value = realms[radius_servers[i].eduroamMonRealm].cn;

        mon_realm[radius_servers[i].cn] = value;
      }
    }
  }

  // generate reverse mapping, always one realm as key
  reverse_mapping(mon_realm, realms_radius);


  //console.log(mon_realm);
  //console.log("<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>");
  //console.log(realms_radius);

  //console.log("<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>");
  //console.log(testing_ids);
  //console.log("<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>");
  //console.log(disabled_realms);

  process_services(radius_servers, mon_realm, realms, realms_radius);

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
  console.log("DROP TABLE IF EXISTS service;");

  // max varchar size set to 191 - because of https://stackoverflow.com/questions/1814532/1071-specified-key-was-too-long-max-key-length-is-767-bytes
  // 191 * 4 = 764

  //console.log("DROP TABLE IF EXISTS radius_admin;");
  //console.log("DROP TABLE IF EXISTS radius_testing_id;");

  console.log("CREATE TABLE IF NOT EXISTS admin (admin_dn VARCHAR(191) NOT NULL, admin_cn VARCHAR(191) NOT NULL, mail VARCHAR(191) NOT NULL, uid VARCHAR(191) NOT NULL, PRIMARY KEY ( admin_dn ), INDEX admin_idx (admin_dn));");

  console.log("CREATE TABLE IF NOT EXISTS testing_id (id VARCHAR(191) NOT NULL, password VARCHAR(191) NOT NULL, INDEX testing_id_idx(id));");

  //console.log("CREATE TABLE IF NOT EXISTS realm (id INT NOT NULL AUTO_INCREMENT, realm_dn VARCHAR(191) NOT NULL, realm_cn VARCHAR(191) NOT NULL, status VARCHAR(191) NOT NULL, member_type VARCHAR(191) NOT NULL, realm_manager VARCHAR(191) NOT NULL, FOREIGN KEY (realm_manager) REFERENCES admin(admin_dn), testing_id VARCHAR(191) NOT NULL, testing_pass VARCHAR(191) NOT NULL, PRIMARY KEY ( id ), UNIQUE ( id ), INDEX realm_idx (realm_dn));");

  console.log("CREATE TABLE IF NOT EXISTS realm (id INT NOT NULL AUTO_INCREMENT, realm_dn VARCHAR(191) NOT NULL, realm_cn VARCHAR(191) NOT NULL, status VARCHAR(191) NOT NULL, member_type VARCHAR(191) NOT NULL, realm_manager VARCHAR(191) NOT NULL, FOREIGN KEY (realm_manager) REFERENCES admin(admin_dn), testing_id VARCHAR(191), FOREIGN KEY (testing_id) REFERENCES testing_id(id), PRIMARY KEY ( id ), UNIQUE ( id ), INDEX realm_idx (realm_dn));");

  console.log("CREATE TABLE IF NOT EXISTS radius_server (id INT NOT NULL AUTO_INCREMENT, radius_dn VARCHAR(191) NOT NULL, radius_cn VARCHAR(191) NOT NULL, inf_radius_secret VARCHAR(191) NOT NULL, transport VARCHAR(191) NOT NULL, mon_radius_secret VARCHAR(191) NOT NULL, mon_realm VARCHAR(191), FOREIGN KEY (mon_realm) REFERENCES realm(realm_dn), inf_realm VARCHAR(191), FOREIGN KEY (inf_realm) REFERENCES realm(realm_dn), radius_manager VARCHAR(191) NOT NULL, FOREIGN KEY (radius_manager) REFERENCES admin(admin_dn), PRIMARY KEY ( id ), UNIQUE ( id ), INDEX radius_server_idx (radius_dn));");


  console.log("CREATE TABLE IF NOT EXISTS service (id VARCHAR(191) NOT NULL, visitors_realm VARCHAR(191) NOT NULL, visited_realm VARCHAR(191) NOT NULL, check_host VARCHAR(191) NOT NULL, home_server VARCHAR(191) NOT NULL, home_realm_check BOOLEAN, testing_id VARCHAR(191) NOT NULL, password VARCHAR(191) NOT NULL, PRIMARY KEY ( id ), UNIQUE ( id ), INDEX service_idx (id));");
 
  //console.log("CREATE TABLE IF NOT EXISTS radius_server (id INT NOT NULL AUTO_INCREMENT, radius_dn VARCHAR(191) NOT NULL, radius_cn VARCHAR(191) NOT NULL, inf_radius_secret VARCHAR(191) NOT NULL, transport VARCHAR(191) NOT NULL, mon_radius_secret VARCHAR(191) NOT NULL, mon_realm VARCHAR(191), FOREIGN KEY (mon_realm) REFERENCES realm(realm_dn), inf_realm VARCHAR(191), FOREIGN KEY (inf_realm) REFERENCES realm(realm_dn), radius_manager VARCHAR(191) NOT NULL, FOREIGN KEY (radius_manager) REFERENCES admin(admin_dn), PRIMARY KEY ( id ), UNIQUE ( id ), INDEX radius_server_idx (radius_dn));");

 //console.log("CREATE TABLE IF NOT EXISTS realm_admin;");               // potrebujeme vubec evidovat adminy u realmu?
  // pokud ano, tak dalsi vazebni tabulky realm_admin?

  callback(null);
}
// --------------------------------------------------------------------------------------
main()
// --------------------------------------------------------------------------------------

