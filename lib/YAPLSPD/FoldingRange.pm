package YAPLSPD::FoldingRange;
use strict;
use warnings;

# LSP FoldingRangeKind
my $KIND_COMMENT = 'comment';
my $KIND_REGION = 'region';
my $KIND_IMPORTS = 'imports';

sub new {
    my ($class) = @_;
    bless {}, $class;
}

sub get_folding_ranges {
    my ($self, $document) = @_;
    
    my @ranges;
    my $text = $document->text;
    my @lines = split(/\n/, $text);
    
    # Stack for tracking block starts
    my @block_stack;  # { type => 'sub|package|block', start_line => N }
    my @pod_stack;    # Track POD start lines
    my @comment_stack;# Track comment block starts
    
    my $in_pod = 0;
    my $in_comment_block = 0;
    my $comment_start_line = -1;
    
    for (my $i = 0; $i < @lines; $i++) {
        my $line = $lines[$i];
        my $indent = length($line) - length($line =~ s/^\s+//r);
        
        # Handle POD
        if ($line =~ /^=(\w+)/) {
            my $command = $1;
            if (!$in_pod && $command ne 'cut') {
                $in_pod = 1;
                push @pod_stack, $i;
            }
            elsif ($in_pod && $command eq 'cut') {
                my $start = pop @pod_stack;
                if (defined $start) {
                    push @ranges, {
                        startLine => $start,
                        endLine => $i,
                        kind => $KIND_COMMENT,
                    };
                }
                $in_pod = 0;
            }
            next;
        }
        
        next if $in_pod;
        
        # Handle comment blocks
        if ($line =~ /^\s*#/) {
            if (!$in_comment_block) {
                $in_comment_block = 1;
                $comment_start_line = $i;
            }
        }
        elsif ($in_comment_block && $line !~ /^\s*$/) {
            # End of comment block (at least 2 consecutive comment lines)
            if ($i - $comment_start_line >= 2) {
                push @ranges, {
                    startLine => $comment_start_line,
                    endLine => $i - 1,
                    kind => $KIND_COMMENT,
                };
            }
            $in_comment_block = 0;
        }
        elsif ($line =~ /^\s*$/) {
            # Empty line - keep comment block going
        }
        else {
            $in_comment_block = 0;
        }
        
        # Handle subroutines
        if ($line =~ /^\s*sub\s+(\w+)/) {
            push @block_stack, { type => 'sub', name => $1, start_line => $i, indent => $indent };
        }
        # Handle packages
        elsif ($line =~ /^\s*package\s+(\w+)/) {
            push @block_stack, { type => 'package', name => $1, start_line => $i, indent => $indent };
        }
        # Handle block endings (heuristic based on closing brace)
        elsif ($line =~ /^\s*\}\s*(?:#.*)?$/) {
            # Find matching opening block
            my @matching_indices = grep { $block_stack[$_]{indent} == $indent } 0..$#block_stack;
            if (@matching_indices) {
                my $idx = $matching_indices[-1];
                my $block = splice @block_stack, $idx, 1;
                
                # Only fold if block has at least 3 lines
                if ($i - $block->{start_line} >= 2) {
                    push @ranges, {
                        startLine => $block->{start_line},
                        endLine => $i,
                        kind => $block->{type} eq 'sub' ? 'subroutine' : undef,
                    };
                }
            }
        }
    }
    
    # Close any remaining open blocks
    foreach my $block (@block_stack) {
        my $end_line = scalar(@lines) - 1;
        if ($end_line - $block->{start_line} >= 2) {
            push @ranges, {
                startLine => $block->{start_line},
                endLine => $end_line,
                kind => $block->{type} eq 'sub' ? 'subroutine' : undef,
            };
        }
    }
    
    # Handle multiline strings (q{}, qq{}, qw{}, heredocs)
    push @ranges, $self->_find_multiline_strings(\@lines);
    
    # Handle import blocks (use/require statements)
    push @ranges, $self->_find_import_blocks(\@lines);
    
    return \@ranges;
}

sub _find_multiline_strings {
    my ($self, $lines) = @_;
    
    my @ranges;
    my $in_heredoc = 0;
    my $heredoc_delim = '';
    my $heredoc_start = -1;
    
    for (my $i = 0; $i < @$lines; $i++) {
        my $line = $lines->[$i];
        
        if ($in_heredoc) {
            if ($line =~ /^$heredoc_delim\s*$/) {
                push @ranges, {
                    startLine => $heredoc_start,
                    endLine => $i,
                };
                $in_heredoc = 0;
                $heredoc_delim = '';
            }
        }
        else {
            # Check for heredoc start
            if ($line =~ /<<\s*['"]?([^\s;'"]+)['"]?/) {
                $heredoc_delim = $1;
                $heredoc_start = $i;
                $in_heredoc = 1;
            }
        }
    }
    
    return @ranges;
}

sub _find_import_blocks {
    my ($self, $lines) = @_;
    
    my @ranges;
    my $import_start = -1;
    my $import_end = -1;
    
    for (my $i = 0; $i < @$lines; $i++) {
        my $line = $lines->[$i];
        
        if ($line =~ /^\s*(?:use|require|no)\s+/) {
            if ($import_start < 0) {
                $import_start = $i;
            }
            $import_end = $i;
        }
        elsif ($import_start >= 0 && $line !~ /^\s*$/ && $line !~ /^\s*#/) {
            # End of import block
            if ($import_end - $import_start >= 2) {
                push @ranges, {
                    startLine => $import_start,
                    endLine => $import_end,
                    kind => $KIND_IMPORTS,
                };
            }
            $import_start = -1;
            $import_end = -1;
        }
    }
    
    # Handle imports at end of file
    if ($import_start >= 0 && $import_end - $import_start >= 2) {
        push @ranges, {
            startLine => $import_start,
            endLine => $import_end,
            kind => $KIND_IMPORTS,
        };
    }
    
    return @ranges;
}

1;