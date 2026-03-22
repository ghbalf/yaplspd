#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/../lib";

use YAPLSPD::Completion;
use YAPLSPD::Document;

# Test completion functionality
my $completion = YAPLSPD::Completion->new();
my $doc = YAPLSPD::Document->new(
    uri => 'file:///test.pl',
    text => "#!/usr/bin/perl\nuse strict;\nmy \$var = \"test\";\nwhile (1) {\n    prin",
    version => 1
);

# Test basic keyword completion
my $position = { line => 4, character => 8 };  # After "prin"
my $completions = $completion->complete($doc, $position);

ok(scalar @$completions > 0, 'Should return completions');
my @print_completions = grep { $_->{label} eq 'print' } @$completions;
ok(scalar @print_completions > 0, 'Should include "print" completion');

# Test if completion includes "while" keyword
$position = { line => 3, character => 0 };
$completions = $completion->complete($doc, $position);
my @while_completions = grep { $_->{label} eq 'while' } @$completions;
ok(scalar @while_completions > 0, 'Should include "while" completion');

done_testing();