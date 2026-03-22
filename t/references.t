#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use lib 'lib';

use YAPLSPD::References;
use YAPLSPD::Document;

subtest 'References - subroutine calls' => sub {
    my $references = YAPLSPD::References->new();
    
    my $code = <<'PERL';
sub hello {
    print "Hello";
}

sub world {
    hello();
    hello();
}

hello();
PERL

    my $doc = YAPLSPD::Document->new(text => $code);
    
    # Find references to 'hello' subroutine
    my $refs = $references->find_references($doc, {line => 0, character => 4});
    
    is scalar(@$refs), 3, 'Found 3 references to hello subroutine';
    
    # Check the line numbers (0-based in LSP range)
    my @lines = map { $_->{range}{start}{line} } @$refs;
    is_deeply [sort @lines], [5, 6, 9], 'References on correct lines';
};

subtest 'References - no matches' => sub {
    my $references = YAPLSPD::References->new();
    
    my $code = <<'PERL';
sub test {
    return 42;
}

some_other_function();
PERL

    my $doc = YAPLSPD::Document->new(text => $code);
    
    my $refs = $references->find_references($doc, {line => 0, character => 4});
    is scalar(@$refs), 0, 'No references for non-existent function';
};

subtest 'References - mixed calls' => sub {
    my $references = YAPLSPD::References->new();
    
    my $code = <<'PERL';
sub calculate {
    my ($x, $y) = @_;
    return $x + $y;
}

my $result = calculate(5, 3);
if (calculate(10, 20) > 20) {
    calculate(1, 1);
}
PERL

    my $doc = YAPLSPD::Document->new(text => $code);
    
    my $refs = $references->find_references($doc, {line => 0, character => 4});
    
    is scalar(@$refs), 3, 'Found 3 references to calculate subroutine';
};

done_testing();