package YAPLSPD::DocumentHighlight;
use strict;
use warnings;

# LSP DocumentHighlightKind
my $KIND_TEXT = 1;    # textual occurrence
my $KIND_READ = 2;    # read access
my $KIND_WRITE = 3;   # write access

sub new {
    my ($class) = @_;
    bless {}, $class;
}

sub get_highlights {
    my ($self, $document, $position) = @_;
    
    my $line = $position->{line};
    my $char = $position->{character};
    
    # Get the word at position
    my $word = $document->get_word_at_position($line, $char);
    return [] unless defined $word && $word ne '';
    
    # Determine symbol type and find all occurrences
    my @highlights;
    
    if ($word =~ /^[\$@%]/) {
        # Variable
        @highlights = $self->_find_variable_highlights($document, $word);
    }
    elsif ($word =~ /^[A-Z_]+$/) {
        # Constant (all caps)
        @highlights = $self->_find_constant_highlights($document, $word);
    }
    else {
        # Subroutine or other identifier
        @highlights = $self->_find_sub_highlights($document, $word);
    }
    
    return \@highlights;
}

sub _find_variable_highlights {
    my ($self, $document, $var_name) = @_;
    
    my @highlights;
    my $text = $document->text;
    my @lines = split(/\n/, $text);
    
    # Extract base name without sigil
    my ($sigil, $base_name) = $var_name =~ /^([\$@%])(.+)$/;
    return () unless defined $base_name;
    
    my $escaped = quotemeta($base_name);
    
    for (my $i = 0; $i < @lines; $i++) {
        my $line = $lines[$i];
        
        # Find all occurrences of this variable name (with any sigil)
        pos($line) = 0;
        while ($line =~ /([\$@%])($escaped)\b/g) {
            my $match_sigil = $1;
            my $match_start = $-[1];
            my $match_len = length($match_sigil) + length($2);
            
            # Determine if read or write
            my $kind = $self->_determine_variable_access($line, $match_start);
            
            push @highlights, {
                range => {
                    start => { line => $i, character => $match_start },
                    end => { line => $i, character => $match_start + $match_len },
                },
                kind => $kind,
            };
        }
    }
    
    return @highlights;
}

sub _determine_variable_access {
    my ($self, $line, $pos) = @_;
    
    # Check context before the variable
    my $before = substr($line, 0, $pos);
    my $after = substr($line, $pos);
    
    # Write indicators
    if ($before =~ /(?:my|our|local|state)\s+$/) {
        return $KIND_WRITE;
    }
    if ($before =~ /\$\s*\{\s*$/) {
        return $KIND_WRITE;  # Hash assignment
    }
    if ($after =~ /^\s*=/) {
        return $KIND_WRITE;  # Direct assignment
    }
    if ($before =~ /for(?:each)?\s+\$?[\w_]*\s*$/) {
        return $KIND_WRITE;  # Loop variable
    }
    
    return $KIND_READ;
}

sub _find_sub_highlights {
    my ($self, $document, $sub_name) = @_;
    
    my @highlights;
    my $text = $document->text;
    my @lines = split(/\n/, $text);
    
    my $escaped = quotemeta($sub_name);
    
    for (my $i = 0; $i < @lines; $i++) {
        my $line = $lines[$i];
        
        # Definition: sub name
        if ($line =~ /\bsub\s+($escaped)\b/) {
            my $start = $-[1];
            push @highlights, {
                range => {
                    start => { line => $i, character => $start },
                    end => { line => $i, character => $start + length($1) },
                },
                kind => $KIND_WRITE,
            };
        }
        
        # Function calls
        pos($line) = 0;
        while ($line =~ /\b($escaped)\s*(?:\(|\s+\w)/g) {
            # Skip if preceded by 'sub'
            next if $-[0] >= 4 && substr($line, $-[0] - 4, 3) eq 'sub';
            
            my $start = $-[1];
            push @highlights, {
                range => {
                    start => { line => $i, character => $start },
                    end => { line => $i, character => $start + length($1) },
                },
                kind => $KIND_READ,
            };
        }
        
        # Method calls ->name
        pos($line) = 0;
        while ($line =~ /->\s*($escaped)\b/g) {
            my $start = $-[1];
            push @highlights, {
                range => {
                    start => { line => $i, character => $start },
                    end => { line => $i, character => $start + length($1) },
                },
                kind => $KIND_READ,
            };
        }
    }
    
    return @highlights;
}

sub _find_constant_highlights {
    my ($self, $document, $const_name) = @_;
    
    my @highlights;
    my $text = $document->text;
    my @lines = split(/\n/, $text);
    
    my $escaped = quotemeta($const_name);
    
    for (my $i = 0; $i < @lines; $i++) {
        my $line = $lines[$i];
        
        # Definition: use constant NAME => value
        if ($line =~ /\buse\s+constant\s+($escaped)\b/) {
            my $start = $-[1];
            push @highlights, {
                range => {
                    start => { line => $i, character => $start },
                    end => { line => $i, character => $start + length($1) },
                },
                kind => $KIND_WRITE,
            };
            next;
        }
        
        # Usage
        pos($line) = 0;
        while ($line =~ /\b($escaped)\b/g) {
            my $start = $-[1];
            push @highlights, {
                range => {
                    start => { line => $i, character => $start },
                    end => { line => $i, character => $start + length($1) },
                },
                kind => $KIND_READ,
            };
        }
    }
    
    return @highlights;
}

1;