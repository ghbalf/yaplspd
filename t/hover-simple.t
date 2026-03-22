#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/../lib";

use YAPLSPD::Hover;

# Test hover functionality
my $hover = YAPLSPD::Hover->new();

# Mock document object
my $doc = bless {
    text => "#!/usr/bin/perl\nuse strict;\nmy \$var = \"test\";\nprint \$var;\n",
}, 'MockDocument';

# Mock document methods
{ 
    package MockDocument; 
    sub lines { [split /\n/, $_[0]->{text}] }
    sub find_subroutine { undef }
    sub find_subroutine_calls { [] }
    sub variables { [] }
    sub uri { 'file:///test.pl' }
    sub get_line { my ($self, $line) = @_; $self->lines->[$line] }
}

# Test basic hover for keywords
my $position = { line => 1, character => 2 };  # On "use"
my $hover_info = $hover->get_hover_info($doc, $position);

ok(defined $hover_info, 'Should return hover info');
if ($hover_info) {
    is($hover_info->{label}, 'use', 'Should identify "use" keyword');
    like($hover_info->{documentation}{value}, qr/Perl Keyword/, 'Should include keyword documentation');
}

# Test hover for built-in functions
$position = { line => 3, character => 2 };  # On "print"
$hover_info = $hover->get_hover_info($doc, $position);

ok(defined $hover_info, 'Should return hover info for built-in');
if ($hover_info) {
    is($hover_info->{label}, 'print', 'Should identify "print" built-in');
    like($hover_info->{documentation}{value}, qr/Perl Built-in/, 'Should include built-in documentation');
}

# Test hover for special variables
$position = { line => 2, character => 4 };  # On "$var"
$hover_info = $hover->get_hover_info($doc, $position);

is($hover_info, undef, 'Should return undef for unknown variables');

# Test hover for Perl special variables
$doc = bless {
    text => "#!/usr/bin/perl\nprint \$_;\n",
}, 'MockDocument';

$position = { line => 1, character => 7 };  # On "$_"
$hover_info = $hover->get_hover_info($doc, $position);

ok(defined $hover_info, 'Should return hover info for special variables');
if ($hover_info) {
    is($hover_info->{label}, '$_', 'Should identify $_ special variable');
    like($hover_info->{documentation}{value}, qr/Perl Special Variable/, 'Should include special variable documentation');
}

done_testing();