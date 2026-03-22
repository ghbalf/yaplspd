package YAPLSPD::Diagnostics;
use strict;
use warnings;

sub new {
    my ($class) = @_;
    return bless {}, $class;
}

sub analyze_document {
    my ($self, $document) = @_;
    my $text = $document->text;
    my $diagnostics = [];
    my @lines = split(/\n/, $text);
    
    # Basic syntax checking
    my $open_braces = 0;
    my $open_brackets = 0;
    my $open_parens = 0;
    
    for (my $i = 0; $i < @lines; $i++) {
        my $line = $lines[$i];
        
        # Count brackets
        $open_braces += ($line =~ tr/{//) - ($line =~ tr/}//);
        $open_brackets += ($line =~ tr/\[//) - ($line =~ tr/\]//);
        $open_parens += ($line =~ tr/\(//) - ($line =~ tr/\)//);
        
        # Check for trailing whitespace
        if ($line =~ /([ \t]+)$/) {
            push @$diagnostics, {
                range => {
                    start => { line => $i, character => length($line) - length($1) },
                    end => { line => $i, character => length($line) }
                },
                severity => 3, # Info
                message => "Trailing whitespace",
                source => 'perl-lsp'
            };
        }
        
        # Check for lines longer than 120 characters
        if (length($line) > 120) {
            push @$diagnostics, {
                range => {
                    start => { line => $i, character => 120 },
                    end => { line => $i, character => length($line) }
                },
                severity => 2, # Warning
                message => "Line exceeds 120 characters",
                source => 'perl-lsp'
            };
        }
        
        # Check for missing semicolons (basic heuristic)
        if ($line =~ /\S$/ && $line !~ /[{};]$/ && $line !~ /^\s*#/ && $line !~ /^\s*$/) {
            push @$diagnostics, {
                range => {
                    start => { line => $i, character => length($line) },
                    end => { line => $i, character => length($line) + 1 }
                },
                severity => 2, # Warning
                message => "Possible missing semicolon",
                source => 'perl-lsp'
            };
        }
    }
    
    # Add bracket mismatch errors
    if ($open_braces != 0) {
        push @$diagnostics, {
            range => {
                start => { line => 0, character => 0 },
                end => { line => 0, character => 1 }
            },
            severity => 1, # Error
            message => "Unmatched braces: $open_braces unclosed",
            source => 'perl-lsp'
        };
    }
    
    if ($open_brackets != 0) {
        push @$diagnostics, {
            range => {
                start => { line => 0, character => 0 },
                end => { line => 0, character => 1 }
            },
            severity => 1, # Error
            message => "Unmatched brackets: $open_brackets unclosed",
            source => 'perl-lsp'
        };
    }
    
    if ($open_parens != 0) {
        push @$diagnostics, {
            range => {
                start => { line => 0, character => 0 },
                end => { line => 0, character => 1 }
            },
            severity => 1, # Error
            message => "Unmatched parentheses: $open_parens unclosed",
            source => 'perl-lsp'
        };
    }
    
    return $diagnostics;
}

1;