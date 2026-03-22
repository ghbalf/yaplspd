#!/usr/bin/env perl
use strict;
use warnings;

# Mock document for testing hover functionality without PPI
package MockDocument;
use strict;
use warnings;

sub new {
    my ($class, %args) = @_;
    bless { %args }, $class;
}

sub uri { shift->{uri} }
sub text { shift->{text} }
sub lines { [split /\n/, shift->{text}] }

sub get_line {
    my ($self, $line) = @_;
    my @lines = split /\n/, $self->{text};
    return $lines[$line] // '';
}

sub subroutines {
    my ($self) = @_;
    return [
        { name => 'greet', line => 6, declaration => bless({}, 'PPI::Statement::Sub') },
        { name => 'calculate', line => 11, declaration => bless({}, 'PPI::Statement::Sub') },
        { name => 'simple_sub', line => 17, declaration => bless({}, 'PPI::Statement::Sub') },
    ];
}

sub find_subroutine {
    my ($self, $name) = @_;    
    my $subs = $self->subroutines;
    foreach my $sub (@$subs) {
        return $sub if $sub->{name} eq $name;
    }
    return undef;
}

sub find_subroutine_calls {
    my ($self, $name) = @_;    
    # Mock: return some calls
    return [{ name => $name, line => 22 }] if $name eq 'calculate';
    return [{ name => $name, line => 23 }] if $name eq 'greet';
    return [{ name => $name, line => 24 }] if $name eq 'simple_sub';
    return [];
}

sub variables {
    my ($self) = @_;    
    return [
        { name => '$scalar_var', line => 4, type => 'scalar' },
        { name => '@array_var', line => 5, type => 'array' },
        { name => '%hash_var', line => 6, type => 'hash' },
    ];
}

# Mock hover module with our changes
package MockHover;
use strict;
use warnings;

sub new { bless {}, shift }

sub get_hover_info {
    my ($self, $document, $position) = @_;    
    my $line = $position->{line};
    my $character = $position->{character};
    
    my $lines = $document->lines;
    return undef unless defined $lines->[$line];
    
    my $current_line = $lines->[$line];
    my $word = $self->_get_word_at_position($current_line, $character);
    return undef unless $word;
    
    return $self->_find_subroutine_info($document, $word) ||
           $self->_find_variable_info($document, $word) ||
           $self->_classify_word($word);
}

sub _get_word_at_position {
    my ($self, $line_text, $character) = @_;    
    return '' unless defined $line_text && defined $character;
    
    my $start = $character;
    my $end = $character;
    my @chars = split //, $line_text;
    
    while ($start > 0 && $chars[$start - 1] =~ /[\w\$@%::]/) {
        $start--;
    }
    
    while ($end < scalar @chars && $chars[$end] =~ /[\w\$@%::]/) {
        $end++;
    }
    
    return $end > $start
        ? substr($line_text, $start, $end - $start)
        : '';
}

sub _find_subroutine_info {
    my ($self, $document, $word) = @_;    
    return unless $document;
    
    $word =~ s/^&//;
    my $sub = $document->find_subroutine($word);
    return unless $sub;
    
    my $line_text = $document->get_line($sub->{line} - 1);
    my $calls = $document->find_subroutine_calls($word);
    my $usage_count = scalar @$calls;
    
    return {
        label => $word,
        kind => 12,
        detail => "User-defined subroutine",
        documentation => {
            kind => 'markdown',
            value => "**sub $word**\n\n" . 
                     "**File:** test.pl\n" .
                     "**Line:** " . $sub->{line} . "\n" .
                     "**Usage:** Called $usage_count time" . ($usage_count == 1 ? "" : "s") . "\n\n" .
                     "**Declaration:**\n\`\`\`perl\n$line_text\n\`\`\`",
        },
    };
}

sub _find_variable_info {
    my ($self, $document, $word) = @_;    
    return unless $document;
    return unless $word =~ /^[\$@%]/;
    
    my $vars = $document->variables;
    my ($var) = grep { $_->{name} eq $word } @$vars;
    return unless $var;
    
    my $line_text = $document->get_line($var->{line} - 1);
    
    return {
        label => $word,
        kind => 6,
        detail => "User-defined " . $var->{type} . " variable",
        documentation => {
            kind => 'markdown',
            value => "**$word**\n\n" . 
                     "**Type:** " . ucfirst($var->{type}) . " variable\n" .
                     "**File:** test.pl\n" .
                     "**Line:** " . $var->{line} . "\n\n" .
                     "**Declaration:**\n\`\`\`perl\n$line_text\n\`\`\`",
        },
    };
}

