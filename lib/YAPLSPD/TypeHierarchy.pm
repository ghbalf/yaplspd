package YAPLSPD::TypeHierarchy;
use strict;
use warnings;

# Try to load PPI, but make it optional for testing
my $HAS_PPI = 0;
eval {
    require PPI;
    $HAS_PPI = 1;
};

# SymbolKind constants
use constant {
    SYMBOL_KIND_CLASS => 5,
    SYMBOL_KIND_INTERFACE => 11,
    SYMBOL_KIND_NAMESPACE => 3,
};

sub new {
    my ($class) = @_;
    return bless {}, $class;
}

# Prepare type hierarchy items at a given position
sub prepare_type_hierarchy {
    my ($self, $document, $position) = @_;
    
    my $line = $position->{line};
    my $character = $position->{character};
    
    # Get word at position
    my $word = $self->_get_word_at_position($document, $line, $character) or return [];
    
    # Find the package or class definition for this word
    my $location = $self->_find_package_definition($document, $word);
    return [] unless $location;
    
    # Build type hierarchy item
    my $item = {
        name => $word,
        kind => SYMBOL_KIND_CLASS,
        uri => $document->uri,
        range => $location->{range},
        selectionRange => $location->{range},
    };
    
    return [$item];
}

# Find supertypes (parent classes)
sub supertypes {
    my ($self, $document, $item) = @_;
    
    my $type_name = $item->{name};
    my @supertypes;
    
    if ($HAS_PPI && $document->can('ppi_document')) {
        @supertypes = $self->_find_supertypes_with_ppi($document, $type_name);
    } else {
        @supertypes = $self->_find_supertypes_fallback($document, $type_name);
    }
    
    return \@supertypes;
}

# Find subtypes (child classes) - limited to current document for now
sub subtypes {
    my ($self, $document, $item) = @_;
    
    my $type_name = $item->{name};
    my @subtypes;
    
    if ($HAS_PPI && $document->can('ppi_document')) {
        @subtypes = $self->_find_subtypes_with_ppi($document, $type_name);
    } else {
        @subtypes = $self->_find_subtypes_fallback($document, $type_name);
    }
    
    return \@subtypes;
}

# Private methods

sub _get_word_at_position {
    my ($self, $document, $line, $character) = @_;
    
    my $text = $document->text;
    my @lines = split(/\n/, $text);
    return unless $line >= 0 && $line < @lines;
    
    my $line_text = $lines[$line];
    
    # Find word at character position
    my $start = $character;
    while ($start > 0 && substr($line_text, $start - 1, 1) =~ /[a-zA-Z0-9_:]/) {
        $start--;
    }
    
    my $end = $character;
    while ($end < length($line_text) && substr($line_text, $end, 1) =~ /[a-zA-Z0-9_:]/) {
        $end++;
    }
    
    my $word = substr($line_text, $start, $end - $start);
    # Allow package names with ::
    return $word if $word =~ /^[a-zA-Z_][a-zA-Z0-9_:]*$/;
    
    return;
}

sub _find_package_definition {
    my ($self, $document, $word) = @_;
    
    if ($HAS_PPI && $document->can('ppi_document')) {
        my $ppi = eval { $document->ppi_document() };
        if ($ppi && !$@) {
            # Find package declarations
            my $packages = $ppi->find('PPI::Statement::Package');
            if ($packages) {
                foreach my $pkg (@$packages) {
                    my $name = $pkg->namespace;
                    next unless $name && ($name eq $word || $name =~ /\b\Q$word\E$/);
                    
                    my $location = $pkg->location;
                    next unless $location && ref($location) eq 'HASH';
                    
                    return {
                        uri => $document->uri,
                        range => {
                            start => {
                                line => $location->{line} - 1,
                                character => $location->{column} - 1,
                            },
                            end => {
                                line => $location->{line} - 1,
                                character => $location->{column} - 1 + length($name),
                            },
                        },
                    };
                }
            }
        }
    }
    
    # Fallback: regex search for package declaration
    my $text = $document->text;
    my @lines = split(/\n/, $text);
    
    for (my $i = 0; $i < @lines; $i++) {
        if ($lines[$i] =~ /^\s*package\s+([a-zA-Z_][a-zA-Z0-9_:]*\b)?\Q$word\E\b/) {
            my $full_pkg = $1 ? $1 . $word : $word;
            my $char_pos = index($lines[$i], $full_pkg);
            $char_pos = index($lines[$i], 'package') + 8 if $char_pos < 0;
            
            return {
                uri => $document->uri,
                range => {
                    start => { line => $i, character => $char_pos },
                    end => { line => $i, character => $char_pos + length($full_pkg) },
                },
            };
        }
    }
    
    return;
}

