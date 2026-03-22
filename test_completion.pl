#!/usr/bin/env perl
use strict;
use warnings;
use lib 'lib';
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

my $completion = YAPLSPD::Completion->new();

# Test completion at different positions
print "=== Testing Subroutine Completion ===\n";
my $position = { line => 12, character => 12 };  # After "my \$x = calc"
my $completions = $completion->complete($doc, $position);

print "Found completions:\n";
foreach my $c (@$completions) {
    printf "  %-20s (%s) - %s\n", $c->{label}, $c->{kind}, $c->{detail};
}

print "\n=== Testing Variable Completion ===\n";
$position = { line => 12, character => 8 };  # After "my "
$completions = $completion->complete($doc, $position);

print "Found completions:\n";
foreach my $c (@$completions) {
    printf "  %-20s (%s) - %s\n", $c->{label}, $c->{kind}, $c->{detail};
}

print "\n=== Document Analysis ===\n";
my $subs = $doc->subroutines;
print "Subroutines found: " . scalar(@$subs) . "\n";
foreach my $sub (@$subs) {
    print "  $sub->{name} at line $sub->{line}\n";
}

my $vars = $doc->variables;
print "Variables found: " . scalar(@$vars) . "\n";
foreach my $var (@$vars) {
    print "  $var->{name} ($var->{type}) at line $var->{line}\n";
}
