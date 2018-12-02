#!/usr/bin/perl -w

use strict;

my $template = '"70:6f:6c:6%x:%.2x:%.2x"';
my @mac;

foreach my $o4 (9..0xf) {
    foreach my $o5 (0..0xff) {
        foreach my $o6 (0..0xff) {
            push @mac, sprintf($template, $o4, $o5, $o6);
        };
    };
};

print "const mac_address = [
".join(",\n", @mac)."
]\n";
