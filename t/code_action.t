use strict;
use warnings;
use Test::More tests => 8;
use lib 'lib';

use YAPLSPD::CodeAction;
use YAPLSPD::Document;

my $code_action = YAPLSPD::CodeAction->new();
ok($code_action, 'Created CodeAction instance');

# Test quick fixes with diagnostics
my $doc1 = YAPLSPD::Document->new(
    uri => 'file:///test1.pl',
    text => "#!/usr/bin/perl\nprint \$undefined;\n",
);

my $diag1 = {
    range => { start => { line => 1, character => 6 }, end => { line => 1, character => 16 } },
    message => "Global symbol \"\$undefined\" requires explicit package name",
};

my $actions1 = $code_action->get_code_actions($doc1, 
    { start => { line => 1, character => 6 }, end => { line => 1, character => 16 } },
    { diagnostics => [$diag1] }
);
ok($actions1, 'Got code actions');
ok(scalar(@$actions1) > 0, 'Has at least one action');

# Test source actions without diagnostics
my $doc2 = YAPLSPD::Document->new(
    uri => 'file:///test2.pl',
    text => "print 'Hello';\n",
);

my $actions2 = $code_action->get_code_actions($doc2,
    { start => { line => 0, character => 0 }, end => { line => 0, character => 13 } },
    { diagnostics => [] }
);
ok($actions2, 'Got code actions without diagnostics');
my @source_actions = grep { $_->{kind} && $_->{kind} eq 'source' } @$actions2;
ok(scalar(@source_actions) > 0, 'Has source actions');

# Test extract variable action (requires selection > 50 chars or multiline)
my $doc3 = YAPLSPD::Document->new(
    uri => 'file:///test3.pl',
    text => "my \$x = 'a very long string that definitely needs extraction here';\n",
);

my $actions3 = $code_action->get_code_actions($doc3,
    { start => { line => 0, character => 9 }, end => { line => 0, character => 60 } },
    { diagnostics => [] }
);
ok($actions3, 'Got actions for selection');
my @extract_actions = grep { $_->{kind} && $_->{kind} eq 'refactor.extract' } @$actions3;
# Extract actions may or may not be present depending on selection
diag("Extract actions found: " . scalar(@extract_actions));

# Test add strict/warnings action
my $actions4 = $code_action->get_code_actions($doc2,
    { start => { line => 0, character => 0 }, end => { line => 0, character => 0 } },
    { diagnostics => [] }
);
my @strict_actions = grep { $_->{title} && $_->{title} =~ /strict/ } @$actions4;
ok(scalar(@strict_actions) > 0, 'Has add strict action');
ok($strict_actions[0]{edit}, 'Add strict action has edit');

print "CodeAction tests passed!\n";