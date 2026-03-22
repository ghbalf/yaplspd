use strict;
use warnings;
use Test::More;
use lib 'lib';

plan tests => 11;

use YAPLSPD::FoldingRange;
use YAPLSPD::Document;

my $folding_range = YAPLSPD::FoldingRange->new();
ok($folding_range, 'Created FoldingRange instance');

# Test subroutine folding
my $doc1 = YAPLSPD::Document->new(
    uri => 'file:///test1.pl',
    text => "sub foo {\n    my \$x = 1;\n    print \$x;\n}\n",
);

my $ranges1 = $folding_range->get_folding_ranges($doc1);
ok($ranges1, 'Got folding ranges');
my @sub_ranges = grep { $_->{kind} && $_->{kind} eq 'subroutine' } @$ranges1;
is(scalar(@sub_ranges), 1, 'Found 1 subroutine folding range');
is($sub_ranges[0]{startLine}, 0, 'Subroutine starts at line 0');
is($sub_ranges[0]{endLine}, 3, 'Subroutine ends at line 3');

# Test POD folding
my $doc2 = YAPLSPD::Document->new(
    uri => 'file:///test2.pl',
    text => "=head1 NAME\n\nTest Module\n\n=cut\n\nsub bar {}\n",
);

my $ranges2 = $folding_range->get_folding_ranges($doc2);
my @pod_ranges = grep { $_->{kind} && $_->{kind} eq 'comment' } @$ranges2;
is(scalar(@pod_ranges), 1, 'Found 1 POD folding range');
is($pod_ranges[0]{startLine}, 0, 'POD starts at line 0');
is($pod_ranges[0]{endLine}, 4, 'POD ends at line 4');

# Test import block folding
my $doc3 = YAPLSPD::Document->new(
    uri => 'file:///test3.pl',
    text => "use strict;\nuse warnings;\nuse Data::Dumper;\n\nsub baz {}\n",
);

my $ranges3 = $folding_range->get_folding_ranges($doc3);
my @import_ranges = grep { $_->{kind} && $_->{kind} eq 'imports' } @$ranges3;
is(scalar(@import_ranges), 1, 'Found 1 import folding range');
is($import_ranges[0]{startLine}, 0, 'Imports start at line 0');
is($import_ranges[0]{endLine}, 2, 'Imports end at line 2');

print "FoldingRange tests passed!\n";