sub _find_supertypes_with_ppi {
    my ($self, $document, $type_name) = @_;
    
    return () unless $document->can('ppi_document');
    my $ppi = eval { $document->ppi_document() } or return ();
    my @supertypes;
    
    # Find the package declaration for this type
    my $packages = $ppi->find('PPI::Statement::Package') or return ();
    my $target_pkg;
    
    foreach my $pkg (@$packages) {
        if ($pkg->namespace eq $type_name) {
            $target_pkg = $pkg;
            last;
        }
    }
    
    return () unless $target_pkg;
    
    # Look for @ISA, use base, use parent in the same scope
    my $ppi_doc = $document->ppi_document();
    
    # Method 1: Find @ISA assignments
    my $isa_assignments = $ppi_doc->find(sub {
        my ($root, $node) = @_;
        return 0 unless $node->isa('PPI::Token::Symbol');
        return 0 unless $node->content eq '@ISA';
        # Check if it's in the same package scope
        my $stmt = $node->statement;
        return 0 unless $stmt;
        return 1;
    });
    
    if ($isa_assignments) {
        foreach my $isa (@$isa_assignments) {
            my $stmt = $isa->statement;
            next unless $stmt;
            
            # Check if this @ISA is in our target package scope
            my $stmt_location = $stmt->location;
            next unless $stmt_location && ref($stmt_location) eq 'HASH';
            
            # Find all string/quote tokens in this statement (parent classes)
            my $strings = $stmt->find('PPI::Token::Quote');
            if ($strings) {
                foreach my $str (@$strings) {
                    my $parent = $str->string;
                    next unless $parent;
                    
                    my $str_loc = $str->location;
                    my $range = $str_loc && ref($str_loc) eq 'HASH' ? {
                        start => {
                            line => $str_loc->{line} - 1,
                            character => $str_loc->{column} - 1,
                        },
                        end => {
                            line => $str_loc->{line} - 1,
                            character => $str_loc->{column} - 1 + length($str->content),
                        },
                    } : {
                        start => { line => $stmt_location->{line} - 1, character => 0 },
                        end => { line => $stmt_location->{line} - 1, character => length($parent) },
                    };
                    
                    push @supertypes, {
                        name => $parent,
                        kind => SYMBOL_KIND_CLASS,
                        uri => $document->uri,
                        range => $range,
                        selectionRange => $range,
                    };
                }
            }
            
            # Also check for barewords (unquoted package names)
            my $words = $stmt->find('PPI::Token::Word');
            if ($words) {
                foreach my $word (@$words) {
                    my $content = $word->content;
                    next if $content =~ /^(?:our|my|local|qw|qq|q)$/;
                    next unless $content =~ /^[a-zA-Z_][a-zA-Z0-9_:]+$/;
                    
                    my $word_loc = $word->location;
                    my $range = $word_loc && ref($word_loc) eq 'HASH' ? {
                        start => {
                            line => $word_loc->{line} - 1,
                            character => $word_loc->{column} - 1,
                        },
                        end => {
                            line => $word_loc->{line} - 1,
                            character => $word_loc->{column} - 1 + length($content),
                        },
                    } : {
                        start => { line => $stmt_location->{line} - 1, character => 0 },
                        end => { line => $stmt_location->{line} - 1, character => length($content) },
                    };
                    
                    push @supertypes, {
                        name => $content,
                        kind => SYMBOL_KIND_CLASS,
                        uri => $document->uri,
                        range => $range,
                        selectionRange => $range,
                    };
                }
            }
        }
    }
    
    # Method 2: Find "use base" or "use parent"
    my $includes = $ppi_doc->find('PPI::Statement::Include');
    if ($includes) {
        foreach my $inc (@$includes) {
            my $module = $inc->module;
            next unless $module && ($module eq 'base' || $module eq 'parent');
            
            # Get arguments (parent classes)
            my @args = $inc->arguments;
            foreach my $arg (@args) {
                if ($arg->isa('PPI::Token::Quote')) {
                    my $parent = $arg->string;
                    next unless $parent;
                    
                    my $arg_loc = $arg->location;
                    my $range = $arg_loc && ref($arg_loc) eq 'HASH' ? {
                        start => {
                            line => $arg_loc->{line} - 1,
                            character => $arg_loc->{column} - 1,
                        },
                        end => {
                            line => $arg_loc->{line} - 1,
                            character => $arg_loc->{column} - 1 + length($arg->content),
                        },
                    } : {
                        start => { line => 0, character => 0 },
                        end => { line => 0, character => length($parent) },
                    };
                    
                    push @supertypes, {
                        name => $parent,
                        kind => SYMBOL_KIND_CLASS,
                        uri => $document->uri,
                        range => $range,
                        selectionRange => $range,
                    };
                }
            }
        }
    }
    
    return @supertypes;
}

