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

if (defined($hosts->{$np->opts->host})) {
    my $host = $hosts->{$np->opts->host};
    my $result = OK;
    my @msg;
    if (defined($host->{'not_sending'})) {
	$result = CRITICAL;
	push @msg, 'Requests without Operator-Name='.$host->{'not_sending'};
    };
    if (defined($host->{'OperatorName'})) {
	my $invalid = 0;
	foreach my $on (keys %{$host->{'OperatorName'}}) {
	    unless ($on =~ /^[a-zA-Z0-9\.\-]+$/) {
		$invalid++;
		$result = CRITICAL;
		push @msg, "Operator-Name=$on - contains invalid characters";
	    };
	};
	push(@msg, 'Seen Operator-Names: '.join(', ', keys %{$host->{'OperatorName'}})) unless ($invalid);
    };
    
    $np->nagios_exit($result, join('; ', @msg));
} else {
    $np->nagios_exit(WARNING, "Host ".$np->opts->host." didn't sent any request to NREN RADIUS");
};
