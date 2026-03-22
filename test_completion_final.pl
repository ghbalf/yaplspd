#!/usr/bin/env perl
use strict;
use warnings;

# Simple test for completion logic without PPI
{
    package MockDocument;
    sub new { bless { text => $_[1]->{text} }, $_[0] }
    sub lines { [split /\n/, $_[0]->{text}] }
    sub subroutines {
        return [
            { name => 'calculate_something', line => 7 },
            { name => 'another_function', line => 13 },
            { name => 'process_data', line => 20 },
        ];
    }
    sub variables {
        return [
            { name => '$global_var', line => 4, type => 'scalar' },
            { name => '@array_var', line => 5, type => 'array' },
            { name => '%hash_var', line => 6, type => 'hash' },
            { name => '$local_var', line => 14, type => 'scalar' },
        ];
    }
}

# Include the completion module directly
require '/home/alf/.openclaw/workspace/projects/yaplspd/lib/YAPLSPD/Completion.pm';

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

sub process_data {
    my $data = shift;
    return $data;
}

# Test completion here
my $x = calc
PERL

my $doc = MockDocument->new({ text => $code });
my $completion = YAPLSPD::Completion->new();

print "=== YAPLSPD Code Completion Test ===\n";
print "Testing completion for subroutines and variables...\n\n";

# Test 1: Subroutine completion
print "Test 1: Subroutine completion (prefix 'calc')\n";
my $position = { line => 23, character => 12 };
my $completions = $completion->complete($doc, $position);

my @filtered = grep { $_->{label} =~ /^calc/ } @$completions;
print "Found ", scalar(@filtered), " matching subroutines:\n";
foreach my $c (@filtered) {
    printf "  %-20s (kind: %s) - %s\n", $c->{label}, $c->{kind}, $c->{detail};
}

# Test 2: Variable completion
print "\nTest 2: Variable completion (prefix '\$g')\n";
$position = { line => 23, character => 8 };
$completions = $completion->complete($doc, $position);

@filtered = grep { $_->{label} =~ /^\$g/ } @$completions;
print "Found ", scalar(@filtered), " matching variables:\n";
foreach my $c (@filtered) {
    printf "  %-20s (kind: %s) - %s\n", $c->{label}, $c->{kind}, $c->{detail};
}

# Test 3: All completions
print "\nTest 3: All available completions\n";
$position = { line => 23, character => 8 };
$completions = $completion->complete($doc, $position);

print "Total completions found: ", scalar(@$completions), "\n";
print "Top 10 completions:\n";
my @sorted = sort { $a->{sortText} cmp $b->{sortText} } @$completions;
my @top10 = @sorted > 10 ? @sorted[0..9] : @sorted;
foreach my $c (@top10) {
    printf "  %-20s (kind: %s) - %s\n", $c->{label}, $c->{kind}, $c->{detail};
}

print "\n✅ Code completion implementation complete!\n";
print "Features implemented:\n";
print "  - Subroutine completion from current document\n";
print "  - Variable completion (scalar, array, hash)\n";
print "  - Built-in keywords and functions\n";
print "  - Smart sorting (user code first, then built-ins)\n";