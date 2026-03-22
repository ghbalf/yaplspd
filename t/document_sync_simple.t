#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use lib 'lib';
use YAPLSPD::Document;

# Test basic document creation and version management
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

# Test multi-line change - replace entire document
$doc->apply_changes([{
    text => "# New header\nprint 'Multi';"
}]);
is($doc->text, "# New header\nprint 'Multi';", 'Multi-line change works');
is($doc->version, 4, 'Version incremented on multi-line change');

# Test line-based operations
my $line = $doc->get_line(0);
is($line, "# New header", 'get_line works correctly');

my $word = $doc->get_word_at_position(1, 8);
is($word, 'Multi', 'get_word_at_position works correctly');

done_testing;
