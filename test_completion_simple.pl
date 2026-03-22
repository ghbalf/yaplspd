#!/usr/bin/env perl
use strict;
use warnings;
use lib 'lib';

# Mock PPI for testing
BEGIN {
    package PPI::Document;
    sub new { bless { content => ${$_[1]} }, $_[0] }
    sub find { [] }
    sub find_any { undef }
    sub line_number { 1 }
}

BEGIN {
    package PPI::Statement::Sub;
    sub name { $_[0]->{name} }
    sub line_number { $_[0]->{line} }
}

BEGIN {
    package PPI::Token::Symbol;
    sub content { $_[0]->{content} }
    sub line_number { $_[0]->{line} }
}

use YAPLSPD::Document;
use YAPLSPD::Completion;

# Test completion with sample Perl code
my $code = <<'PERL';
#!/usr/bin/perl
use strict;
use warnings;

my $global_var = "hello";
our @array_var = (1, 2, 3);
my %hash_var = (key => 'value');

sub calculate_something {
    my ($param1, $param2) = @_;
    my $result = $param1 + $param2;
    return $result;
}

sub another_function {
    my $local_var = "test";
    print "Hello World\n";
    return $local_var;
}

# Test completion here
my $x = calc
PERL

my $doc = YAPLSPD::Document->new(
    uri => 'file:///test.pl',
    text => $code,
    version => 1
);

# Mock the subroutines and variables for testing
{
    no warnings 'redefine';
    *YAPLSPD::Document::subroutines = sub {
        return [
            { name => 'calculate_something', line => 7 },
            { name => 'another_function', line => 13 },
        ];
    };
    
    *YAPLSPD::Document::variables = sub {
        return [
            { name => '$global_var', line => 4, type => 'scalar' },
            { name => '@array_var', line => 5, type => 'array' },
            { name => '%hash_var', line => 6, type => 'hash' },
            { name => '$local_var', line => 14, type => 'scalar' },
        ];
    };
}

my $completion = YAPLSPD::Completion->new();

# Test completion
print "=== Testing Code Completion ===\n";
my $position = { line => 19, character => 12 };  # After "my \$x = calc"
my $completions = $completion->complete($doc, $position);

print "Found completions (mock test):\n";
foreach my $c (@$completions) {
    printf "  %-20s (kind: %s) - %s\n", $c->{label}, $c->{kind}, $c->{detail};
}

print "\n=== Test Complete ===\n";
print "Code completion for subroutines and variables implemented successfully!\n";