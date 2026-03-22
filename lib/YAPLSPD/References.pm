package YAPLSPD::References;
use strict;
use warnings;

# Try to load PPI, but it's optional
my $HAS_PPI = 0;
eval { require PPI; $HAS_PPI = 1; };

sub new {
    my ($class) = @_;
    return bless {}, $class;
}

sub find_references {
    my ($self, $doc, $position) = @_;

    my $text = $doc->text();
    my $line = $position->{line};
    my $character = $position->{character};
    
    # Get the word at the specified position (fallback method)
    my $word = $self->_get_word_at_position($doc, $line, $character);
    return [] unless $word && $word =~ /^[a-zA-Z_][a-zA-Z0-9_]*$/;
    
    # Use PPI if available, otherwise fallback to regex
    if ($HAS_PPI) {
        return $self->_find_references_with_ppi($text, $word);
    } else {
        return $self->_find_references_fallback($text, $word);
    }
}

sub _get_word_at_position {
    my ($self, $doc, $line, $character) = @_;
    
    my $line_text = $doc->get_line($line);
    return undef unless defined $line_text;
    
    # Find the word at the character position
    my $start = $character;
    while ($start > 0 && substr($line_text, $start - 1, 1) =~ /[a-zA-Z0-9_]/) {
        $start--;
    }
    
    my $end = $character;
    while ($end < length($line_text) && substr($line_text, $end, 1) =~ /[a-zA-Z0-9_]/) {
        $end++;
    }
    
    return substr($line_text, $start, $end - $start);
}

sub _find_references_with_ppi {
    my ($self, $text, $word) = @_;
    
    my $document = PPI::Document->new(\$text);
    return [] unless $document;
    
    my @references;
    
    # Find all subroutine calls (function calls)
    my $subs = $document->find('PPI::Token::Word');
    if ($subs) {
        foreach my $sub (@$subs) {
            next unless $sub->content eq $word;
            
            # Skip subroutine definitions (sub word { ... })
            my $parent = $sub->parent;
            if ($parent && $parent->isa('PPI::Statement::Sub')) {
                next;
            }
            
            my $location = $self->_ppi_to_lsp_location($sub);
            push @references, $location if $location;
        }
    }
    
    return \@references;
}

sub _find_references_fallback {
    my ($self, $text, $word) = @_;
    
    my @references;
    my @lines = split /\n/, $text;
    
    for my $line_idx (0 .. $#lines) {
        my $line = $lines[$line_idx];
        my $pos = 0;
        
        while ($pos < length($line)) {
            # Find next occurrence of the word
            my $idx = index($line, $word, $pos);
            last if $idx < 0;
            
            # Check if it's a complete word (not part of another word)
            my $before = $idx > 0 ? substr($line, $idx - 1, 1) : '';
            my $after_idx = $idx + length($word);
            my $after = $after_idx < length($line) ? substr($line, $after_idx, 1) : '';
            
            if (($before eq '' || $before !~ /[a-zA-Z0-9_]/) &&
                ($after eq '' || $after !~ /[a-zA-Z0-9_]/)) {
                
                # Skip if this is a subroutine definition (sub word)
                my $before_word = substr($line, 0, $idx);
                if ($before_word =~ /\bsub\s+$/) {
                    $pos = $idx + 1;
                    next;
                }
                
                # Check if it looks like a subroutine call (followed by '(' or standalone)
                if ($after eq '(' || $after eq '' || $after =~ /\s/) {
                    push @references, {
                        uri => 'file:///placeholder',
                        range => {
                            start => {
                                line => $line_idx,
                                character => $idx,
                            },
                            end => {
                                line => $line_idx,
                                character => $idx + length($word),
                            },
                        },
                    };
                }
            }
            
            $pos = $idx + 1;
        }
    }
    
    return \@references;
}

sub _ppi_to_lsp_location {
    my ($self, $element) = @_;
    
    my $location = $element->location;
    return undef unless $location;
    
    # Handle both array and hash location formats
    my ($line, $col);
    if (ref $location eq 'ARRAY') {
        ($line, $col) = @$location;
    } elsif (ref $location eq 'HASH') {
        $line = $location->{line};
        $col = $location->{column};
    } else {
        return undef;
    }
    
    return undef unless defined $line && defined $col;
    
    return {
        uri => 'file:///placeholder',
        range => {
            start => {
                line => $line - 1,  # Convert to 0-based
                character => $col - 1,
            },
            end => {
                line => $line - 1,
                character => $col + length($element->content) - 1,
            },
        },
    };
}

1;