package YAPLSPD::Formatting;
use strict;
use warnings;

# Try to load Perl::Tidy, fallback to basic formatting if not available
my $HAS_PERL_TIDY = eval { require Perl::Tidy; 1 };

sub new {
    my ($class) = @_;
    return bless {}, $class;
}

sub format_document {
    my ($self, $document) = @_;
    
    my $text = $document->text;
    
    # Try Perl::Tidy if available
    if ($HAS_PERL_TIDY) {
        my $formatted;
        my $error;
        
        # Perl::Tidy options - conservative, LSP-friendly
        my @options = (
            '-pbp',           # Perl Best Practices
            '-nst',          # No standard input/output
            '-se',           # Errors to stderr
            '-wbb="= + - * / %"',  # Break before operators
            '-l=100',        # Line length 100
            '-i=4',          # 4-space indentation
            '-ci=4',         # Continuation indentation
            '-vt=2',         # Vertical tightness
            '-pt=2',         # Parentheses tightness
            '-bt=2',         # Brace tightness
            '-sbt=2',        # Square bracket tightness
            '-bbt=1',        # Block brace tightness
            '-nsfs',         # No spaces before semicolon
            '-nolq',         # No outdenting long quotes
        );
        
        eval {
            local $SIG{__WARN__} = sub { $error = shift };
            my $result = Perl::Tidy::perltidy(
                source      => \\$text,
                destination => \\$formatted,
                argv        => \\@options,
            );
            
            if ($result == 0 && !$error) {
                return _create_text_edits($text, $formatted);
            }
        };
    }
    
    # Fallback: basic formatting if Perl::Tidy not available or failed
    return _basic_format($text);
}

sub _create_text_edits {
    my ($original, $formatted) = @_;
    
    # If no changes, return empty array
    return [] if $original eq $formatted;
    
    # Split into lines for LSP TextEdit
    my @original_lines = split(/\n/, $original);
    
    # Create full document replacement
    my $line_count = scalar(@original_lines);
    my $last_line_length = length($original_lines[-1] || '');
    
    return [{
        range => {
            start => { line => 0, character => 0 },
            end => { 
                line => $line_count - 1, 
                character => $last_line_length 
            }
        },
        newText => $formatted
    }];
}

sub _basic_format {
    my ($text) = @_;
    
    # Basic formatting: trim trailing whitespace, ensure consistent indentation
    my @lines = split(/\n/, $text);
    my @formatted;
    my $in_pod = 0;
    
    foreach my $line (@lines) {
        # Handle POD sections
        if ($line =~ /^=\w/) {
            $in_pod = 1;
        } elsif ($line =~ /^=cut/) {
            $in_pod = 0;
        }
        
        # Basic cleanup: remove trailing whitespace
        $line =~ s/\s+$//;
        
        push @formatted, $line;
    }
    
    my $formatted = join("\n", @formatted);
    $formatted .= "\n" unless $formatted =~ /\n$/;
    
    return _create_text_edits($text, $formatted);
}

sub format_range {
    my ($self, $document, $range) = @_;
    
    my $text = $document->text;
    my @lines = split(/\n/, $text);
    
    my $start_line = $range->{start}{line};
    my $end_line = $range->{end}{line};
    
    # Clamp to document bounds
    $start_line = 0 if $start_line < 0;
    $end_line = $#lines if $end_line > $#lines;
    
    # Extract range text
    my @range_lines = @lines[$start_line..$end_line];
    my $range_text = join("\n", @range_lines);
    
    # Try Perl::Tidy on the range
    my $formatted;
    if ($HAS_PERL_TIDY) {
        my $error;
        my @options = (
            '-pbp', '-nst', '-se',
            '-wbb="= + - * / %"',
            '-l=100', '-i=4', '-ci=4',
            '-vt=2', '-pt=2', '-bt=2',
            '-sbt=2', '-bbt=1',
            '-nsfs', '-nolq',
        );
        
        eval {
            local $SIG{__WARN__} = sub { $error = shift };
            my $result = Perl::Tidy::perltidy(
                source      => \$range_text,
                destination => \$formatted,
                argv        => \@options,
            );
            
            if ($result == 0 && !$error) {
                return _create_range_text_edits($start_line, $end_line, \@lines, $formatted);
            }
        };
    }
    
    # Fallback: basic formatting for range
    return _basic_format_range($start_line, $end_line, \@lines);
}

sub _create_range_text_edits {
    my ($start_line, $end_line, $lines, $formatted) = @_;
    
    my $original = join("\n", @$lines[$start_line..$end_line]);
    return [] if $original eq $formatted;
    
    my $last_line_idx = $end_line;
    my $last_line = $lines->[$last_line_idx] || '';
    
    return [{
        range => {
            start => { line => $start_line, character => 0 },
            end   => { 
                line => $last_line_idx, 
                character => length($last_line)
            }
        },
        newText => $formatted
    }];
}

sub _basic_format_range {
    my ($start_line, $end_line, $lines) = @_;
    
    my @range_lines = @$lines[$start_line..$end_line];
    my @formatted;
    
    foreach my $line (@range_lines) {
        $line =~ s/\s+$//;
        push @formatted, $line;
    }
    
    my $formatted = join("\n", @formatted);
    $formatted .= "\n" unless $formatted =~ /\n$/;
    
    return _create_range_text_edits($start_line, $end_line, $lines, $formatted);
}

1;