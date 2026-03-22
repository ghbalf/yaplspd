package YAPLSPD::Definition;
use strict;
use warnings;

# Try to load PPI, but make it optional for testing
my $HAS_PPI = 0;
eval {
    require PPI;
    $HAS_PPI = 1;
};

sub new {
    my ($class) = @_;
    return bless {}, $class;
}

sub find_definition {
    my ($self, $document, $position) = @_;
    
    my $line = $position->{line};
    my $character = $position->{character};
    
    # Get word at position (PPI or text-based fallback)
    my $word = $self->_get_word_at_position($document, $line, $character) or return;
    
    # Try PPI first if available
    if ($HAS_PPI) {
        my $ppi = $document->ppi_document();
        if ($ppi) {
            my $result = $self->_find_definition_with_ppi($document, $word);
            return $result if defined $result;
        }
    }
    
    # Fallback: simple regex-based search
    return $self->_find_definition_fallback($document, $word);
}

sub _find_definition_with_ppi {
    my ($self, $document, $word) = @_;
    
    my $ppi = $document->ppi_document() or return;
    
    # Find subroutine definitions
    my $subs = $ppi->find('PPI::Statement::Sub');
    return unless $subs;
    
    foreach my $sub (@$subs) {
        my $name = $sub->name;
        next unless $name && $name eq $word;
        
        my $location = $sub->location;
        next unless $location && ref($location) eq 'HASH';
        
        return {
            uri => $document->uri,
            range => {
                start => {
                    line => $location->{line} - 1,  # Convert to 0-based
                    character => $location->{column} - 1,
                },
                end => {
                    line => $location->{line} - 1,
                    character => $location->{column} - 1 + length($name),
                },
            },
        };
    }
    
    return;
}

sub _find_definition_fallback {
    my ($self, $document, $word) = @_;
    
    my $text = $document->text;
    my @lines = split(/\n/, $text);
    
    # Simple regex search for "sub word"
    for (my $i = 0; $i < @lines; $i++) {
        if ($lines[$i] =~ /^\s*sub\s+\b\Q$word\E\b/) {
            my $line_text = $lines[$i];
            my $char_pos = index($line_text, $word);
            $char_pos = 4 while $char_pos < 0 && ($line_text =~ /sub\s+/g && (($char_pos = pos($line_text) - length($word)) >= 0));
            $char_pos = 4 if $char_pos < 0;  # Default after "sub "
            
            return {
                uri => $document->uri,
                range => {
                    start => {
                        line => $i,
                        character => $char_pos,
                    },
                    end => {
                        line => $i,
                        character => $char_pos + length($word),
                    },
                },
            };
        }
    }
    
    return;
}

sub _get_word_at_position {
    my ($self, $document, $line, $character) = @_;
    
    # PPI-based word extraction if available
    if ($HAS_PPI) {
        my $ppi = $document->ppi_document();
        if ($ppi) {
            my $word = $self->_get_word_with_ppi($ppi, $line + 1, $character);  # PPI is 1-based
            return $word if defined $word;
        }
    }
    
    # Fallback: text-based word extraction
    return $self->_get_word_fallback($document, $line, $character);
}

sub _get_word_with_ppi {
    my ($self, $ppi, $line, $character) = @_;
    
    my $tokens = $ppi->find('PPI::Token');
    return unless $tokens;
    
    foreach my $token (@$tokens) {
        my $location = $token->location;
        next unless $location && ref($location) eq 'HASH';
        
        if ($location->{line} == $line) {
            my $start_col = $location->{column};
            my $end_col = $start_col + length($token->content) - 1;
            
            if ($character >= $start_col - 1 && $character <= $end_col - 1) {
                my $content = $token->content;
                $content =~ s/^\s+|\s+$//g;
                return $content if $content =~ /^[a-zA-Z_][a-zA-Z0-9_]*$/;
            }
        }
    }
    
    return;
}

sub _get_word_fallback {
    my ($self, $document, $line, $character) = @_;
    
    my $text = $document->text;
    my @lines = split(/\n/, $text);
    return unless $line >= 0 && $line < @lines;
    
    my $line_text = $lines[$line];
    
    # Find word at character position (0-based)
    # Look backwards to find word start
    my $start = $character;
    while ($start > 0 && substr($line_text, $start - 1, 1) =~ /[a-zA-Z0-9_]/) {
        $start--;
    }
    
    # Look forwards to find word end
    my $end = $character;
    while ($end < length($line_text) && substr($line_text, $end, 1) =~ /[a-zA-Z0-9_]/) {
        $end++;
    }
    
    my $word = substr($line_text, $start, $end - $start);
    return $word if $word =~ /^[a-zA-Z_][a-zA-Z0-9_]*$/;
    
    return;
}

1;