sub _find_supertypes_fallback {
    my ($self, $document, $type_name) = @_;
    
    my $text = $document->text;
    my @lines = split(/\n/, $text);
    my @supertypes;
    my $in_package = 0;
    my $current_package = '';
    
    for (my $i = 0; $i < @lines; $i++) {
        my $line = $lines[$i];
        
        # Track current package
        if ($line =~ /^\s*package\s+([a-zA-Z_][a-zA-Z0-9_:]*)\s*;/) {
            $current_package = $1;
            $in_package = ($current_package eq $type_name);
            next;
        }
        
        next unless $in_package;
        
        # Check for @ISA assignment - handle qw(), quoted strings, and parentheses
        if ($line =~ /\@ISA\s*=\s*(.+?);/) {
            my $isa_content = $1;
            $isa_content =~ s/^\s+//;
            $isa_content =~ s/\s+$//;
            
            # Check for qw() list first - handle qw(...), qw[...], qw{...}
            if ($isa_content =~ /qw\s*([\(\[\{])([^\)\]\}]+)[\)\]\}]/) {
                my @parents = split(/\s+/, $2);
                foreach my $parent (@parents) {
                    next unless $parent =~ /^[a-zA-Z_][a-zA-Z0-9_:]*$/;
                    
                    my $char_pos = index($line, $parent);
                    $char_pos = 0 if $char_pos < 0;
                    
                    push @supertypes, {
                        name => $parent,
                        kind => SYMBOL_KIND_CLASS,
                        uri => $document->uri,
                        range => {
                            start => { line => $i, character => $char_pos },
                            end => { line => $i, character => $char_pos + length($parent) },
                        },
                        selectionRange => {
                            start => { line => $i, character => $char_pos },
                            end => { line => $i, character => $char_pos + length($parent) },
                        },
                    };
                }
            }
            # Extract quoted strings
            elsif ($isa_content =~ /(["'])([a-zA-Z_][a-zA-Z0-9_:]*)\1/) {
                my $parent = $2;
                my $char_pos = index($line, $parent);
                $char_pos = 0 if $char_pos < 0;
                
                push @supertypes, {
                    name => $parent,
                    kind => SYMBOL_KIND_CLASS,
                    uri => $document->uri,
                    range => {
                        start => { line => $i, character => $char_pos },
                        end => { line => $i, character => $char_pos + length($parent) },
                        },
                    selectionRange => {
                        start => { line => $i, character => $char_pos },
                        end => { line => $i, character => $char_pos + length($parent) },
                    },
                };
            }
        }
        
        # Check for "use base" or "use parent"
        if ($line =~ /^\s*use\s+(base|parent)\s+(?:qw)?[\s'"]*([a-zA-Z_][a-zA-Z0-9_:]*)["']?/) {
            my $parent = $2;
            my $char_pos = index($line, $parent);
            $char_pos = 0 if $char_pos < 0;
            
            push @supertypes, {
                name => $parent,
                kind => SYMBOL_KIND_CLASS,
                uri => $document->uri,
                range => {
                    start => { line => $i, character => $char_pos },
                    end => { line => $i, character => $char_pos + length($parent) },
                },
                selectionRange => {
                    start => { line => $i, character => $char_pos },
                    end => { line => $i, character => $char_pos + length($parent) },
                },
            };
        }
    }
    
    return @supertypes;
}

sub _find_subtypes_with_ppi {
    my ($self, $document, $type_name) = @_;
    
    return () unless $document->can('ppi_document');
    my $ppi = eval { $document->ppi_document() } or return ();
    my @subtypes;
    
    # Find all package declarations
    my $packages = $ppi->find('PPI::Statement::Package') or return ();
    
    foreach my $pkg (@$packages) {
        my $pkg_name = $pkg->namespace;
        next unless $pkg_name;
        next if $pkg_name eq $type_name;  # Skip self
        
        # Check if this package inherits from type_name
        my $inherits = 0;
        
        # Get location for range
        my $pkg_loc = $pkg->location;
        my $pkg_range = $pkg_loc && ref($pkg_loc) eq 'HASH' ? {
            start => {
                line => $pkg_loc->{line} - 1,
                character => $pkg_loc->{column} - 1,
            },
            end => {
                line => $pkg_loc->{line} - 1,
                character => $pkg_loc->{column} - 1 + length($pkg_name),
            },
        } : undef;
        
        next unless $pkg_range;
        
        # Check @ISA
        my $ppi_doc = $document->ppi_document();
        my $isa_assignments = $ppi_doc->find(sub {
            my ($root, $node) = @_;
            return 0 unless $node->isa('PPI::Token::Symbol');
            return $node->content eq '@ISA';
        });
        
        if ($isa_assignments) {
            foreach my $isa (@$isa_assignments) {
                my $stmt = $isa->statement;
                next unless $stmt;
                
                # Check if @ISA contains type_name
                my $strings = $stmt->find('PPI::Token::Quote');
                if ($strings) {
                    foreach my $str (@$strings) {
                        if ($str->string eq $type_name) {
                            $inherits = 1;
                            last;
                        }
                    }
                }
                
                last if $inherits;
            }
        }
        
        # Check use base/parent
        if (!$inherits) {
            my $includes = $ppi_doc->find('PPI::Statement::Include');
            if ($includes) {
                foreach my $inc (@$includes) {
                    my $module = $inc->module;
                    next unless $module && ($module eq 'base' || $module eq 'parent');
                    
                    my @args = $inc->arguments;
                    foreach my $arg (@args) {
                        if ($arg->isa('PPI::Token::Quote') && $arg->string eq $type_name) {
                            $inherits = 1;
                            last;
                        }
                    }
                    
                    last if $inherits;
                }
            }
        }
        
        if ($inherits) {
            push @subtypes, {
                name => $pkg_name,
                kind => SYMBOL_KIND_CLASS,
                uri => $document->uri,
                range => $pkg_range,
                selectionRange => $pkg_range,
            };
        }
    }
    
    return @subtypes;
}

