use strict;
use warnings;
use Test::More;

# Add lib to path
use lib 'lib';
use YAPLSPD::CallHierarchy;

# Simple document mock that doesn't require PPI
{
    package TestDocument;
    sub new {
        my ($class, %args) = @_;
        bless { text => $args{text}, uri => $args{uri} }, $class;
    }
    sub text { shift->{text} }
    sub uri { shift->{uri} }
}

# Create a test document with subroutine calls (no leading newline)
my $test_code = <<'PERL';
sub caller_one {
    my $x = shift;
    return target_func($x);
}

sub caller_two {
    my ($a, $b) = @_;
    my $result = target_func($a);
    return target_func($b) + $result;
}

sub target_func {
    my $val = shift;
    my $internal = helper_func($val);
    return $internal * 2;
}

sub helper_func {
    my $x = shift;
    return $x + 1;
}

sub standalone {
    print "Hello\n";
}
PERL

# Remove leading newline from heredoc
$test_code =~ s/^\n//;

# Debug: print line numbers
my @lines = split(/\n/, $test_code);
for (my $i = 0; $i < @lines; $i++) {
    if ($lines[$i] =~ /^sub (\w+)/) {
        diag "Line $i: sub $1";
    }
}

my $doc = TestDocument->new(
    uri => 'file:///test.pl',
    text => $test_code,
);

my $ch = YAPLSPD::CallHierarchy->new();

# Find actual line numbers
my ($target_line, $helper_line, $standalone_line);
for (my $i = 0; $i < @lines; $i++) {
    $target_line = $i if $lines[$i] =~ /^sub target_func/;
    $helper_line = $i if $lines[$i] =~ /^sub helper_func/;
    $standalone_line = $i if $lines[$i] =~ /^sub standalone/;
}

# Test 1: prepare_call_hierarchy
subtest 'prepare_call_hierarchy' => sub {
    my $items = $ch->prepare_call_hierarchy($doc, { line => $target_line, character => 8 });
    
    is(scalar @$items, 1, 'Found one hierarchy item');
    is($items->[0]{name}, 'target_func', 'Item name is target_func');
    is($items->[0]{kind}, 12, 'Kind is Function (12)');
    is($items->[0]{uri}, 'file:///test.pl', 'URI matches');
};

# Test 2: incoming_calls - who calls target_func
subtest 'incoming_calls' => sub {
    my $item = {
        name => 'target_func',
        kind => 12,
        uri => 'file:///test.pl',
        range => {
            start => { line => $target_line, character => 4 },
            end => { line => $target_line, character => 15 },
        },
    };
    
    my $incoming = $ch->incoming_calls($doc, $item);
    
    is(scalar @$incoming, 2, 'Found 2 callers');
    
    my @caller_names = map { $_->{from}{name} } @$incoming;
    is_deeply([sort @caller_names], ['caller_one', 'caller_two'], 'Callers are caller_one and caller_two');
    
    # Check call counts
    my ($caller_one) = grep { $_->{from}{name} eq 'caller_one' } @$incoming;
    is(scalar @{$caller_one->{fromRanges}}, 1, 'caller_one calls target_func once');
    
    my ($caller_two) = grep { $_->{from}{name} eq 'caller_two' } @$incoming;
    is(scalar @{$caller_two->{fromRanges}}, 2, 'caller_two calls target_func twice');
};

# Test 3: outgoing_calls - what does target_func call
subtest 'outgoing_calls' => sub {
    my $item = {
        name => 'target_func',
        kind => 12,
        uri => 'file:///test.pl',
        range => {
            start => { line => $target_line, character => 4 },
            end => { line => $target_line, character => 15 },
        },
    };
    
    my $outgoing = $ch->outgoing_calls($doc, $item);
    
    is(scalar @$outgoing, 1, 'Found 1 callee');
    is($outgoing->[0]{to}{name}, 'helper_func', 'Callee is helper_func');
    is(scalar @{$outgoing->[0]{fromRanges}}, 1, 'Calls helper_func once');
};

# Test 4: Function with no incoming calls
subtest 'no_incoming_calls' => sub {
    my $item = {
        name => 'standalone',
        kind => 12,
        uri => 'file:///test.pl',
        range => {
            start => { line => $standalone_line, character => 4 },
            end => { line => $standalone_line, character => 14 },
        },
    };
    
    my $incoming = $ch->incoming_calls($doc, $item);
    is(scalar @$incoming, 0, 'standalone has no callers');
};

# Test 5: Function with no outgoing calls
subtest 'no_outgoing_calls' => sub {
    my $item = {
        name => 'helper_func',
        kind => 12,
        uri => 'file:///test.pl',
        range => {
            start => { line => $helper_line, character => 4 },
            end => { line => $helper_line, character => 15 },
        },
    };
    
    my $outgoing = $ch->outgoing_calls($doc, $item);
    is(scalar @$outgoing, 0, 'helper_func has no callees');
};

# Test 6: prepare_call_hierarchy returns empty for non-existent function
subtest 'prepare_nonexistent' => sub {
    my $items = $ch->prepare_call_hierarchy($doc, { line => 0, character => 0 });
    is(scalar @$items, 0, 'No items for non-function position');
};

done_testing();
