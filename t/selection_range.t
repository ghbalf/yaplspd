use strict;
use warnings;
use Test::More tests => 12;
use lib 'lib';

use YAPLSPD::SelectionRange;
use YAPLSPD::Document;

my $selection_range = YAPLSPD::SelectionRange->new();
ok($selection_range, 'Created SelectionRange instance');

# Test word selection
my $doc1 = YAPLSPD::Document->new(
    uri => 'file:///test1.pl',
    text => "my \$foo = 1;\n",
);

my $ranges1 = $selection_range->get_selection_ranges($doc1, [{ line => 0, character => 5 }]);
ok($ranges1, 'Got selection ranges');
is(scalar(@$ranges1), 1, 'Got one selection range set');
ok($ranges1->[0]{range}, 'Has range');
is($ranges1->[0]{range}{start}{line}, 0, 'Starts at line 0');

# Test parent chain
my $doc2 = YAPLSPD::Document->new(
    uri => 'file:///test2.pl',
    text => "sub foo {\n    my \$x = 1;\n}\n",
);

my $ranges2 = $selection_range->get_selection_ranges($doc2, [{ line => 1, character => 8 }]);
ok($ranges2, 'Got selection ranges for line in sub');

# Check that there's a chain
my $r = $ranges2->[0];
my $chain_length = 1;
while ($r->{parent}) {
    $r = $r->{parent};
    $chain_length++;
}
cmp_ok($chain_length, '>=', 3, 'Has parent chain of at least 3 levels');

# Test multiple positions
my $ranges3 = $selection_range->get_selection_ranges($doc2, [
    { line => 0, character => 5 },
    { line => 1, character => 8 },
]);
is(scalar(@$ranges3), 2, 'Got ranges for 2 positions');

# Test subroutine range
my $sub_range = $selection_range->get_selection_ranges($doc2, [{ line => 0, character => 5 }]);
ok($sub_range, 'Got sub range');

# Find the largest range (subroutine)
$r = $sub_range->[0];
my $largest_range;
while ($r) {
    $largest_range = $r->{range};
    $r = $r->{parent};
}
ok($largest_range, 'Found largest range');
is($largest_range->{start}{line}, 0, 'Sub starts at line 0');
cmp_ok($largest_range->{end}{line}, '>=', 1, 'Sub ends at line >= 1');

print "SelectionRange tests passed!\n";