#!/usr/bin/perl -w
#
# check_radius.pl - Nagios Plugin
#
# Copyright (C) 2009 Carlos Vicente.  University of Oregon.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
#
#
# Report bugs to:
#
# Carlos Vicente <cvicente@ns.uoregon.edu>
# 
#
use strict;
use Authen::Radius;
use Getopt::Long qw(:config no_ignore_case);

my ($status, $host, $username, $password, $secret, $nas, $port, $timeout);
my $VERSION = 0.2;
my $HELP    = 0;
# Default values
$timeout = 5;
$port    = 1812;
$nas     = "127.0.0.1";

my %STATUSCODE = (  'OK'       => '0',
                    'WARNING'  => '1',
                    'CRITICAL' => '2',
		    'UNKNOWN'  => '3');


my $usage = <<EOF;
 
 Copyright (C) 2006 Carlos Vicente

 Checks if a Radius server can authenticate a username/password

  usage: $0  -H host -u username -p password -s secret 
             [-n nas-ip] [-P port] [-t timeout]

Options:
 -h, --help
    Print detailed help screen
 -H, --hostname=ADDRESS
    Host name or IP Address
 -P, --port=INTEGER
    Port number (default: $port)
 -u, --username=STRING
    The user to authenticate
 -p, --password=STRING
    Password for autentication (SECURITY RISK)
 -n, --nas-ip=STRING
    NAS IP Address (default: $nas)
 -s, --secret=STRING
    Radius secret
 -t, --timeout=INTEGER
    Seconds before connection times out (default: $timeout)

This plugin checks if a username/password can be authenticated against a 
Radius Server. 

The password option presents a substantial security issue because the
password can be determined by careful watching of the command line in
a process listing.  This risk is exacerbated because nagios will
run the plugin at regular predictable intervals.  Please make sure that
the password used does not allow access to sensitive system resources,
otherwise, a compromise could occur.

EOF


# handle cmdline args
my $result = GetOptions( "H|host=s"      => \$host,
			 "u|username=s"  => \$username,
			 "p|password=s"  => \$password,
			 "s|secret=s"    => \$secret,
			 "n|nas-ip:s"    => \$nas,
			 "P|port:i"      => \$port,
			 "t|timeout:i"   => \$timeout,
			 "h|help"        => \$HELP,
			 );

if( ! $result ) {
    print "ERROR: Problem with cmdline args\n";
    print $usage;
    exit($STATUSCODE{'UNKNOWN'});
}
if( $HELP ) {
    print $usage;
    exit($STATUSCODE{'UNKNOWN'});
}

if ( !($host && $username && $password && $secret) ){
    print "ERROR: Missing required arguments\n";
    print $usage;
    exit($STATUSCODE{'UNKNOWN'});
}

$host = "$host:$port" if $port;
if (!(my $radius = Authen::Radius->new(Host => $host, Secret => $secret, TimeOut => $timeout))){
    my $err = "Could not connect to $host";
    $err .= ": " . Authen::Radius::strerror if (Authen::Radius::strerror);
    print $err, "\n";
    $status = &set_status(0);
}else{
    my $answer = $radius->check_pwd($username, $password, $nas);
    $status = &set_status($answer);
}

exit($STATUSCODE{$status});

sub set_status {
    my $res = shift;
    my $status;
    if ($res) {
	$status = "OK";
    }else {
	$status = "CRITICAL";
    }
    print "$status\n";
    return($status);
}