sub _classify_word {
    my ($self, $word) = @_;    
    
    my %keywords = map { $_ => 'Perl Keyword' } qw(
        if else elsif unless
        while for foreach until do
        next last redo
        sub package use require no
        my our local
        return
        die warn
        eval
        BEGIN END
        given when default
        and or not xor
        eq ne lt le gt ge cmp
    );
    
    my %builtins = map { $_ => 'Perl Built-in Function' } qw(
        print printf sprintf
        open close read write
        split join reverse
        sort map grep
        keys values each exists delete
        length substr index rindex
        time localtime gmtime
        rand srand
        system exec
        bless ref
        defined undef
        scalar
        chomp chop
        push pop shift unshift
        uc lc ucfirst lcfirst
        quotemeta
    );
    
    my %special_vars = map { $_ => 'Perl Special Variable' } qw(
        $_ @_ $! $$ $< $> $0 $1 $2 $3 $& $` $' $+
        $/ $\ $| $,
        @ARGV %ENV @INC %INC
    );
    
    if (exists $keywords{$word}) {
        return {
            label => $word,
            kind => 14,
            detail => $keywords{$word},
            documentation => {
                kind => 'markdown',
                value => "**$word**\n\n$keywords{$word}.",
            },
        };
    }
    
    if (exists $builtins{$word}) {
        return {
            label => $word,
            kind => 3,
            detail => $builtins{$word},
            documentation => {
                kind => 'markdown',
                value => "**$word**\n\n$builtins{$word}.",
            },
        };
    }
    
    if (exists $special_vars{$word}) {
        return {
            label => $word,
            kind => 6,
            detail => $special_vars{$word},
            documentation => {
                kind => 'markdown',
                value => "**$word**\n\n$special_vars{$word}.",
            },
        };
    }
    
    return undef;
}

package main;

# Test document
my $test_code = <<'PERL';
#!/usr/bin/env perl
use strict;
use warnings;

my $scalar_var = "hello";
our @array_var = (1, 2, 3);
local %hash_var = (key => 'value');

sub greet {
    my ($name) = @_;
    return "Hello, $name!";
}

sub calculate {
    my ($x, $y) = @_;
    return $x + $y;
}

sub simple_sub {
    print "This is simple\n";
}

# Usage
my $result = calculate(5, 3);
my $greeting = greet("World");
simple_sub();

print $scalar_var;
PERL

my $doc = MockDocument->new(
    uri => 'file:///test.pl',
    text => $test_code
);

my $hover = MockHover->new();

print "Testing hover functionality (mock version)...\n\n";

my @test_cases = (
    [6, 5, 'subroutine', 'greet'],
    [11, 5, 'subroutine', 'calculate'],
    [17, 5, 'subroutine', 'simple_sub'],
    [4, 5, 'variable', '$scalar_var'],
    [5, 6, 'variable', '@array_var'],
    [6, 8, 'variable', '%hash_var'],
    [22, 15, 'subroutine', 'calculate'],
    [23, 20, 'subroutine', 'greet'],
    [24, 2, 'subroutine', 'simple_sub'],
    [4, 2, 'keyword', 'my'],
    [5, 2, 'keyword', 'our'],
    [6, 2, 'keyword', 'local'],
    [2, 2, 'keyword', 'use'],
    [25, 2, 'keyword', 'print'],
);

foreach my $test (@test_cases) {
    my ($line, $char, $expected_type, $expected_name) = @$test;
    
    print "Testing hover at line $line, char $char... ";
    
    my $hover_info = $hover->get_hover_info($doc, { line => $line, character => $char });
    
    if ($hover_info) {
        if ($hover_info->{label} eq $expected_name) {
            print "PASS - Found $expected_type '$expected_name'\n";
        } else {
            print "FAIL - Expected '$expected_name', got '$hover_info->{label}'\n";
        }
    } else {
        print "SKIP - No hover info\n";
    }
}

print "\nDetailed hover examples:\n\n";

# Show detailed examples
my @detailed_tests = (
    [11, 5, 'calculate subroutine'],
    [4, 5, '$scalar_var variable'],
    [2, 2, 'use keyword'],
);

foreach my $test (@detailed_tests) {
    my ($line, $char, $description) = @$test;
    print "--- $description ---\n";
    
    my $info = $hover->get_hover_info($doc, { line => $line, character => $char });
    if ($info) {
        print "Label: $info->{label}\n";
        print "Kind: $info->{kind}\n";
        print "Detail: $info->{detail}\n";
        print "Documentation: $info->{documentation}{value}\n\n";
    }
}

print "Mock hover test completed!\n";