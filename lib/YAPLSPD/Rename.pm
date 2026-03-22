package YAPLSPD::Rename;
use strict;
use warnings;

sub new {
    my ($class) = @_;
    bless {}, $class;
}

sub rename {
    my ($self, $document, $position, $new_name) = @_;
    
    # Get the word at the position
    my $old_name = $document->get_word_at_position($position->{line}, $position->{character});
    return undef unless defined $old_name && $old_name ne '';
    
    # Determine what kind of symbol this is
    my $symbol_type = $self->_get_symbol_type($document, $old_name);
    
    # Find all occurrences based on type
    my @changes;
    
    if ($symbol_type eq 'subroutine') {
        @changes = $self->_find_sub_occurrences($document, $old_name);
    }
    elsif ($symbol_type eq 'variable') {
        @changes = $self->_find_variable_occurrences($document, $old_name);
    }
    elsif ($symbol_type eq 'package') {
        @changes = $self->_find_package_occurrences($document, $old_name);
    }
    else {
        # Unknown type - try generic text-based renaming
        @changes = $self->_find_text_occurrences($document, $old_name);
    }
    
    return undef unless @changes;
    
    # Build WorkspaceEdit
    my $uri = $document->uri;
    return {
        changes => {
            $uri => \@changes,
        },
    };
}

sub _get_symbol_type {
    my ($self, $document, $name) = @_;
    
    my $text = $document->text;
    
    # Check if it's a subroutine
    if ($text =~ /\bsub\s+\Q$name\E\b/) {
        return 'subroutine';
    }
    
    # Check if it's a package
    if ($text =~ /\bpackage\s+\Q$name\E\b/) {
        return 'package';
    }
    
    # Check if it's a variable
    if ($name =~ /^[\$@%]/) {
        return 'variable';
    }
    
    return 'unknown';
}

sub _find_sub_occurrences {
    my ($self, $document, $sub_name) = @_;
    
    my @changes;
    my $text = $document->text;
    my @lines = split(/\n/, $text);
    
    my $escaped_name = quotemeta($sub_name);
    
    for (my $i = 0; $i < @lines; $i++) {
        my $line = $lines[$i];
        
        # Match subroutine definition: sub name
        while ($line =~ /\bsub\s+($escaped_name)\b/g) {
            my $start = pos($line) - length($1);
            push @changes, {
                range => {
                    start => { line => $i, character => $start },
                    end => { line => $i, character => $start + length($1) },
                },
                newText => $sub_name,
            };
        }
        
        # Match subroutine calls: name( or name(
        pos($line) = 0;
        while ($line =~ /\b($escaped_name)(?:\s*\(|\s+\w)/g) {
            my $match_start = $-[1];
            push @changes, {
                range => {
                    start => { line => $i, character => $match_start },
                    end => { line => $i, character => $match_start + length($1) },
                },
                newText => $sub_name,
            };
        }
        
        # Match method calls: ->name or ->name(
        pos($line) = 0;
        while ($line =~ /->\s*($escaped_name)\b/g) {
            my $match_start = $-[1];
            push @changes, {
                range => {
                    start => { line => $i, character => $match_start },
                    end => { line => $i, character => $match_start + length($1) },
                },
                newText => $sub_name,
            };
        }
    }
    
    return @changes;
}

sub _find_variable_occurrences {
    my ($self, $document, $var_name) = @_;
    
    my @changes;
    my $text = $document->text;
    my @lines = split(/\n/, $text);
    
    # Extract base name without sigil
    my ($sigil, $base_name) = $var_name =~ /^([\$@%])(.+)$/;
    return () unless defined $base_name;
    
    my $escaped_name = quotemeta($base_name);
    
    for (my $i = 0; $i < @lines; $i++) {
        my $line = $lines[$i];
        
        # Match all sigils for this variable name
        pos($line) = 0;
        while ($line =~ /([\$@%])($escaped_name)\b/g) {
            my $match_sigil = $1;
            my $match_start = $-[1];
            my $match_len = length($match_sigil) + length($2);
            
            push @changes, {
                range => {
                    start => { line => $i, character => $match_start },
                    end => { line => $i, character => $match_start + $match_len },
                },
                newText => $sigil . $base_name,
            };
        }
    }
    
    return @changes;
}

sub _find_package_occurrences {
    my ($self, $document, $package_name) = @_;
    
    my @changes;
    my $text = $document->text;
    my @lines = split(/\n/, $text);
    
    my $escaped_name = quotemeta($package_name);
    
    for (my $i = 0; $i < @lines; $i++) {
        my $line = $lines[$i];
        
        # Match package declarations
        while ($line =~ /\bpackage\s+($escaped_name)\b/g) {
            my $start = $-[1];
            push @changes, {
                range => {
                    start => { line => $i, character => $start },
                    end => { line => $i, character => $start + length($1) },
                },
                newText => $package_name,
            };
        }
        
        # Match package usage in use/require
        pos($line) = 0;
        while ($line =~ /\b(?:use|require)\s+($escaped_name)\b/g) {
            my $start = $-[1];
            push @changes, {
                range => {
                    start => { line => $i, character => $start },
                    end => { line => $i, character => $start + length($1) },
                },
                newText => $package_name,
            };
        }
    }
    
    return @changes;
}

sub _find_text_occurrences {
    my ($self, $document, $name) = @_;
    
    my @changes;
    my $text = $document->text;
    my @lines = split(/\n/, $text);
    
    my $escaped_name = quotemeta($name);
    
    for (my $i = 0; $i < @lines; $i++) {
        my $line = $lines[$i];
        
        pos($line) = 0;
        while ($line =~ /\b($escaped_name)\b/g) {
            my $start = $-[1];
            push @changes, {
                range => {
                    start => { line => $i, character => $start },
                    end => { line => $i, character => $start + length($1) },
                },
                newText => $name,
            };
        }
    }
    
    return @changes;
}

1;