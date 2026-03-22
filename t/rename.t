use strict;
use warnings;
use Test::More;
use lib 'lib';

plan tests => 9;

use YAPLSPD::Rename;
use YAPLSPD::Document;

my $rename = YAPLSPD::Rename->new();
ok($rename, 'Created Rename instance');

# Test subroutine renaming
my $doc1 = YAPLSPD::Document->new(
    uri => 'file:///test1.pl',
    text => "sub greet { print 'Hello'; }\ngreet();\n",
);

my $result1 = $rename->rename($doc1, { line => 1, character => 0 }, 'say_hello');
ok($result1, 'Got rename result for subroutine');
ok($result1->{changes}, 'Has changes');
my @changes1 = @{$result1->{changes}{$doc1->uri}};
cmp_ok(scalar(@changes1), '>=', 2, 'Found at least 2 occurrences');

# Test variable renaming
my $doc2 = YAPLSPD::Document->new(
    uri => 'file:///test2.pl',
    text => "my \$foo = 1;\nprint \$foo;\n",
);

my $result2 = $rename->rename($doc2, { line => 0, character => 4 }, 'bar');
ok($result2, 'Got rename result for variable');
my @changes2 = @{$result2->{changes}{$doc2->uri}};
cmp_ok(scalar(@changes2), '>=', 2, 'Found at least 2 occurrences of variable');

# Test unknown symbol
my $doc3 = YAPLSPD::Document->new(
    uri => 'file:///test3.pl',
    text => "my \$x = 5;\n",
);

my $result3 = $rename->rename($doc3, { line => 0, character => 50 }, 'y');
is($result3, undef, 'No rename result for out of bounds position');

# Test package renaming
my $doc4 = YAPLSPD::Document->new(
    uri => 'file:///test4.pl',
    text => "package MyPackage;\nsub foo {}\npackage main;\nuse MyPackage;\n",
);

my $result4 = $rename->rename($doc4, { line => 0, character => 10 }, 'NewPackage');
ok($result4, 'Got rename result for package');
my @changes4 = @{$result4->{changes}{$doc4->uri}};
cmp_ok(scalar(@changes4), '>=', 2, 'Found package declarations and usages');

print "Rename tests passed!\n";