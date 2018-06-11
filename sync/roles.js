#!/usr/bin/env node

// --------------------------------------------------------------------------------------
// this script is used to set realm admin roles in /etc/icingaweb2/roles.ini
// --------------------------------------------------------------------------------------
const async = require('async');
const mysql = require('mysql');
const fs = require('fs');
const assert = require('assert');
const secrets = require('./config/secrets.js');
const config = require('./config/config.js');
// --------------------------------------------------------------------------------------
// --------------------------------------------------------------------------------------
function init_db()
{
  var db = mysql.createConnection({
                  host     : 'localhost',
                  user     : 'icinga2',
                  password : secrets.db_pass,
                  database : 'ldap_to_icinga'
          });

  return db;
}
// --------------------------------------------------------------------------------------
// TODO
// --------------------------------------------------------------------------------------
function get_data(db, data, callback)
{
  db.query("select group_concat(uid), realm_cn from admin join realm on admin.admin_dn = realm.realm_manager group by realm_cn;", 
    function (error, result) {
      // save data
      for(var i in result)
        data.push({ realm : result[i].realm_cn, admins : result[i]['group_concat(uid)'] });

      callback();
  });
}
// --------------------------------------------------------------------------------------
// TODO
// --------------------------------------------------------------------------------------
function write_roles(data, callback)
{

//#[Realm_admins]
//#users = "machv@cesnet.cz"
//#permissions = "monitoring/*, module/*"
//#groups = "Administrators"

  var out = "";

  // TODO - pouzit pouze primarni realm

  for(var i in data) {
    //console.log(data[i].realm);

    out = "[" + data[i].realm + "_admins]\n"
    out += "users = \"";

    if(data[i].admins.indexOf(",") == -1)       // one admin only
      out += data[i].admins + "@cesnet.cz";
    else {                                      // multiple admins
      var admins = data[i].admins.split(",");

      for(var j in admins) {
        if(j == admins.length - 1)      // last one
          out += admins[j] + "@cesnet.cz";
        else
          out += admins[j] + "@cesnet.cz" + ", ";
      }
    }
    
    out += "\"\n";
    //out += "\n";

    // TODO
    //out += 'permissions = "monitoring/*, module/*\n"'
    
    // TODO
    // tohle asi nebude potreba?
    //out += 'groups = "Administrators"'



    // TODO - monitoring/blacklist/properties:  ?

    // permissions
    //out += 'permissions = "monitoring/command/schedule-check, monitoring/command/acknowledge-problem, monitoring/command/remove-acknowledgement, monitoring/command/comment/*, monitoring/command/downtime/*"\n';
    out += 'permissions = "module/monitoring, monitoring/command/schedule-check, monitoring/command/acknowledge-problem, monitoring/command/remove-acknowledgement, monitoring/command/comment/*, monitoring/command/downtime/*"\n';





//monitoring/command/*: Allow all commands
//monitoring/command/schedule-check: Allow scheduling host and service checks
//monitoring/command/acknowledge-problem: Allow acknowledging host and service problems
//monitoring/command/remove-acknowledgement: Allow removing problem acknowledgements
//monitoring/command/comment/*: Allow adding and deleting host and service comments
//monitoring/command/comment/add: Allow commenting on hosts and services
//monitoring/command/comment/delete: Allow deleting host and service comments
//monitoring/command/downtime/*: Allow scheduling and deleting host and service downtimes
//monitoring/command/downtime/schedule: Allow scheduling host and service downtimes
//monitoring/command/downtime/delete: Allow deleting host and service downtimes


//monitoring/command/process-check-result: Allow processing host and service check results
//monitoring/command/feature/instance: Allow processing commands for toggling features on an instance-wide basis
//monitoring/command/feature/object/*: Allow processing commands for toggling features on host and service objects
//monitoring/command/feature/object/active-checks: Allow processing commands for toggling active checks on host and service objects
//monitoring/command/feature/object/passive-checks: Allow processing commands for toggling passive checks on host and service objects
//monitoring/command/feature/object/notifications: Allow processing commands for toggling notifications on host and service objects
//monitoring/command/feature/object/event-handler: Allow processing commands for toggling event handlers on host and service objects
//monitoring/command/feature/object/flap-detection: Allow processing commands for toggling flap detection on host and service objects
//monitoring/command/send-custom-notification: Allow sending custom notifications for hosts and services


// TODO?
//Restrictions    monitoring/filter/objects: Restrict views to the Icinga objects that match the filter
//monitoring/blacklist/properties: Hide the properties of monitored objects that match the filter


    //// object filters
    ////out =+ 'monitoring/filter/objects = "host_name=*'

    //if(data[i].realm.indexOf(",") == -1) {       // one realm only
    //  out += 'monitoring/filter/objects = "hostgroup_name=';
    //  out += data[i].realm;
    //  out += '"\n';
    //}
    //else {                                      // multiple realms
    //  out += 'monitoring/filter/objects = "(hostgroup_name=';
    //  var realms = data[i].realm.split(",");

    //  for(var j in realms) {
    //    if(j == realms.length - 1)      // last one
    //      out += realms[j];
    //    else
    //      out += realms[j] + "|hostgroup_name=";
    //  }
    //  out += ')"\n';
    //}


    out += "\n";

    fs.appendFileSync("/etc/icingaweb2/roles.ini", out);
  }

  callback();
  
}
// --------------------------------------------------------------------------------------
// TODO
// --------------------------------------------------------------------------------------
function main()
{
  var data = []; // TODO
  var db = init_db();
  db.connect(function(err) {
    if (err) throw err;


  async.series([
    function(callback) {
      get_data(db, data, callback);
    },
    function(callback) {
      //// debug 
      //console.log(data);

      write_roles(data, callback);
      //callback();
      //print_radius_servers(radius_servers, callback);
    },
  ],
  // optional callback
  function(err, results) {
    //save_latest();

    //client.unbind(function(err) {
    //  assert.ifError(err);
    //});
    db.end();           // disconnect from db
  });
  });
}
// --------------------------------------------------------------------------------------
main()
