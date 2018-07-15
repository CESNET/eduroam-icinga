#!/usr/bin/perl -w

use strict;
use Data::Dumper;
use Storable;
use Monitoring::Plugin;
use Monitoring::Plugin::Functions;
use File::Basename;

#apt-get install libnagios-plugin-perl

my $eapol_test = '/usr/lib/nagios/plugins/rad_eap_test';

my $np = Monitoring::Plugin->new(
    usage => "Usage: %s -H <hostname> -P <port> -S <secret> -u <username> -p <password> -M",
    plugin => lc basename $0, '.pl',
    shortname => lc basename $0, '.pl',
    );

$np->add_arg(
    spec => 'hostname|H=s',
    help => '-H, --hostname=STRING',
    required => 1,
    );

$np->add_arg(
    spec => 'port|P=s',
    help => '-P, --port=STRING',
    required => 1,
    );

$np->add_arg(
    spec => 'secret|S=s',
    help => '-S, --secret=STRING',
    required => 1,
    );

$np->add_arg(
    spec => 'username|u=s',
    help => '-u, --username=STRING',
    required => 1,
    );

$np->add_arg(
    spec => 'password|p=s',
    help => '-p, --password=STRING',
    required => 1,
    );

$np->add_arg(
    spec => 'MAC|M=s',
    help => '-M, --MAC=STRING',
    required => 1,
    );


$np->getopts;

my $cmd = sprintf("%s -H %s -P %s -S %s -u '%s' -p '%s' -e PEAP -m WPA-EAP -i 'CUI test' -t 50 -O 1ermon.cesnet.cz -C -v",
		  $eapol_test,
		  $np->opts->hostname,
		  $np->opts->port,
		  $np->opts->secret,
		  $np->opts->username,
		  $np->opts->password,
		  $np->opts->MAC);

open(IN, "$cmd |")
    or  $np->nagios_exit(UNKNOWN, "Failed to exec $eapol_test: $!");

my $first_line = '';
my $CUI = '';
while (my $line=<IN>) {
    chomp($first_line);
    $first_line = $line if ($first_line eq '');
    if ($line =~ /Attribute 89 \(Chargeable-User-Identity\)/) {
	$CUI = <IN>;
	chomp($CUI);
	$CUI =~ s/.*://;
	$CUI =~ s/[ ']//g;
    };
};

if ($first_line =~ /access-accept/) {
    if (length($CUI) > 5) {
	$np->nagios_exit(OK, "$first_line; CUI=$CUI");
    } else {
	$np->nagios_exit(CRITICAL, "$first_line; CUI=MISSING");	
    };
} else {
    $np->nagios_exit(CRITICAL, "Failed to get Access-Accept: rad_eap_test output: $first_line");
};
