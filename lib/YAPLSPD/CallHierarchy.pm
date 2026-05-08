package YAPLSPD::CallHierarchy;
use strict;
use warnings;

# Try to load PPI, but make it optional for testing
my $HAS_PPI = 0;
eval {
    require PPI;
    $HAS_PPI = 1;
};

sub new {
    my ($class) = @_;
    return bless {}, $class;
}

# Prepare call hierarchy items at a given position
sub prepare_call_hierarchy {
    my ($self, $document, $position) = @_;
    
    my $line = $position->{line};
    my $character = $position->{character};
    
    # Get word at position
    my $word = $self->_get_word_at_position($document, $line, $character) or return [];
    
    # Find the subroutine definition for this word
    my $location = $self->_find_sub_definition($document, $word);
    return [] unless $location;
    
    # Build call hierarchy item
    my $item = {
        name => $word,
        kind => 12,  # SymbolKind::Function
        uri => $document->uri,
        range => $location->{range},
        selectionRange => $location->{range},
    };
    
    return [$item];
}

# Find incoming calls (who calls this function)
sub incoming_calls {
    my ($self, $document, $item) = @_;
    
    my $target_name = $item->{name};
    my @incoming;
    
    if ($HAS_PPI && $document->can('ppi_document')) {
        @incoming = $self->_find_incoming_with_ppi($document, $target_name);
    } else {
        @incoming = $self->_find_incoming_fallback($document, $target_name);
    }
    
    return \@incoming;
}

# Find outgoing calls (what this function calls)
sub outgoing_calls {
    my ($self, $document, $item) = @_;
    
    my $func_name = $item->{name};
    my @outgoing;
    
    if ($HAS_PPI && $document->can('ppi_document')) {
        @outgoing = $self->_find_outgoing_with_ppi($document, $func_name);
    } else {
        @outgoing = $self->_find_outgoing_fallback($document, $func_name);
    }
    
    return \@outgoing;
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
    while ($start > 0 && substr($line_text, $start - 1, 1) =~ /[a-zA-Z0-9_]/) {
        $start--;
    }
    
    my $end = $character;
    while ($end < length($line_text) && substr($line_text, $end, 1) =~ /[a-zA-Z0-9_]/) {
        $end++;
    }
    
    my $word = substr($line_text, $start, $end - $start);
    return $word if $word =~ /^[a-zA-Z_][a-zA-Z0-9_]*$/;
    
    return;
}

