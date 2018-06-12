#!/usr/bin/perl

###  check_radsecproxy.pl

# Originally by Nathan Vonnahme, n8v at users dot sourceforge
# dot net, July 19 2006

# Please modify to your heart's content and use as the basis for all
# the really cool Nagios monitoring scripts you're going to create.
# You rock. 
#
# Pavel Polacek  pavel.polacek@ujep.cz 
# ver. 0.02 24.09.2009

##############################################################################
# prologue
use strict;
use warnings;

use Monitoring::Plugin ;
use Data::Dumper;

use vars qw($VERSION $PROGNAME $verbose $result);
'$Revision: 1.3 $' =~ /^.*(\d+.\d+) \$$/;  # Use The Revision from RCS/CVS/Subversion
$VERSION = $1;

# get the base name of this script for use in the examples
use File::Basename;
$PROGNAME = basename($0);


##############################################################################
# define and get the command line options.
#   see the command line option guidelines at 
#   http://nagiosplug.sourceforge.net/developer-guidelines.html#PLUGOPTIONS


# Instantiate Nagios::Plugin object (the 'usage' parameter is mandatory)
my $p = Monitoring::Plugin->new(
    usage => "Usage: %s [ -v|--verbose ]  [-H <host>] [-t <timeout>] [-P <port>]",
    version => $VERSION,
    blurb => 'Check connection to radsecproxy.', 

	extra => ""
);


# Define and document the valid command line options
# usage, help, version, timeout and verbose are defined by default.
$p->add_arg(
    spec => 'hostname|H=s',
    help => 
      qq{-H, --hostname=IP address},
);

$p->add_arg(
    spec => 'port|P=s',
    help => 
      qq{-H, --port=IP address},
);

$p->add_arg(
    spec => 'SPonly|S',
    help => 
      qq{-S, --SPonly},
    );

$p->add_arg(
    spec => 'IdPonly|I',
    help => 
      qq{-I, --IdPonly},
);


# Parse arguments and process standard ones (e.g. usage, help, version)
$p->getopts;


##############################################################################
my $ip_addr;
if (defined $p->opts->hostname) {
  $ip_addr = $p->opts->hostname;
} else {
  $p->nagios_die( "-H <ip_addr> option is not defined" );
}

my $port = '208.';  # default port
if (defined $p->opts->port) {
  $port = $p->opts->port;
}

my $netstat_result = `LANG=en /bin/netstat -tn`; # | grep $ip_addr:$port | awk '{print \$6}'`;

my @rows = split( /\n/, $netstat_result);

#print Dumper @rows;

my @rows_ip = grep( /$ip_addr/, @rows );

#print $grep_result;
my @to_proxy = grep( /$ip_addr:$port/, @rows_ip );
my @from_proxy = grep( /:$port\s/, grep( !/$ip_addr:$port/, @rows_ip ));

#print Dumper @to_proxy;
#print Dumper @from_proxy;

my $grep_result = "";

my $result = CRITICAL;
my $res_message = "";

if (defined ($p->opts->SPonly) and ($p->opts->SPonly == 1)) {
  $result = OK;
} else {
  foreach my $ip_to (@to_proxy) {
    my @connection_status = split( /\s+/, $ip_to );
    #print Dumper $ip_to;
    #print Dumper @connection_status;
    #print Dumper $connection_status[5];
    if ( $connection_status[5] =~ /ESTABLISHED/ ) {
      $result = OK;
      $res_message .= "Connection to '$ip_addr:$port' is established. ";
      last;
    } else {
      $result = WARNING;
      $res_message .= "Connection to '$ip_addr:$port' is in state: ".$connection_status[5].". ";
    }
  }
};

$res_message .= "No connection to '$ip_addr:$port.' " if $result eq CRITICAL;


my $result2 = CRITICAL;

if (defined ($p->opts->IdPonly) and ($p->opts->IdPonly == 1)) {
    $result2 = OK;
} else {
    foreach my $from_ip (@from_proxy) {
	my @connection_status = split( /\s+/, $from_ip );
	if ($connection_status[5] =~ /ESTABLISHED/ ) {
	    $result2 = OK;
	    $res_message .= "Connection from server $ip_addr is established. ";
	    last;
	} else {
	    $result2 = WARNING; 
	    $res_message .= "Connection from server $ip_addr is in state: ".$connection_status[5].". ";
	}
    }
};

$res_message .= "No connection from server $ip_addr. " if $result2 eq CRITICAL;

# decision logic
my $final_result;
if (($result eq CRITICAL) || ($result2 == CRITICAL )) {
  $final_result = CRITICAL;
} elsif (($result eq OK) && ($result2 == OK)) {
  $final_result = OK;
} else {
  $final_result = WARNING;
}

# return result
$p->nagios_exit( 
	 return_code => $final_result, 
	 message => $res_message 
);

