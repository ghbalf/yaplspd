package YAPLSPD::WorkspaceSymbol;
use strict;
use warnings;

# Symbol kinds from LSP
my %SYMBOL_KIND = (
    FILE => 1,
    MODULE => 2,
    NAMESPACE => 3,
    PACKAGE => 4,
    CLASS => 5,
    METHOD => 6,
    PROPERTY => 7,
    FIELD => 8,
    CONSTRUCTOR => 9,
    ENUM => 10,
    INTERFACE => 11,
    FUNCTION => 12,
    VARIABLE => 13,
    CONSTANT => 14,
    STRING => 15,
    NUMBER => 16,
    BOOLEAN => 17,
    ARRAY => 18,
    OBJECT => 19,
    KEY => 20,
    NULL => 21,
    ENUM_MEMBER => 22,
    STRUCT => 23,
    EVENT => 24,
    OPERATOR => 25,
    TYPE_PARAMETER => 26,
);

sub new {
    my ($class) = @_;
    bless {}, $class;
}

sub get_workspace_symbols {
    my ($self, $documents, $query) = @_;
    
    my @symbols;
    my $query_re = $query ? qr/\Q$query\E/i : undef;
    
    foreach my $uri (keys %$documents) {
        my $doc = $documents->{$uri};
        my $doc_symbols = $self->_get_document_symbols($doc, $uri, $query_re);
        push @symbols, @$doc_symbols;
    }
    
    return \@symbols;
}

sub _get_document_symbols {
    my ($self, $document, $uri, $query_re) = @_;
    
    my @symbols;
    my $text = $document->text;
    my @lines = split(/\n/, $text);
    
    my $current_package = 'main';
    
    for (my $i = 0; $i < @lines; $i++) {
        my $line = $lines[$i];
        
        # Packages
        if ($line =~ /^\s*package\s+(\w+(?:::\w+)*)/) {
            my $name = $1;
            $current_package = $name;
            
            if (!$query_re || $name =~ /$query_re/) {
                push @symbols, {
                    name => $name,
                    kind => $SYMBOL_KIND{PACKAGE},
                    location => {
                        uri => $uri,
                        range => {
                            start => { line => $i, character => 0 },
                            end => { line => $i, character => length($line) },
                        },
                    },
                    containerName => undef,
                };
            }
        }
        
        # Subroutines
        if ($line =~ /^\s*sub\s+(\w+)/) {
            my $name = $1;
            my $full_name = "$current_package::$name";
            
            if (!$query_re || $full_name =~ /$query_re/ || $name =~ /$query_re/) {
                push @symbols, {
                    name => $name,
                    kind => $SYMBOL_KIND{FUNCTION},
                    location => {
                        uri => $uri,
                        range => {
                            start => { line => $i, character => 0 },
                            end => { line => $i, character => length($line) },
                        },
                    },
                    containerName => $current_package,
                };
            }
        }
        
        # Constants (use constant)
        if ($line =~ /^\s*use\s+constant\s+(\w+)/) {
            my $name = $1;
            
            if (!$query_re || $name =~ /$query_re/) {
                push @symbols, {
                    name => $name,
                    kind => $SYMBOL_KIND{CONSTANT},
                    location => {
                        uri => $uri,
                        range => {
                            start => { line => $i, character => 0 },
                            end => { line => $i, character => length($line) },
                        },
                    },
                    containerName => $current_package,
                };
            }
        }
        
        # Global variables (our variables)
        while ($line =~ /\bour\s+([\$@%][\w_]+)/g) {
            my $name = $1;
            
            if (!$query_re || $name =~ /$query_re/) {
                push @symbols, {
                    name => $name,
                    kind => $SYMBOL_KIND{VARIABLE},
                    location => {
                        uri => $uri,
                        range => {
                            start => { line => $i, character => 0 },
                            end => { line => $i, character => length($line) },
                        },
                    },
                    containerName => $current_package,
                };
            }
        }
        
        # Labels
        if ($line =~ /^\s*(\w+):\s*$/) {
            my $name = $1;
            next if $name eq 'sub';  # Skip false positives
            
            if (!$query_re || $name =~ /$query_re/) {
                push @symbols, {
                    name => $name,
                    kind => $SYMBOL_KIND{KEY},  # Using KEY for labels
                    location => {
                        uri => $uri,
                        range => {
                            start => { line => $i, character => 0 },
                            end => { line => $i, character => length($line) },
                        },
                    },
                    containerName => $current_package,
                };
            }
        }
    }
    
    return \@symbols;
}

1;