package YAPLSPD::Completion;
use strict;
use warnings;

# Perl keywords and built-ins
my @PERL_KEYWORDS = qw(
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

my @PERL_BUILTINS = qw(
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

my @PERL_SPECIAL_VARS = qw(
    $_ @_ $! $$ $< $> $0 $1 $2 $3 $& $` $' $+
    $/ $\ $| $, $
    @ARGV %ENV @INC %INC
);

sub new {
    my ($class) = @_;
    bless {}, $class;
}

sub complete {
    my ($self, $document, $position) = @_;
    
    my $line = $position->{line};
    my $character = $position->{character};
    
    # Get current line content up to cursor position
    my $lines = $document->lines;
    return [] unless defined $lines->[$line];
    
    my $current_line = $lines->[$line];
    my $prefix = substr($current_line, 0, $character);
    
    # Remove whitespace from prefix
    $prefix =~ s/^\s+//;
    
    my @completions;
    
    # Extract word prefix for matching
    my $word_prefix = '';
    if ($prefix =~ /([\w\$@%]*)$/) {
        $word_prefix = $1;
    }
    
    # Allow completion even with empty prefix or short prefixes
    $word_prefix = '' unless defined $word_prefix;
    
    # Add user-defined subroutines
    my $subs = $document->subroutines;
    foreach my $sub (@$subs) {
        my $name = $sub->{name};
        if (!$word_prefix || index($name, $word_prefix) == 0) {
            push @completions, {
                label => $name,
                kind => 3,  # Function
                insertText => $name,
                sortText => "1_$name",  # Sort user subs first
                filterText => $name,
                detail => "subroutine",
            };
        }
    }
    
    # Add user-defined variables
    my $vars = $document->variables;
    foreach my $var (@$vars) {
        my $name = $var->{name};
        # Remove sigil for matching if prefix doesn't have one
        my $match_name = $name;
        $match_name =~ s/^[\$@%]// if $word_prefix !~ /^[\$@%]/;
        
        if (index($name, $word_prefix) == 0 || index($match_name, $word_prefix) == 0) {
            push @completions, {
                label => $name,
                kind => 6,  # Variable
                insertText => $name,
                sortText => "2_$name",  # Sort variables after subs
                filterText => $name,
                detail => $var->{type} . " variable",
            };
        }
    }
    
    # Add built-in keywords and functions
    foreach my $keyword ((@PERL_KEYWORDS, @PERL_BUILTINS, @PERL_SPECIAL_VARS)) {
        if (index($keyword, $word_prefix) == 0) {
            push @completions, {
                label => $keyword,
                kind => _get_completion_kind($keyword),
                insertText => $keyword,
                sortText => "3_$keyword",  # Sort built-ins last
                filterText => $keyword,
                detail => _get_keyword_detail($keyword),
            };
        }
    }
    
    # Sort completions
    @completions = sort { $a->{sortText} cmp $b->{sortText} } @completions;
    
    return \@completions;
}

sub _get_completion_kind {
    my ($keyword) = @_;
    
    # LSP CompletionItemKind constants
    my %kinds = (
        keyword => 14,      # Keyword
        variable => 6,      # Variable
        function => 3,      # Function
        constant => 21,     # Constant
    );
    
    # Simple classification
    return $kinds{keyword} if grep { $_ eq $keyword } @PERL_KEYWORDS;
    return $kinds{function} if grep { $_ eq $keyword } @PERL_BUILTINS;
    return $kinds{variable} if grep { $_ eq $keyword } @PERL_SPECIAL_VARS;
    
    return $kinds{keyword};
}

sub _get_keyword_detail {
    my ($keyword) = @_;
    
    return "keyword" if grep { $_ eq $keyword } @PERL_KEYWORDS;
    return "built-in function" if grep { $_ eq $keyword } @PERL_BUILTINS;
    return "special variable" if grep { $_ eq $keyword } @PERL_SPECIAL_VARS;
    return "unknown";
}

1;