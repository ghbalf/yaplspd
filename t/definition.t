#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use lib 'lib';
use YAPLSPD::Definition;
use YAPLSPD::Document;

# Test setup
my $perl_code = <<'PERL';
sub hello {
    print "Hello, World!";
}

sub world {
    hello();
}
PERL

my $doc = YAPLSPD::Document->new(text => $perl_code);
my $definition = YAPLSPD::Definition->new();

# Test finding definition of 'hello'
my $result = $definition->find_definition($doc, {line => 5, character => 5});  # Position on 'hello()'

ok($result, 'Found definition');
is($result->{range}{start}{line}, 0, 'Correct line');
is($result->{range}{start}{character}, 4, 'Correct character position');
is($result->{range}{end}{character}, 9, 'Correct end position');

# Test non-existent subroutine
$result = $definition->find_definition($doc, {line => 4, character => 10});
is($result, undef, 'No definition for non-existent sub');

done_testing;