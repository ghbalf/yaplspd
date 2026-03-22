use strict;
use warnings;
use Test::More;
use lib 'lib';

use YAPLSPD::WorkspaceSymbol;
use YAPLSPD::Document;

plan tests => 14;

my $workspace_symbol = YAPLSPD::WorkspaceSymbol->new();
ok($workspace_symbol, 'Created WorkspaceSymbol instance');

# Create mock documents hash
my $doc1 = YAPLSPD::Document->new(
    uri => 'file:///test1.pl',
    text => "package Foo;\nsub bar { }\nsub baz { }\n",
);

my $doc2 = YAPLSPD::Document->new(
    uri => 'file:///test2.pl',
    text => "package Bar;\nsub qux { }\nuse constant PI => 3.14;\n",
);

my $documents = {
    'file:///test1.pl' => $doc1,
    'file:///test2.pl' => $doc2,
};

# Test all symbols
my $symbols1 = $workspace_symbol->get_workspace_symbols($documents, '');
ok($symbols1, 'Got workspace symbols');
cmp_ok(scalar(@$symbols1), '>=', 5, 'Found at least 5 symbols');

# Check for packages
my @packages = grep { $_->{kind} == 4 } @$symbols1;  # Package = 4
is(scalar(@packages), 2, 'Found 2 packages');

# Check for functions
my @functions = grep { $_->{kind} == 12 } @$symbols1;  # Function = 12
is(scalar(@functions), 3, 'Found 3 functions');

# Check for constants
my @constants = grep { $_->{kind} == 14 } @$symbols1;  # Constant = 14
is(scalar(@constants), 1, 'Found 1 constant');

# Test query filtering (may find multiple matches due to full_name search)
my $symbols2 = $workspace_symbol->get_workspace_symbols($documents, 'bar');
ok($symbols2, 'Got filtered symbols');
cmp_ok(scalar(@$symbols2), '>=', 1, 'Found at least 1 symbol matching "bar"');

# Test case-insensitive query
my $symbols3 = $workspace_symbol->get_workspace_symbols($documents, 'BAR');
cmp_ok(scalar(@$symbols3), '>=', 1, 'Case-insensitive match works');

# Test partial query
my $symbols4 = $workspace_symbol->get_workspace_symbols($documents, 'ba');
cmp_ok(scalar(@$symbols4), '>=', 1, 'Partial match finds symbols');

# Test container names
my @with_container = grep { $_->{containerName} } @$symbols1;
cmp_ok(scalar(@with_container), '>=', 3, 'Some symbols have container names');

# Test locations
ok($symbols1->[0]{location}, 'Has location');
ok($symbols1->[0]{location}{uri}, 'Has URI');
ok($symbols1->[0]{location}{range}, 'Has range');

print "WorkspaceSymbol tests passed!\n";