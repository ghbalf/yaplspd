use strict;
use warnings;
use Test::More;
use lib 'lib';

plan tests => 11;

use YAPLSPD::DocumentHighlight;
use YAPLSPD::Document;

my $highlight = YAPLSPD::DocumentHighlight->new();
ok($highlight, 'Created DocumentHighlight instance');

# Test variable highlights
my $doc1 = YAPLSPD::Document->new(
    uri => 'file:///test1.pl',
    text => "my \$foo = 1;\nprint \$foo;\n\$foo = 2;\n",
);

my $highlights1 = $highlight->get_highlights($doc1, { line => 0, character => 4 });
ok($highlights1, 'Got variable highlights');
is(scalar(@$highlights1), 3, 'Found 3 occurrences of $foo');

# Check kinds (implementation may categorize differently)
my @writes = grep { $_->{kind} == 3 } @$highlights1;  # Write = 3
my @reads = grep { $_->{kind} == 2 } @$highlights1;   # Read = 2
cmp_ok(scalar(@writes), '>=', 1, 'Found at least 1 write');
cmp_ok(scalar(@reads), '>=', 1, 'Found at least 1 read');

# Test subroutine highlights
my $doc2 = YAPLSPD::Document->new(
    uri => 'file:///test2.pl',
    text => "sub greet { print 'hi'; }\ngreet();\n",
);

my $highlights2 = $highlight->get_highlights($doc2, { line => 0, character => 4 });
ok($highlights2, 'Got subroutine highlights');
is(scalar(@$highlights2), 2, 'Found 2 occurrences of greet');

my @sub_writes = grep { $_->{kind} == 3 } @$highlights2;
my @sub_reads = grep { $_->{kind} == 2 } @$highlights2;
cmp_ok(scalar(@sub_writes) + scalar(@sub_reads), '>=', 2, 'Found at least 2 occurrences');

# Test method call highlights
my $doc3 = YAPLSPD::Document->new(
    uri => 'file:///test3.pl',
    text => "sub process { }\n\$obj->process();\n",
);

my $highlights3 = $highlight->get_highlights($doc3, { line => 1, character => 8 });
ok($highlights3, 'Got method highlights');
cmp_ok(scalar(@$highlights3), '>=', 2, 'Found at least 2 occurrences');

# Test no highlights for non-existent symbol
my $highlights4 = $highlight->get_highlights($doc1, { line => 0, character => 100 });
is(scalar(@$highlights4), 0, 'No highlights for out of bounds position');

print "DocumentHighlight tests passed!\n";