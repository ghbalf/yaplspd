#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use lib 'lib';
use YAPLSPD::Protocol;

# Test protocol message parsing
my $protocol = YAPLSPD::Protocol->new();

# Test basic functionality
ok($protocol, 'Protocol object created');
isa_ok($protocol, 'YAPLSPD::Protocol');

# Note: These are basic smoke tests
# Full testing would require mocking STDIN/STDOUT

done_testing();