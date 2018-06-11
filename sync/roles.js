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
// get data from database
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
// write user roles to file
// --------------------------------------------------------------------------------------
function write_roles(data, callback)
{
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

    out += "\n";

    fs.appendFileSync("/etc/icingaweb2/roles.ini", out);
  }

  callback();
  
}
// --------------------------------------------------------------------------------------
// main function
// --------------------------------------------------------------------------------------
function main()
{
  var data = [];
  var db = init_db();
  db.connect(function(err) {
    if (err)
      throw err;

    async.series([
      function(callback) {
        get_data(db, data, callback);
      },
      function(callback) {
        write_roles(data, callback);
      },
    ],
    // optional callback
    function(err, results) {
      db.end();           // disconnect from db
    });
  });
}
// --------------------------------------------------------------------------------------
main()
