package YAPLSPD::Document;
use strict;
use warnings;

# Try to load PPI, but make it optional for basic functionality
my $HAS_PPI = 0;
eval {
    require PPI;
    $HAS_PPI = 1;
};

sub new {
    my ($class, %args) = @_;
    my $self = {
        uri => $args{uri},
        text => $args{text} || '',
        version => $args{version} || 0,
        ppi => undef,
        _parsed => 0,
    };
    bless $self, $class;
    $self->_parse_if_possible;
    return $self;
}

sub uri {
    my ($self) = @_;
    return $self->{uri};
}

sub text {
    my ($self, $new_text) = @_;
    if (defined $new_text) {
        $self->{text} = $new_text;
        $self->_parse_if_possible;
    }
    return $self->{text};
}

sub version {
    my ($self, $new_version) = @_;
    if (defined $new_version) {
        $self->{version} = $new_version;
    }
    return $self->{version};
}

sub lines {
    my ($self) = @_;
    return [split(/\n/, $self->{text})];
}

sub get_line {
    my ($self, $line_num) = @_;
    my $lines = $self->lines;
    return $lines->[$line_num];
}

sub get_word_at_position {
    my ($self, $line_num, $char) = @_;
    return '' unless defined $line_num && defined $char;

    my $line = $self->get_line($line_num);
    return '' unless defined $line;

    # Clamp character position to line length
    my $line_len = length($line);
    $char = $line_len if $char > $line_len;

    # Find word boundaries (Perl identifiers: alphanumeric, underscore, $, @, %)
    my $start = $char;
    my $end = $char;

    # Move start back
    while ($start > 0 && substr($line, $start - 1, 1) =~ /[\w\$@%]/) {
        $start--;
    }

    # Move end forward
    while ($end < $line_len && substr($line, $end, 1) =~ /[\w\$@%]/) {
        $end++;
    }

    return substr($line, $start, $end - $start);
}

sub ppi_document {
    my ($self) = @_;
    return $self->{ppi} if $self->{ppi};
    return undef unless $HAS_PPI;
    
    $self->{ppi} = PPI::Document->new(\$self->{text});
    return $self->{ppi};
}

sub apply_changes {
    my ($self, $changes) = @_;

    foreach my $change (@$changes) {
        if (exists $change->{text}) {
            if (exists $change->{range}) {
                # Incremental change
                $self->_apply_incremental_change($change);
            } else {
                # Full document replace
                $self->{text} = $change->{text};
            }
            # Increment version for each change
            $self->{version}++;
        }
    }

    # Re-parse after changes
    $self->{ppi} = undef;
    $self->_parse_if_possible;
}

sub _apply_incremental_change {
    my ($self, $change) = @_;

    my $range = $change->{range};
    my $new_text = $change->{text};
    my @lines = split(/\n/, $self->{text}, -1);

    my $start_line = $range->{start}{line};
    my $start_char = $range->{start}{character};
    my $end_line = $range->{end}{line};
    my $end_char = $range->{end}{character};

    # Handle edge case: document is empty
    if (@lines == 0 || ($lines[0] eq '' && @lines == 1)) {
        $self->{text} = $new_text;
        return;
    }

    # Ensure we have enough lines
    while (@lines <= $end_line) {
        push @lines, '';
    }

    # Get text before the change (from start line)
    my $before = '';
    if ($start_line < @lines) {
        $before = substr($lines[$start_line], 0, $start_char);
    }

    # Get text after the change (from end line)
    my $after = '';
    if ($end_line < @lines) {
        $after = substr($lines[$end_line], $end_char);
    }

    # Build the replacement
    my $replacement = $before . $new_text . $after;

    # Reconstruct the lines
    my @new_lines;
    push @new_lines, @lines[0..$start_line-1] if $start_line > 0;
    push @new_lines, split(/\n/, $replacement, -1);
    push @new_lines, @lines[$end_line+1..$#lines] if $end_line < $#lines;

    $self->{text} = join("\n", @new_lines);
}

sub _parse_if_possible {
    my ($self) = @_;
    return unless $HAS_PPI;
    
    eval {
        $self->{ppi} = PPI::Document->new(\$self->{text});
        $self->_extract_symbols if $self->{ppi};
    };
}

sub _extract_symbols {
    my ($self) = @_;
    return unless $self->{ppi};
    
    $self->{_subroutines} = [];
    $self->{_variables} = [];
    $self->{_packages} = [];
    
    # Extract packages
    my $packages = $self->{ppi}->find('PPI::Statement::Package');
    if ($packages) {
        foreach my $pkg (@$packages) {
            my $loc = $pkg->location;
            my $line = ref($loc) eq 'ARRAY' ? $loc->[0] : $loc->{line};
            push @{$self->{_packages}}, {
                name => $pkg->namespace,
                line => $line,
            };
        }
    }

    # Extract subroutines
    my $subs = $self->{ppi}->find('PPI::Statement::Sub');
    if ($subs) {
        foreach my $sub (@$subs) {
            my $name = $sub->name;
            next unless $name;

            my $loc = $sub->location;
            my $line = ref($loc) eq 'ARRAY' ? $loc->[0] : $loc->{line};
            my $column = ref($loc) eq 'ARRAY' ? $loc->[1] : $loc->{column};

            push @{$self->{_subroutines}}, {
                name => $name,
                line => $line,
                column => $column,
                declaration => $sub,
            };
        }
    }

    # Extract variables
    my $symbols = $self->{ppi}->find('PPI::Token::Symbol');
    if ($symbols) {
        my %seen;
        foreach my $sym (@$symbols) {
            my $name = $sym->content;
            next if $seen{$name}++;

            my $type = 'scalar';
            $type = 'array' if $name =~ /^@/;
            $type = 'hash' if $name =~ /^%/;

            my $loc = $sym->location;
            my $line = ref($loc) eq 'ARRAY' ? $loc->[0] : $loc->{line};

            push @{$self->{_variables}}, {
                name => $name,
                line => $line,
                type => $type,
            };
        }
    }
}

sub subroutines {
    my ($self) = @_;
    return $self->{_subroutines} || [];
}

sub variables {
    my ($self) = @_;
    return $self->{_variables} || [];
}

sub packages {
    my ($self) = @_;
    return $self->{_packages} || [];
}

sub find_subroutine {
    my ($self, $name) = @_;
    foreach my $sub (@{$self->{_subroutines}}) {
        return $sub if $sub->{name} eq $name;
    }
    return undef;
}

sub find_subroutine_calls {
    my ($self, $name) = @_;
    return [] unless $self->{ppi};
    
    my @calls;
    my $words = $self->{ppi}->find('PPI::Token::Word');
    return \@calls unless $words;
    
    foreach my $word (@$words) {
        if ($word->content eq $name) {
            push @calls, {
                line => $word->location->{line},
                column => $word->location->{column},
            };
        }
    }
    
    return \@calls;
}

sub syntax_errors {
    my ($self) = @_;
    return [] unless $self->{ppi};
    
    my @errors;
    my $unterminated = $self->{ppi}->find('PPI::Token::Unknown');
    if ($unterminated) {
        foreach my $token (@$unterminated) {
            push @errors, {
                message => "Syntax error: " . $token->content,
                line => $token->location->{line},
                column => $token->location->{column},
            };
        }
    }
    
    return \@errors;
}

1;
