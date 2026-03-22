#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use lib 'lib';
use YAPLSPD::Document;

# Test basic document creation
my $doc = YAPLSPD::Document->new(
    uri => 'file:///test.pl',
    text => "use strict;\nuse warnings;\n\nsub hello {\n    print 'Hello';\n}",
    version => 1
);

is($doc->text, "use strict;\nuse warnings;\n\nsub hello {\n    print 'Hello';\n}", 'Initial text matches');
is($doc->version, 1, 'Initial version correct');

# Test full document replace
$doc->apply_changes([{ text => "use strict;\nprint 'New';" }]);
is($doc->text, "use strict;\nprint 'New';", 'Full replace works');
is($doc->version, 2, 'Version incremented on change');

# Test incremental change
$doc->apply_changes([{
    range => {
        start => { line => 1, character => 7 },
        end => { line => 1, character => 10 }
    },
    text => 'Modified'
}]);
is($doc->text, "use strict;\nprint 'Modified';", 'Incremental change works');
is($doc->version, 3, 'Version incremented on incremental change');

# Test multi-line change - full document replace
$doc->apply_changes([{
    text => "# New header\nprint 'Multi';"
}]);
is($doc->text, "# New header\nprint 'Multi';", 'Multi-line change works');
is($doc->version, 4, 'Version incremented on multi-line change');

# Test parsing after changes (requires PPI)
SKIP: {
    skip "PPI not installed", 3 unless eval { require PPI };
    
    my $subs = $doc->subroutines;
    is(scalar(@$subs), 0, 'No subroutines after changes');

    # Test with subroutine
    $doc->text("sub test { 1 }");
    $subs = $doc->subroutines;
    is(scalar(@$subs), 1, 'Found subroutine after text change');
    is($subs->[0]->{name}, 'test', 'Correct subroutine name');
}

done_testing;
