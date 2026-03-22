#!/usr/bin/env perl
use strict;
use warnings;
use lib 'lib';

use YAPLSPD::Document;
use YAPLSPD::Hover;

# Test document with various Perl constructs
my $test_code = <<'PERL';
#!/usr/bin/env perl
use strict;
use warnings;

my $scalar_var = "hello";
our @array_var = (1, 2, 3);
local %hash_var = (key => 'value');

sub greet {
    my ($name) = @_;
    return "Hello, $name!";
}

sub calculate {
    my ($x, $y) = @_;
    return $x + $y;
}

sub simple_sub {
    print "This is simple\n";
}

# Usage
my $result = calculate(5, 3);
my $greeting = greet("World");
simple_sub();

print $scalar_var;
PERL

# Create document
my $doc = YAPLSPD::Document->new(
    uri => 'file:///test.pl',
    text => $test_code,
    version => 1
);

# Create hover handler
my $hover = YAPLSPD::Hover->new();

# Test cases
my @test_cases = (
    # [line, character, expected_type, expected_name]
    [6, 5, 'subroutine', 'greet'],
    [7, 10, 'subroutine', 'greet'],
    [11, 5, 'subroutine', 'calculate'],
    [19, 5, 'subroutine', 'simple_sub'],
    [22, 15, 'subroutine', 'calculate'],
    [4, 5, 'variable', '$scalar_var'],
    [5, 6, 'variable', '@array_var'],
    [6, 8, 'variable', '%hash_var'],
    [23, 20, 'variable', '$scalar_var'],
    [1, 2, 'keyword', 'my'],
    [2, 2, 'keyword', 'our'],
    [3, 2, 'keyword', 'local'],
);

print "Testing hover functionality...\n\n";

foreach my $test (@test_cases) {
    my ($line, $char, $expected_type, $expected_name) = @$test;
    
    print "Testing hover at line $line, char $char... ";
    
    my $hover_info = $hover->get_hover_info($doc, { line => $line, character => $char });
    
    if ($hover_info) {
        if ($hover_info->{label} eq $expected_name) {
            print "PASS - Found $expected_type '$expected_name'\n";
            print "  Detail: $hover_info->{detail}\n" if $hover_info->{detail};
        } else {
            print "FAIL - Expected '$expected_name', got '$hover_info->{label}'\n";
        }
    } else {
        print "SKIP - No hover info (expected for some cases)\n";
    }
}

print "\nTesting edge cases...\n";

# Test edge cases
my $edge_cases = [
    [100, 0],  # Out of bounds line
    [0, 100],  # Out of bounds character
    [5, 0],    # Empty position
];

foreach my $edge (@$edge_cases) {
    my ($line, $char) = @$edge;
    my $info = $hover->get_hover_info($doc, { line => $line, character => $char });
    print "Edge case [$line,$char]: " . ($info ? "Found '$info->{label}'" : "No info") . "\n";
}

print "\nHover test completed!\n";

# Test the actual hover data structure
print "\nDetailed hover info for 'calculate' subroutine:\n";
my $calc_hover = $hover->get_hover_info($doc, { line => 11, character => 5 });
if ($calc_hover) {
    print "Label: $calc_hover->{label}\n";
    print "Kind: $calc_hover->{kind}\n";
    print "Detail: $calc_hover->{detail}\n";
    print "Documentation: $calc_hover->{documentation}{value}\n";
}

print "\nDetailed hover info for '$scalar_var' variable:\n";
my $var_hover = $hover->get_hover_info($doc, { line => 4, character => 5 });
if ($var_hover) {
    print "Label: $var_hover->{label}\n";
    print "Kind: $var_hover->{kind}\n";
    print "Detail: $var_hover->{detail}\n";
    print "Documentation: $var_hover->{documentation}{value}\n";
}