sub _find_subtypes_fallback {
    my ($self, $document, $type_name) = @_;
    
    my $text = $document->text;
    my @lines = split(/\n/, $text);
    my @subtypes;
    my $current_package = '';
    my $current_pkg_line = 0;
    my @current_isa;
    
    for (my $i = 0; $i < @lines; $i++) {
        my $line = $lines[$i];
        
        # Track package declaration
        if ($line =~ /^\s*package\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*;/) {
            # Check previous package for inheritance
            if ($current_package && $current_package ne $type_name) {
                foreach my $isa (@current_isa) {
                    if ($isa eq $type_name) {
                        my $char_pos = index($lines[$current_pkg_line], $current_package);
                        $char_pos = 8 if $char_pos < 0;
                        
                        push @subtypes, {
                            name => $current_package,
                            kind => SYMBOL_KIND_CLASS,
                            uri => $document->uri,
                            range => {
                                start => { line => $current_pkg_line, character => $char_pos },
                                end => { line => $current_pkg_line, character => $char_pos + length($current_package) },
                            },
                            selectionRange => {
                                start => { line => $current_pkg_line, character => $char_pos },
                                end => { line => $current_pkg_line, character => $char_pos + length($current_package) },
                            },
                        };
                        last;
                    }
                }
            }
            
            $current_package = $1;
            $current_pkg_line = $i;
            @current_isa = ();
        }
        
        next unless $current_package;
        
        # Check for @ISA assignment - handle qw(), quoted strings, and parentheses
        if ($line =~ /\@ISA\s*=\s*(.+?);/) {
            my $isa_content = $1;
            $isa_content =~ s/^\s+//;
            $isa_content =~ s/\s+$//;
            
            # Check for qw() list first - handle qw(...), qw[...], qw{...}
            if ($isa_content =~ /qw\s*([\(\[\{])([^\)\]\}]+)[\)\]\}]/) {
                my @parents = split(/\s+/, $2);
                foreach my $parent (@parents) {
                    push @current_isa, $parent if $parent =~ /^[a-zA-Z_][a-zA-Z0-9_:]*$/;
                }
            }
            # Extract quoted strings
            elsif ($isa_content =~ /(["'])([a-zA-Z_][a-zA-Z0-9_:]*)\1/) {
                push @current_isa, $2;
            }
        }
        
        # Check for "use base" or "use parent"
        if ($line =~ /^\s*use\s+(base|parent)\s+(?:qw)?[\s'"]*([a-zA-Z_][a-zA-Z0-9_:]*)["']?/) {
            push @current_isa, $2;
        }
    }
    
    # Check last package
    if ($current_package && $current_package ne $type_name) {
        foreach my $isa (@current_isa) {
            if ($isa eq $type_name) {
                my $char_pos = index($lines[$current_pkg_line], $current_package);
                $char_pos = 8 if $char_pos < 0;
                
                push @subtypes, {
                    name => $current_package,
                    kind => SYMBOL_KIND_CLASS,
                    uri => $document->uri,
                    range => {
                        start => { line => $current_pkg_line, character => $char_pos },
                        end => { line => $current_pkg_line, character => $char_pos + length($current_package) },
                    },
                    selectionRange => {
                        start => { line => $current_pkg_line, character => $char_pos },
                        end => { line => $current_pkg_line, character => $char_pos + length($current_package) },
                    },
                };
                last;
            }
        }
    }
    
    return @subtypes;
}

1;
