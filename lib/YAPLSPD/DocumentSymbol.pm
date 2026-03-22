package YAPLSPD::DocumentSymbol;

use strict;
use warnings;
use LSP::Types qw(FUNCTION MODULE VARIABLE);

# Try to load PPI, but make it optional
my $HAS_PPI = 0;
eval {
    require PPI;
    $HAS_PPI = 1;
};

sub new {
    my ($class, $document) = @_;
    return bless { document => $document }, $class;
}

sub get_document_symbols {
    my ($self) = @_;
    my $document = $self->{document};
    
    return [] unless $document;
    
    my $text = $document->text;
    return [] unless defined $text;
    
    # Try PPI first if available
    if ($HAS_PPI && $document->ppi_document) {
        return $self->_get_symbols_with_ppi($document);
    }
    
    # Fallback to regex-based parsing
    return $self->_get_symbols_fallback($text);
}

sub _get_symbols_with_ppi {
    my ($self, $document) = @_;
    my $ppi_document = $document->ppi_document;
    
    return [] unless $ppi_document;
    
    my @symbols;
    
    # Suche nach Subroutinen
    my $subs = $ppi_document->find('PPI::Statement::Sub');
    if ($subs) {
        foreach my $sub (@$subs) {
            my $name = $sub->name;
            next unless defined $name;
            
            push @symbols, {
                name => $name,
                kind => FUNCTION,
                range => _ppi_node_to_range($sub),
                selectionRange => _ppi_node_to_range($sub),
            };
        }
    }
    
    # Suche nach Package-Deklarationen
    my $packages = $ppi_document->find('PPI::Statement::Package');
    if ($packages) {
        foreach my $package (@$packages) {
            my $namespace = $package->namespace;
            next unless defined $namespace;
            
            push @symbols, {
                name => $namespace,
                kind => MODULE,
                range => _ppi_node_to_range($package),
                selectionRange => _ppi_node_to_range($package),
            };
        }
    }
    
    # Suche nach Variablen-Deklarationen (my/our/state)
    my $vars = $ppi_document->find(sub {
        my ($parent, $element) = @_;
        return $element->isa('PPI::Statement::Variable');
    });
    
    if ($vars) {
        foreach my $var_stmt (@$vars) {
            my $vars = $var_stmt->find('PPI::Token::Symbol');
            if ($vars) {
                foreach my $var (@$vars) {
                    push @symbols, {
                        name => $var->content,
                        kind => VARIABLE,
                        range => _ppi_node_to_range($var_stmt),
                        selectionRange => _ppi_node_to_range($var),
                    };
                }
            }
        }
    }
    
    return [ sort { $a->{range}{start}{line} <=> $b->{range}{start}{line} } @symbols ];
}

sub _get_symbols_fallback {
    my ($self, $text) = @_;
    
    my @symbols;
    my @lines = split(/\n/, $text);
    
    for my $line_num (0..$#lines) {
        my $line = $lines[$line_num];
        
        # Match package declarations
        if ($line =~ /^\s*package\s+(\w+(?:::\w+)*)/) {
            my $package_name = $1;
            my $start_char = index($line, $package_name);
            
            push @symbols, {
                name => $package_name,
                kind => MODULE,
                range => {
                    start => { line => $line_num, character => 0 },
                    end => { line => $line_num, character => length($line) }
                },
                selectionRange => {
                    start => { line => $line_num, character => $start_char },
                    end => { line => $line_num, character => $start_char + length($package_name) }
                },
            };
        }
        
        # Match subroutine declarations (sub NAME)
        elsif ($line =~ /^\s*sub\s+(\w+)/) {
            my $sub_name = $1;
            my $start_char = index($line, $sub_name);
            
            push @symbols, {
                name => $sub_name,
                kind => FUNCTION,
                range => {
                    start => { line => $line_num, character => 0 },
                    end => { line => $line_num, character => length($line) }
                },
                selectionRange => {
                    start => { line => $line_num, character => $start_char },
                    end => { line => $line_num, character => $start_char + length($sub_name) }
                },
            };
        }
        
        # Match variable declarations (my/our/state)
        while ($line =~ /\b(my|our|state)\s+([\$@%][\w_]+)/g) {
            my $var_name = $2;
            my $pos = pos($line) - length($var_name);
            
            push @symbols, {
                name => $var_name,
                kind => VARIABLE,
                range => {
                    start => { line => $line_num, character => 0 },
                    end => { line => $line_num, character => length($line) }
                },
                selectionRange => {
                    start => { line => $line_num, character => $pos },
                    end => { line => $line_num, character => $pos + length($var_name) }
                },
            };
        }
    }
    
    return [ sort { $a->{range}{start}{line} <=> $b->{range}{start}{line} } @symbols ];
}

sub _ppi_node_to_range {
    my ($node) = @_;
    my $location = $node->location;
    
    # PPI location can be ARRAY [line, col, end_line, end_col] or HASH
    my ($line, $col, $end_line, $end_col);
    
    if (ref($location) eq 'ARRAY') {
        $line = $location->[0];
        $col = $location->[1];
        $end_line = $location->[2] || $line;
        $end_col = $location->[3] || $col;
    } else {
        $line = $location->{line};
        $col = $location->{column};
        $end_line = $location->{end_line} || $line;
        $end_col = $location->{end_column} || $col;
    }
    
    return {
        start => {
            line => $line - 1,  # Convert to 0-based
            character => $col - 1
        },
        end => {
            line => $end_line - 1,
            character => $end_col
        }
    };
}

1;

__END__

=head1 NAME

YAPLSPD::DocumentSymbol - LSP Document Symbol Provider for Perl

=head1 SYNOPSIS

  use YAPLSPD::DocumentSymbol;
  
  my $symbol_provider = YAPLSPD::DocumentSymbol->new($document);
  my $symbols = $symbol_provider->get_document_symbols;

=head1 DESCRIPTION

Provides document symbol information for Perl files, including subroutines,
packages, and variable declarations.

Works with or without PPI (PPI is preferred for accuracy, regex fallback
for systems without PPI).

=cut
