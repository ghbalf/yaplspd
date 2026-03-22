package YAPLSPD::SelectionRange;
use strict;
use warnings;

sub new {
    my ($class) = @_;
    bless {}, $class;
}

sub get_selection_ranges {
    my ($self, $document, $positions) = @_;
    
    my @ranges;
    
    foreach my $pos (@$positions) {
        my $range = $self->_get_selection_range($document, $pos);
        push @ranges, $range if $range;
    }
    
    return \@ranges;
}

sub _get_selection_range {
    my ($self, $document, $position) = @_;
    
    my $line_num = $position->{line};
    my $char = $position->{character};
    
    my @lines = @{$document->lines};
    return undef unless $line_num < @lines;
    
    my $line = $lines[$line_num];
    return undef unless $char <= length($line);
    
    # Build parent chain from innermost to outermost
    my @chain;
    
    # Start with word selection
    my $word_range = $self->_get_word_range($line, $line_num, $char);
    if ($word_range) {
        push @chain, $word_range;
    }
    
    # Line selection (excluding leading/trailing whitespace)
    my $line_range = $self->_get_line_range($line, $line_num);
    if ($line_range && (!$word_range || !_range_equal($word_range, $line_range))) {
        push @chain, $line_range;
    }
    
    # Statement/block selection
    my $statement_range = $self->_get_statement_range(\@lines, $line_num, $char);
    if ($statement_range && !_range_in_chain($statement_range, \@chain)) {
        push @chain, $statement_range;
    }
    
    # Subroutine selection
    my $sub_range = $self->_get_sub_range(\@lines, $line_num);
    if ($sub_range && !_range_in_chain($sub_range, \@chain)) {
        push @chain, $sub_range;
    }
    
    # Package selection
    my $pkg_range = $self->_get_package_range(\@lines, $line_num);
    if ($pkg_range && !_range_in_chain($pkg_range, \@chain)) {
        push @chain, $pkg_range;
    }
    
    # Build linked structure
    return $self->_build_linked_ranges(\@chain);
}

sub _get_word_range {
    my ($self, $line, $line_num, $char) = @_;
    
    # Find word boundaries
    my $start = $char;
    my $end = $char;
    
    # Move start back
    while ($start > 0 && substr($line, $start - 1, 1) =~ /[\w\$@%]/) {
        $start--;
    }
    
    # Move end forward
    while ($end < length($line) && substr($line, $end, 1) =~ /[\w\$@%]/) {
        $end++;
    }
    
    return undef if $start == $end;
    
    return {
        range => {
            start => { line => $line_num, character => $start },
            end => { line => $line_num, character => $end },
        },
    };
}

sub _get_line_range {
    my ($self, $line, $line_num) = @_;
    
    # Find first non-whitespace
    my $start = 0;
    while ($start < length($line) && substr($line, $start, 1) =~ /\s/) {
        $start++;
    }
    
    # Find last non-whitespace
    my $end = length($line);
    while ($end > $start && substr($line, $end - 1, 1) =~ /\s/) {
        $end--;
    }
    
    return {
        range => {
            start => { line => $line_num, character => $start },
            end => { line => $line_num, character => $end },
        },
    };
}

sub _get_statement_range {
    my ($self, $lines, $line_num, $char) = @_;
    
    # Simple heuristic: find statement boundaries by semicolons
    my $start_line = $line_num;
    my $end_line = $line_num;
    
    # Look backwards for statement start (previous semicolon or block start)
    for (my $i = $line_num; $i >= 0; $i--) {
        my $line = $lines->[$i];
        $start_line = $i;
        
        # Stop at block boundaries or previous semicolon
        if ($i < $line_num && $line =~ /;\s*$/) {
            $start_line = $i + 1;
            last;
        }
        if ($line =~ /\{\s*$/ || $line =~ /^\s*\}/) {
            last;
        }
    }
    
    # Look forwards for statement end
    for (my $i = $line_num; $i < @$lines; $i++) {
        my $line = $lines->[$i];
        $end_line = $i;
        
        # Stop at semicolon
        if ($line =~ /;/) {
            last;
        }
    }
    
    return undef if $start_line == $end_line && $lines->[$start_line] !~ /;.*[^;]$/;
    
    return {
        range => {
            start => { line => $start_line, character => 0 },
            end => { line => $end_line, character => length($lines->[$end_line]) },
        },
    };
}

sub _get_sub_range {
    my ($self, $lines, $line_num) = @_;
    
    # Find enclosing subroutine
    my $sub_start = -1;
    my $sub_end = -1;
    my $depth = 0;
    
    # Look backwards for sub definition
    for (my $i = $line_num; $i >= 0; $i--) {
        my $line = $lines->[$i];
        
        # Track brace depth
        my $close_count =()= $line =~ /\}/g;
        my $open_count =()= $line =~ /\{/g;
        $depth -= $close_count - $open_count;
        
        if ($line =~ /^\s*sub\s+\w+/ && $depth <= 0) {
            $sub_start = $i;
            last;
        }
    }
    
    return undef unless $sub_start >= 0;
    
    # Find subroutine end (matching closing brace)
    $depth = 0;
    for (my $i = $sub_start; $i < @$lines; $i++) {
        my $line = $lines->[$i];
        
        my $open_count =()= $line =~ /\{/g;
        my $close_count =()= $line =~ /\}/g;
        
        $depth += $open_count - $close_count;
        
        if ($depth <= 0 && $i > $sub_start) {
            $sub_end = $i;
            last;
        }
    }
    
    $sub_end = $#$lines if $sub_end < 0;
    
    return {
        range => {
            start => { line => $sub_start, character => 0 },
            end => { line => $sub_end, character => length($lines->[$sub_end]) },
        },
    };
}

sub _get_package_range {
    my ($self, $lines, $line_num) = @_;
    
    # Find enclosing package
    my $pkg_start = -1;
    my $pkg_end = -1;
    
    # Look backwards for package definition
    for (my $i = $line_num; $i >= 0; $i--) {
        if ($lines->[$i] =~ /^\s*package\s+/) {
            $pkg_start = $i;
            last;
        }
    }
    
    return undef unless $pkg_start >= 0;
    
    # Find package end (next package or EOF)
    for (my $i = $pkg_start + 1; $i < @$lines; $i++) {
        if ($lines->[$i] =~ /^\s*package\s+/) {
            $pkg_end = $i - 1;
            last;
        }
    }
    
    $pkg_end = $#$lines if $pkg_end < 0;
    
    return {
        range => {
            start => { line => $pkg_start, character => 0 },
            end => { line => $pkg_end, character => length($lines->[$pkg_end]) },
        },
    };
}

sub _build_linked_ranges {
    my ($self, $chain) = @_;
    
    return undef unless @$chain;
    
    # Link ranges from outermost to innermost
    my $parent = undef;
    for (my $i = $#$chain; $i >= 0; $i--) {
        $chain->[$i]{parent} = $parent;
        $parent = $chain->[$i];
    }
    
    return $chain->[0];
}

sub _range_equal {
    my ($r1, $r2) = @_;
    return (
        $r1->{range}{start}{line} == $r2->{range}{start}{line} &&
        $r1->{range}{start}{character} == $r2->{range}{start}{character} &&
        $r1->{range}{end}{line} == $r2->{range}{end}{line} &&
        $r1->{range}{end}{character} == $r2->{range}{end}{character}
    );
}

sub _range_in_chain {
    my ($range, $chain) = @_;
    
    foreach my $r (@$chain) {
        return 1 if _range_equal($range, $r);
    }
    return 0;
}

1;