#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/../lib";
use lib "$FindBin::Bin/../local/lib/perl5";

BEGIN {
    eval { require PPI; };
    if ($@) {
        plan skip_all => 'PPI not available for testing';
        exit 0;
    }
}

use YAPLSPD::Document;

# Test basic document creation
my $doc = YAPLSPD::Document->new(
    uri => 'file:///test.pl',
    text => "my \$test = 42;\nsub hello { return \"world\"; }",
    version => 1
);

ok($doc, 'Document created');
is($doc->uri, 'file:///test.pl', 'URI correct');
is($doc->text, "my \$test = 42;\nsub hello { return \"world\"; }", 'Text correct');

# Test subroutine detection
my $subs = $doc->subroutines;
is(ref $subs, 'ARRAY', 'subroutines returns arrayref');

# Test variable detection
my $vars = $doc->variables;
is(ref $vars, 'ARRAY', 'variables returns arrayref');

# Test text changes
$doc->text("my \$newvar = 'changed';");
is($doc->text, "my \$newvar = 'changed';", 'Text updated');

# Test line access
my $line = $doc->get_line(0);
is($line, "my \$newvar = 'changed';", 'Line access correct');

done_testing();