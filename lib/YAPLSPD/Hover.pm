package YAPLSPD::Hover;
use strict;
use warnings;

sub new {
    my ($class) = @_;
    bless {}, $class;
}

sub get_hover_info {
    my ($self, $document, $position) = @_;
    
    my $line = $position->{line};
    my $character = $position->{character};
    
    # Get current line content
    my $lines = $document->lines;
    return undef unless defined $lines->[$line];
    
    my $current_line = $lines->[$line];
    return undef unless defined $current_line;
    
    # Extract word at position
    my $word = $self->_get_word_at_position($current_line, $character);
    return undef unless $word;
    
    # Determine what type of word it is (keyword, built-in, special variable, etc.)
    my $hover_info = $self->_classify_word($document, $word);
    
    return $hover_info;
}

sub _get_word_at_position {
    my ($self, $line_text, $character) = @_;
    return '' unless defined $line_text && defined $character;
    
    # Find word boundaries
    my $start = $character;
    my $end = $character;
    
    # Convert to array for character-by-character access
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

sub _classify_word {
    my ($self, $document, $word) = @_;
    
    # Define Perl keywords
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
    
    # Define Perl built-in functions
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
    
    # Define special variables
    my %special_vars = map { $_ => 'Perl Special Variable' } qw(
        $_ @_ $! $$ $< $> $0 $1 $2 $3 $& $` $' $+
        $/ $\ $| $,
        @ARGV %ENV @INC %INC
    );
    
    # Check if it's a known keyword
    if (exists $keywords{$word}) {
        return {
            label => $word,
            kind => 14,  # Keyword
            detail => $keywords{$word},
            documentation => {
                kind => 'markdown',
                value => "**$word**\n\n$keywords{$word}.",
            },
        };
    }
    
    # Check if it's a built-in function
    if (exists $builtins{$word}) {
        return {
            label => $word,
            kind => 3,   # Function
            detail => $builtins{$word},
            documentation => {
                kind => 'markdown',
                value => "**$word**\n\n$builtins{$word}.",
            },
        };
    }
    
    # Check if it's a special variable
    if (exists $special_vars{$word}) {
        return {
            label => $word,
            kind => 6,   # Variable
            detail => $special_vars{$word},
            documentation => {
                kind => 'markdown',
                value => "**$word**\n\n$special_vars{$word}.",
            },
        };
    }
    
    # Check if it's a subroutine from the document
    my $sub_info = $self->_find_subroutine_info($document, $word);
    return $sub_info if $sub_info;
    
    # Check if it's a variable from the document
    my $var_info = $self->_find_variable_info($document, $word);
    return $var_info if $var_info;
    
    return undef;
}

sub _find_subroutine_info {
    my ($self, $document, $word) = @_;    
    return unless $document;
    
    # Remove sigil if present
    $word =~ s/^&//;
    
    my $sub = $document->find_subroutine($word);
    return unless $sub;
    
    # Get the subroutine declaration line
    my $line_text = $document->get_line($sub->{line} - 1); # -1 for 0-based vs 1-based indexing
    
    # Extract subroutine signature/parameters
    my $signature = $self->_extract_sub_signature($sub->{declaration});
    
    # Count usage
    my $calls = $document->find_subroutine_calls($word);
    my $usage_count = scalar @$calls;
    
    return {
        label => $word,
        kind => 12,  # Function
        detail => "User-defined subroutine",
        documentation => {
            kind => 'markdown',
            value => "**sub $word**\n\n" . 
                     "**File:** " . ($document->uri =~ m{([^/]+)$} ? $1 : 'unknown') . "\n" .
                     "**Line:** " . $sub->{line} . "\n" .
                     ($signature ? "**Signature:** \`$signature\`\n\n" : "\n") .
                     "**Usage:** Called $usage_count time" . ($usage_count == 1 ? "" : "s") . "\n\n" .
                     "**Declaration:**\n\`\`\`perl\n$line_text\n\`\`\`",
        },
    };
}

sub _find_variable_info {
    my ($self, $document, $word) = @_;    
    return unless $document;
    
    # Must start with variable sigil
    return unless $word =~ /^[\$@%]/;
    
    my $vars = $document->variables;
    my ($var) = grep { $_->{name} eq $word } @$vars;
    return unless $var;
    
    # Get the variable declaration line
    my $line_text = $document->get_line($var->{line} - 1); # -1 for 0-based vs 1-based indexing
    
    return {
        label => $word,
        kind => 6,  # Variable
        detail => "User-defined " . $var->{type} . " variable",
        documentation => {
            kind => 'markdown',
            value => "**$word**\n\n" . 
                     "**Type:** " . ucfirst($var->{type}) . " variable\n" .
                     "**File:** " . ($document->uri =~ m{([^/]+)$} ? $1 : 'unknown') . "\n" .
                     "**Line:** " . $var->{line} . "\n\n" .
                     "**Declaration:**\n\`\`\`perl\n$line_text\n\`\`\`",
        },
    };
}

sub _extract_sub_signature {
    my ($self, $sub_decl) = @_;    
    return unless $sub_decl;
    
    # Get the full subroutine text
    my $text = $sub_decl->content;
    
    # Extract parameters if any
    if ($text =~ /sub\s+\w+\s*\((.*?)\)/s) {
        my $params = $1;
        $params =~ s/\s+/ /g;
        $params =~ s/^\s+|\s+$//g;
        return "($params)" if $params;
    }
    
    return "()";
}

1;