#!/usr/bin/perl -w

use strict;
use Data::Dumper;
use Storable;
use Monitoring::Plugin;
use Monitoring::Plugin::Functions;
use File::Basename;

#apt-get install libnagios-plugin-perl

my $np = Monitoring::Plugin->new(
    usage => "Usage: %s -F <filename> -H <host> -R <realm1,realm2,...>",
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

$np->add_arg(
    spec => 'realm|R=s',
    help => '-R, --realm=STRING',
    required => 0,
    );

$np->getopts;

my %realm;
if ($np->opts->realm) {
  %realm = map { $_ => 1 } split(/,/, $np->opts->realm);
  $realm{'ermon.cesnet.cz'} = 1 if (%realm);
};

my $hosts;

eval {
    $hosts = retrieve($np->opts->filename);
};
$np->nagios_exit(UNKNOWN, "Failed to read ".$np->opts->filename.": $!") if ($@);


if (defined($hosts->{$np->opts->host})) {
  my $host = $hosts->{$np->opts->host};
  my $result = OK;
  my @msg;
  if (defined($host->{'on_not_sending'})) {
    $result = CRITICAL;
    push @msg, 'Requests without Operator-Name='.$host->{'on_not_sending'};
  };

  if (defined($host->{'OperatorName'})) {
    my $invalid = 0;
    my @seen_on;
    my @valid_on;
    my @unknown_on;
    foreach my $on (keys %{$host->{'OperatorName'}}) {
      unless ($on =~ /^[a-zA-Z0-9\.\-]+$/) {
	$invalid++;
	$result = CRITICAL;
	push @msg, "INVALID Operator-Name=$on - contains invalid characters";
      } elsif (%realm) {
	my $_on = $on; $_on =~ s/^1//;
	if (exists $realm{$_on}) {
	  push @valid_on, $on.' ('.$host->{'OperatorName'}->{$on}.')';
	} else {
	  $invalid++;
	  $result = CRITICAL;
	  push @unknown_on, $on.' ('.$host->{'OperatorName'}->{$on}.')';
	};
      } else {
	push @seen_on, $on.' ('.$host->{'OperatorName'}->{$on}.')';;
      };
    };
    # this can happen when called without -R
    push(@msg, 'Seen Operator-Names: '.join(', ', @seen_on)) if (@seen_on);
    # those two can happen when called with -R
    push(@msg, 'UNregistered Operator-Names: '.join(', ', @unknown_on)) if (@unknown_on);
    push(@msg, 'Registered Operator-Names: '.join(', ', @valid_on)) if (@valid_on);
  };

  $np->nagios_exit($result, join('; ', @msg));
} else {
  $np->nagios_exit(WARNING, "Host ".$np->opts->host." didn't sent any request to NREN RADIUS");
};
