#!/usr/bin/perl -w

use strict;
use Data::Dumper;
use Storable;
use Monitoring::Plugin;
use Monitoring::Plugin::Functions;
use File::Basename;

#apt-get install libnagios-plugin-perl

my $np = Monitoring::Plugin->new(
    usage => "Usage: %s -F <filename> -H <host>",
    plugin => lc basename $0, '.pl',
    shortname => lc basename $0, '.pl',
    );

$np->add_arg(
    spec => 'filename|F=s',
    help => '-F, --filename=STRING',
    required => 1,
    );

$np->add_arg(
    spec => 'host|H=s',
    help => '-H, --host=STRING',
    required => 1,
    );

$np->getopts;

my $hosts;

eval {
    $hosts = retrieve($np->opts->filename);
};
$np->nagios_exit(UNKNOWN, "Failed to read ".$np->opts->filename.": $!") if ($@);

my $result = OK;
my @msg;
if (defined($hosts->{$np->opts->host})) {
    my $host = $hosts->{$np->opts->host};
    if (defined($host->{'csi_not_sending'})) {
	$result = CRITICAL;
	push @msg, sprintf('Requests without Calling-Station-Id: %d, with: %d', 
			   $host->{'csi_not_sending'} || 0,
			   $host->{'csi_sending'} || 0);
    } elsif (defined($host->{'csi_sending'})) {
	$result = OK;
	push @msg, sprintf('Requests with Calling-Station-Id: %d', 
			   $host->{'csi_sending'} || 0);
    } else{
	$result = WARNING;
	push @msg, "Host ".$np->opts->host." didn't sent any access-request to NREN RADIUS, is it alive?"
    };
} else {
    $result = WARNING;
    push @msg, "Host ".$np->opts->host." didn't sent any access-request to NREN RADIUS, is it alive?"
};

$np->nagios_exit($result, join('; ', @msg));