sub _find_sub_definition {
    my ($self, $document, $word) = @_;
    
    if ($HAS_PPI && $document->can('ppi_document')) {
        my $ppi = eval { $document->ppi_document() };
        if ($ppi && !$@) {
            my $subs = $ppi->find('PPI::Statement::Sub');
            if ($subs) {
                foreach my $sub (@$subs) {
                    my $name = $sub->name;
                    next unless $name && $name eq $word;
                    
                    my $location = $sub->location;
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
    
    # Fallback: regex search
    my $text = $document->text;
    my @lines = split(/\n/, $text);
    
    for (my $i = 0; $i < @lines; $i++) {
        if ($lines[$i] =~ /^\s*sub\s+\b\Q$word\E\b/) {
            my $char_pos = index($lines[$i], $word);
            $char_pos = 4 if $char_pos < 0;
            
            return {
                uri => $document->uri,
                range => {
                    start => { line => $i, character => $char_pos },
                    end => { line => $i, character => $char_pos + length($word) },
                },
            };
        }
    }
    
    return;
}

sub _find_incoming_with_ppi {
    my ($self, $document, $target_name) = @_;
    
    return () unless $document->can('ppi_document');
    my $ppi = eval { $document->ppi_document() } or return ();
    my @incoming;
    
    # Find all subroutine definitions
    my $subs = $ppi->find('PPI::Statement::Sub') or return ();
    
    foreach my $sub (@$subs) {
        my $caller_name = $sub->name;
        next unless $caller_name;
        next if $caller_name eq $target_name;  # Skip self
        
        # Check if this sub calls the target
        my $block = $sub->block or next;
        
        # Find all Word tokens (potential function calls)
        my $words = $block->find('PPI::Token::Word') or next;
        
        my $found_call = 0;
        my @call_ranges;
        
        foreach my $word (@$words) {
            next unless $word->content eq $target_name;
            
            # Make sure it's a call, not a definition
            my $parent = $word->parent;
            next if $parent && $parent->isa('PPI::Statement::Sub');
            
            $found_call = 1;
            
            my $loc = $word->location;
            if ($loc && ref($loc) eq 'HASH') {
                push @call_ranges, {
                    start => {
                        line => $loc->{line} - 1,
                        character => $loc->{column} - 1,
                    },
                    end => {
                        line => $loc->{line} - 1,
                        character => $loc->{column} - 1 + length($target_name),
                    },
                };
            }
        }
        
        if ($found_call && @call_ranges) {
            # Get caller's range
            my $caller_loc = $sub->location;
            my $caller_range = $caller_loc && ref($caller_loc) eq 'HASH' ? {
                start => {
                    line => $caller_loc->{line} - 1,
                    character => $caller_loc->{column} - 1,
                },
                end => {
                    line => $caller_loc->{line} - 1,
                    character => $caller_loc->{column} - 1 + length($caller_name),
                },
            } : $call_ranges[0];
            
            push @incoming, {
                from => {
                    name => $caller_name,
                    kind => 12,  # Function
                    uri => $document->uri,
                    range => $caller_range,
                    selectionRange => $caller_range,
                },
                fromRanges => \@call_ranges,
            };
        }
    }
    
    return @incoming;
}

sub _find_incoming_fallback {
    my ($self, $document, $target_name) = @_;
    
    my $text = $document->text;
    my @lines = split(/\n/, $text);
    my @incoming;
    my $current_sub = undef;
    my $current_sub_line = 0;
    my @current_calls;
    
    for (my $i = 0; $i < @lines; $i++) {
        my $line = $lines[$i];
        
        # Check for subroutine definition
        if ($line =~ /^\s*sub\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*[\{\(]?/) {
            # Save previous sub's data if it called our target
            if ($current_sub && @current_calls && $current_sub ne $target_name) {
                my $char_pos = index($lines[$current_sub_line], $current_sub);
                $char_pos = 4 if $char_pos < 0;
                
                push @incoming, {
                    from => {
                        name => $current_sub,
                        kind => 12,
                        uri => $document->uri,
                        range => {
                            start => { line => $current_sub_line, character => $char_pos },
                            end => { line => $current_sub_line, character => $char_pos + length($current_sub) },
                        },
                        selectionRange => {
                            start => { line => $current_sub_line, character => $char_pos },
                            end => { line => $current_sub_line, character => $char_pos + length($current_sub) },
                        },
                    },
                    fromRanges => [ @current_calls ],  # Copy array, not reference
                };
            }
            
            $current_sub = $1;
            $current_sub_line = $i;
            @current_calls = ();
        }
        
        # Check for calls to target in current sub
        if ($current_sub && $current_sub ne $target_name) {
            my $pos = 0;
            while ((my $idx = index($line, $target_name, $pos)) >= 0) {
                # Check word boundaries
                my $before = $idx > 0 ? substr($line, $idx - 1, 1) : '';
                my $after_idx = $idx + length($target_name);
                my $after = $after_idx < length($line) ? substr($line, $after_idx, 1) : '';
                
                if (($before eq '' || $before !~ /[a-zA-Z0-9_]/) &&
                    ($after eq '' || $after !~ /[a-zA-Z0-9_]/)) {
                    push @current_calls, {
                        start => { line => $i, character => $idx },
                        end => { line => $i, character => $idx + length($target_name) },
                    };
                }
                $pos = $idx + 1;
            }
        }
    }
    
    # Don't forget the last subroutine
    if ($current_sub && @current_calls && $current_sub ne $target_name) {
        my $char_pos = index($lines[$current_sub_line], $current_sub);
        $char_pos = 4 if $char_pos < 0;
        
        push @incoming, {
            from => {
                name => $current_sub,
                kind => 12,
                uri => $document->uri,
                range => {
                    start => { line => $current_sub_line, character => $char_pos },
                    end => { line => $current_sub_line, character => $char_pos + length($current_sub) },
                },
                selectionRange => {
                    start => { line => $current_sub_line, character => $char_pos },
                    end => { line => $current_sub_line, character => $char_pos + length($current_sub) },
                },
            },
            fromRanges => [ @current_calls ],  # Copy array, not reference
        };
    }
    
    return @incoming;
}

sub _find_outgoing_with_ppi {
    my ($self, $document, $func_name) = @_;
    
    return () unless $document->can('ppi_document');
    my $ppi = eval { $document->ppi_document() } or return ();
    my @outgoing;
    
    # Find the target subroutine
    my $subs = $ppi->find('PPI::Statement::Sub') or return ();
    my $target_sub;
    
    foreach my $sub (@$subs) {
        if ($sub->name eq $func_name) {
            $target_sub = $sub;
            last;
        }
    }
    
    return () unless $target_sub;
    
    my $block = $target_sub->block or return ();
    
    # Find all called subroutines
    my $words = $block->find('PPI::Token::Word') or return ();
    my %called_funcs;
    
    foreach my $word (@$words) {
        my $content = $word->content;
        
        # Skip keywords and builtins
        next if $content =~ /^(?:my|our|local|if|else|elsif|unless|while|for|foreach|return|print|say|die|warn|next|last|redo|goto|sub|package|use|require|import|do|eval|my)$/;
        
        # Skip the function itself (recursion handled separately if needed)
        next if $content eq $func_name;
        
        # Must look like a function call (followed by '(' or start of statement)
        my $next = $word->snext_sibling;
        next unless $next && ($next->isa('PPI::Structure::List') || 
                             $next->isa('PPI::Token::Structure') ||
                             $next->isa('PPI::Token::Operator'));
        
        my $loc = $word->location;
        if ($loc && ref($loc) eq 'HASH') {
            push @{$called_funcs{$content}}, {
                start => {
                    line => $loc->{line} - 1,
                    character => $loc->{column} - 1,
                },
                end => {
                    line => $loc->{line} - 1,
                    character => $loc->{column} - 1 + length($content),
                },
            };
        }
    }
    
    # Build outgoing call items
    foreach my $called_name (sort keys %called_funcs) {
        # Find the definition of the called function
        my $def_loc;
        foreach my $sub (@$subs) {
            if ($sub->name eq $called_name) {
                my $loc = $sub->location;
                if ($loc && ref($loc) eq 'HASH') {
                    $def_loc = {
                        start => { line => $loc->{line} - 1, character => $loc->{column} - 1 },
                        end => { line => $loc->{line} - 1, character => $loc->{column} - 1 + length($called_name) },
                    };
                }
                last;
            }
        }
        
        # Use first call location as fallback
        my $range = $def_loc || $called_funcs{$called_name}[0];
        
        push @outgoing, {
            to => {
                name => $called_name,
                kind => 12,  # Function
                uri => $document->uri,
                range => $range,
                selectionRange => $range,
            },
            fromRanges => $called_funcs{$called_name},
        };
    }
    
    return @outgoing;
}

sub _find_outgoing_fallback {
    my ($self, $document, $func_name) = @_;
    
    my $text = $document->text;
    my @lines = split(/\n/, $text);
    my @outgoing;
    my $in_target = 0;
    my $brace_depth = 0;
    my %called_funcs;
    
    my @builtins = qw(my our local if else elsif unless while for foreach return print say die warn next last redo goto sub package use require import do eval shift defined length scalar ref push pop shift unshift splice sort map grep join split keys values exists delete);
    my %is_builtin = map { $_ => 1 } @builtins;
    
    for (my $i = 0; $i < @lines; $i++) {
        my $line = $lines[$i];
        
        # Check if we're entering the target subroutine
        if (!$in_target && $line =~ /^\s*sub\s+\Q$func_name\E\b/) {
            $in_target = 1;
            $brace_depth = 0;
            next;
        }
        
        next unless $in_target;
        
        # Track brace depth to know when we exit the sub
        $brace_depth += () = $line =~ /\{/g;
        $brace_depth -= () = $line =~ /\}/g;
        
        # Check for subroutine calls
        # Match: word followed by '(' (function call with parens)
        # OR word at end of statement (bareword function call)
        # OR word followed by comma/semicolon/space then something
        while ($line =~ /\b([a-zA-Z_][a-zA-Z0-9_]*)\b/g) {
            my $called = $1;
            next if $is_builtin{$called};
            next if $called eq $func_name;
            
            my $end_pos = pos($line);
            my $start = $end_pos - length($called);
            
            # Check what follows to determine if it's likely a function call
            my $after = $end_pos < length($line) ? substr($line, $end_pos, 1) : '';
            
            # It's likely a function call if followed by:
            # '(' - function call with parentheses
            # ';' - end of statement (bareword call)
            # ',' - argument separator
            # whitespace then something that's not an operator
            next unless $after =~ /^(\(|;|,|\s|$)/;
            
            # Additional check: make sure it's not a variable assignment like "my $var = ..."
            # by checking if preceded by $, @, %
            my $before = $start > 0 ? substr($line, $start - 1, 1) : '';
            next if $before =~ /[\$@%]/;
            
            push @{$called_funcs{$called}}, {
                start => { line => $i, character => $start },
                end => { line => $i, character => $end_pos },
            };
        }
        
        # Exit if we've closed all braces
        last if $brace_depth <= 0 && $line =~ /\}/;
    }
    
    # Find definitions for called functions
    my %def_locations;
    for (my $i = 0; $i < @lines; $i++) {
        if ($lines[$i] =~ /^\s*sub\s+([a-zA-Z_][a-zA-Z0-9_]*)\b/) {
            my $name = $1;
            if ($called_funcs{$name}) {
                my $char_pos = index($lines[$i], $name);
                $char_pos = 4 if $char_pos < 0;
                $def_locations{$name} = {
                    start => { line => $i, character => $char_pos },
                    end => { line => $i, character => $char_pos + length($name) },
                };
            }
        }
    }
    
    # Build outgoing items
    foreach my $called_name (sort keys %called_funcs) {
        my $range = $def_locations{$called_name} || $called_funcs{$called_name}[0];
        
        push @outgoing, {
            to => {
                name => $called_name,
                kind => 12,
                uri => $document->uri,
                range => $range,
                selectionRange => $range,
            },
            fromRanges => $called_funcs{$called_name},
        };
    }
    
    return @outgoing;
}

1;
