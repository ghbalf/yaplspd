use strict;
use warnings;
use Test::More;
use lib 'lib';

plan tests => 8;

use YAPLSPD::CodeLens;
use YAPLSPD::Document;

my $code_lens = YAPLSPD::CodeLens->new();
ok($code_lens, 'Created CodeLens instance');

# Test subroutine reference count lens
my $doc1 = YAPLSPD::Document->new(
    uri => 'file:///test1.pl',
    text => "sub foo {\n    return 1;\n}\nprint foo();\n",
);

my $lenses1 = $code_lens->get_code_lenses($doc1);
ok($lenses1, 'Got code lenses');
my @ref_lenses = grep { $_->{command}{title} && $_->{command}{title} =~ /reference/ } @$lenses1;
is(scalar(@ref_lenses), 1, 'Found 1 reference lens');
like($ref_lenses[0]{command}{title}, qr/\d+ reference/, 'Reference count shown');

# Test TODO lens
my $doc2 = YAPLSPD::Document->new(
    uri => 'file:///test2.pl',
    text => "sub bar { }\n# TODO: fix this\n",
);

my $lenses2 = $code_lens->get_code_lenses($doc2);
my @todo_lenses = grep { $_->{command}{title} && $_->{command}{title} =~ /TODO/ } @$lenses2;
is(scalar(@todo_lenses), 1, 'Found 1 TODO lens');
like($todo_lenses[0]{command}{title}, qr/⚠ TODO/, 'TODO warning shown');

# Test test function run lens
my $doc3 = YAPLSPD::Document->new(
    uri => 'file:///test3.pl',
    text => "sub test_foo {\n    ok(1);\n}\n",
);

my $lenses3 = $code_lens->get_code_lenses($doc3);
my @test_lenses = grep { $_->{command}{title} && $_->{command}{title} =~ /Run Test/ } @$lenses3;
is(scalar(@test_lenses), 1, 'Found 1 test run lens');

# Test FIXME lens
my $doc4 = YAPLSPD::Document->new(
    uri => 'file:///test4.pl',
    text => "# FIXME: hack\n",
);

my $lenses4 = $code_lens->get_code_lenses($doc4);
my @fixme_lenses = grep { $_->{command}{title} && $_->{command}{title} =~ /FIXME/ } @$lenses4;
is(scalar(@fixme_lenses), 1, 'Found 1 FIXME lens') if @$lenses4;

print "CodeLens tests passed!\n";