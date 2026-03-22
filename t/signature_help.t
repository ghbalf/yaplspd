use strict;
use warnings;
use Test::More tests => 11;
use lib 'lib';

use YAPLSPD::SignatureHelp;
use YAPLSPD::Document;

my $signature_help = YAPLSPD::SignatureHelp->new();
ok($signature_help, 'Created SignatureHelp instance');

# Test builtin function signature
my $doc1 = YAPLSPD::Document->new(
    uri => 'file:///test1.pl',
    text => "my \$result = substr(\$str, 0, 5);\n",
);

my $result1 = $signature_help->get_signature_help($doc1, { line => 0, character => 25 });
ok($result1, 'Got signature help for builtin');
is($result1->{activeSignature}, 0, 'Active signature is 0');
ok($result1->{signatures}[0]{label}, 'Has signature label');
like($result1->{signatures}[0]{label}, qr/substr/, 'Label contains function name');

# Test active parameter counting
my $doc2 = YAPLSPD::Document->new(
    uri => 'file:///test2.pl',
    text => "my \$result = substr(\$str, 0);\n",
);

my $result2 = $signature_help->get_signature_help($doc2, { line => 0, character => 26 });
cmp_ok($result2->{activeParameter}, '>=', 1, 'Active parameter is at least 1');

# Test user-defined subroutine signature
my $doc3 = YAPLSPD::Document->new(
    uri => 'file:///test3.pl',
    text => "sub my_func { my (\$x, \$y) = @_; return \$x + \$y; }\nmy_func(1, 2);\n",
);

my $result3 = $signature_help->get_signature_help($doc3, { line => 1, character => 10 });
ok($result3, 'Got signature help for user sub');
like($result3->{signatures}[0]{label}, qr/my_func/, 'Label contains sub name');

# Test with modern signature syntax
my $doc4 = YAPLSPD::Document->new(
    uri => 'file:///test4.pl',
    text => "sub modern(\$a, \$b, \$c) { return \$a + \$b + \$c; }\nmodern(1, 2);\n",
);

my $result4 = $signature_help->get_signature_help($doc4, { line => 1, character => 10 });
ok($result4, 'Got signature help for modern sig syntax');
like($result4->{signatures}[0]{label}, qr/modern\(/, 'Label shows modern signature');

# Test no signature found
my $doc5 = YAPLSPD::Document->new(
    uri => 'file:///test5.pl',
    text => "my \$x = 5;\n",
);

my $result5 = $signature_help->get_signature_help($doc5, { line => 0, character => 5 });
is($result5, undef, 'No signature help when not in function call');

print "SignatureHelp tests passed!\n";