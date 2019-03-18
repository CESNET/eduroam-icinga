#!/usr/bin/perl -w
#
# check_radius.pl - Nagios Plugin
#
# Copyright (C) 2009 Carlos Vicente.  University of Oregon.
# Copyright (c) 2019 CESNET, Jan Tomasek
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

# dependency libauthen-radius-perl

use strict;
use Authen::Radius;
use Data::Dumper;
use Getopt::Long qw(:config no_ignore_case);

my ($status, $host, $username, $password, $secret, $nas, $port, $timeout, $status_server);
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
 -S, --status-server
    Do Status-Server verification instead of username/password

This plugin checks if a username/password can be authenticated against a 
Radius Server. Or it check Status-Servery by special attribute, RFC 5997.

The password option presents a substantial security issue because the
password can be determined by careful watching of the command line in
a process listing.  This risk is exacerbated because nagios will
run the plugin at regular predictable intervals.  Please make sure that
the password used does not allow access to sensitive system resources,
otherwise, a compromise could occur.

EOF


# handle cmdline args
my $result = GetOptions( "H|host=s"        => \$host,
			 "u|username=s"    => \$username,
			 "p|password=s"    => \$password,
			 "s|secret=s"      => \$secret,
			 "n|nas-ip:s"      => \$nas,
			 "P|port:i"        => \$port,
			 "t|timeout:i"     => \$timeout,
			 "S|status-server" => \$status_server,
			 "h|help"          => \$HELP,
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

if ( !(($host && $username && $password && $secret) or ($host && $status_server)) ){
    print "ERROR: Missing required arguments\n";
    print $usage;
    exit($STATUSCODE{'UNKNOWN'});
}

$host = "$host:$port" if $port;

if (!(my $radius = Authen::Radius->new(Host => $host,
				       Secret => $secret,
				       TimeOut => $timeout,
				       #Debug => 1
      ))){
    my $err = "Could not connect to $host";
    $err .= ": " . Authen::Radius::strerror if (Authen::Radius::strerror);
    print $err, "\n";
    $status = &set_status(0);
} else {
    my $answer;

    # dictionary is tricky, Authen::Radius on debian comes with
    # dictionary within
    # /usr/share/doc/libauthen-radius-perl/raddb/dictionary and
    # attempt to load it ends with error: Can't open dictionary
    # '/usr/share/doc/libauthen-radius-perl/raddb/dictionary.usr' (No
    # such file or directory) that is because usr is shipped as
    # compresed file. Test works without dict, so it is disabled.

    # $radius->load_dictionary('/usr/share/doc/libauthen-radius-perl/raddb/dictionary');

    if ($status_server) {
	$radius->add_attributes({'Name' => 80, #'Message-Authenticator',
				 'Value' => 0x00,
				 'Type' => 'integer'});
	$answer = $radius->send_packet(STATUS_SERVER);
	my $type = $radius->recv_packet();
	if (defined($type) && $type == ACCESS_ACCEPT) {
	    print "OK ";
	    print "Status-Server response is Access-Accept ($type)\n";

	    # without dictionary we are missing human readable
	    # attribute names

	    #for $a ($radius->get_attributes()) {
	    #	print "$a->{'Name'} = $a->{'Value'}\n";
	    #}
	    exit($STATUSCODE{'OK'});
	}

	print "CRITICAL ". $radius->strerror."\n";
	exit($STATUSCODE{'CRITICAL'});
    }

    $answer = $radius->check_pwd($username, $password, $nas);
    if ($answer) {
	print "OK\n";
	exit($STATUSCODE{'OK'});
    } else {
	my $msg = $radius->strerror;
	$msg = 'bad username/password' if ($msg eq 'none');
	print "CRITICAL $msg\n";
	exit($STATUSCODE{'CRITICAL'});
    };
};

# never should reach this point

print "UNKNOWN\n";
exit($STATUSCODE{'UNKNOWN'});
