package YAPLSPD::SemanticTokens;
use strict;
use warnings;

# Try to load PPI, but make it optional for testing
my $HAS_PPI = 0;
eval {
    require PPI;
    $HAS_PPI = 1;
};

# Semantic Token Types (LSP Standard)
# 0=namespace, 1=type, 2=class, 3=enum, 4=interface, 5=struct, 6=typeParameter,
# 7=parameter, 8=variable, 9=property, 10=enumMember, 11=event, 12=function,
# 13=method, 14=macro, 15=keyword, 16=modifier, 17=comment, 18=string,
# 19=number, 20=regexp, 21=operator
use constant {
    TOKEN_NAMESPACE => 0,
    TOKEN_TYPE => 1,
    TOKEN_CLASS => 2,
    TOKEN_ENUM => 3,
    TOKEN_INTERFACE => 4,
    TOKEN_STRUCT => 5,
    TOKEN_TYPE_PARAMETER => 6,
    TOKEN_PARAMETER => 7,
    TOKEN_VARIABLE => 8,
    TOKEN_PROPERTY => 9,
    TOKEN_ENUM_MEMBER => 10,
    TOKEN_EVENT => 11,
    TOKEN_FUNCTION => 12,
    TOKEN_METHOD => 13,
    TOKEN_MACRO => 14,
    TOKEN_KEYWORD => 15,
    TOKEN_MODIFIER => 16,
    TOKEN_COMMENT => 17,
    TOKEN_STRING => 18,
    TOKEN_NUMBER => 19,
    TOKEN_REGEXP => 20,
    TOKEN_OPERATOR => 21,
};

# Token Modifiers (bit flags)
use constant {
    MODIFIER_DECLARATION => 1 << 0,    # 1
    MODIFIER_DEFINITION => 1 << 1,      # 2
    MODIFIER_READONLY => 1 << 2,        # 4
    MODIFIER_STATIC => 1 << 3,          # 8
    MODIFIER_DEPRECATED => 1 << 4,      # 16
    MODIFIER_ABSTRACT => 1 << 5,        # 32
    MODIFIER_ASYNC => 1 << 6,           # 64
    MODIFIER_MODIFICATION => 1 << 7,    # 128
    MODIFIER_DOCUMENTATION => 1 << 8,   # 256
    MODIFIER_DEFAULT_LIBRARY => 1 << 9, # 512
};

# Token type legend for LSP
our @TOKEN_TYPES = qw(
    namespace type class enum interface struct typeParameter
    parameter variable property enumMember event function method
    macro keyword modifier comment string number regexp operator
);

# Token modifier legend for LSP
our @TOKEN_MODIFIERS = qw(
    declaration definition readonly static deprecated abstract
    async modification documentation defaultLibrary
);

sub new {
    my ($class) = @_;
    return bless {}, $class;
}

# Get full document semantic tokens
sub get_semantic_tokens_full {
    my ($self, $document) = @_;
    
    return $self->_get_semantic_tokens($document);
}

# Get semantic tokens for a range
sub get_semantic_tokens_range {
    my ($self, $document, $range) = @_;
    
    return $self->_get_semantic_tokens($document, $range);
}

# Private method to collect all semantic tokens
sub _get_semantic_tokens {
    my ($self, $document, $range) = @_;
    
    my @tokens;
    
    if ($HAS_PPI && $document->can('ppi_document')) {
        @tokens = $self->_get_tokens_with_ppi($document, $range);
    } else {
        @tokens = $self->_get_tokens_fallback($document, $range);
    }
    
    # Sort tokens by line, then by character
    @tokens = sort { 
        $a->{line} <=> $b->{line} || 
        $a->{character} <=> $b->{character} 
    } @tokens;
    
    # Encode tokens into LSP format (delta encoding)
    my @data = $self->_encode_tokens(@tokens);
    
    return {
        data => \@data,
    };
}

# Encode tokens using LSP delta encoding
sub _encode_tokens {
    my ($self, @tokens) = @_;
    
    my @data;
    my $prev_line = 0;
    my $prev_char = 0;
    
    foreach my $token (@tokens) {
        my $line = $token->{line};
        my $char = $token->{character};
        my $length = $token->{length};
        my $type = $token->{token_type};
        my $modifiers = $token->{modifiers} || 0;
        
        # Delta encoding
        if ($line == $prev_line) {
            # Same line: delta from previous character
            push @data, 0, $char - $prev_char, $length, $type, $modifiers;
        } else {
            # Different line: delta from previous line, absolute character
            push @data, $line - $prev_line, $char, $length, $type, $modifiers;
        }
        
        $prev_line = $line;
        $prev_char = $char;
    }
    
    return @data;
}

# Get tokens using PPI
sub _get_tokens_with_ppi {
    my ($self, $document, $range) = @_;
    
    return () unless $document->can('ppi_document');
    my $ppi = eval { $document->ppi_document() } or return ();
    
    my @tokens;
    my $text = $document->text;
    my @lines = split(/\n/, $text);
    
    # Get range boundaries if specified
    my ($start_line, $end_line) = (0, scalar(@lines) - 1);
    if ($range) {
        $start_line = $range->{start}{line};
        $end_line = $range->{end}{line};
    }
    
    # Find all token types in the document
    
    # 1. Package declarations (class, namespace)
    my $packages = $ppi->find('PPI::Statement::Package');
    if ($packages) {
        foreach my $pkg (@$packages) {
            my $loc = $pkg->location;
            next unless $loc && ref($loc) eq 'HASH';
            
            my $line_num = $loc->{line} - 1;
            next if $line_num < $start_line || $line_num > $end_line;
            
            my $name = $pkg->namespace;
            next unless $name;
            
            # Find position of package name
            my $line_text = $lines[$line_num] || '';
            my $char_pos = index($line_text, $name);
            $char_pos = $loc->{column} if $char_pos < 0;
            
            push @tokens, {
                line => $line_num,
                character => $char_pos,
                length => length($name),
                token_type => TOKEN_CLASS,
                modifiers => MODIFIER_DEFINITION | MODIFIER_DECLARATION,
            };
        }
    }
    
    # 2. Subroutines (function, method)
    my $subs = $ppi->find('PPI::Statement::Sub');
    if ($subs) {
        foreach my $sub (@$subs) {
            my $loc = $sub->location;
            next unless $loc && ref($loc) eq 'HASH';
            
            my $line_num = $loc->{line} - 1;
            next if $line_num < $start_line || $line_num > $end_line;
            
            my $name = $sub->name;
            next unless $name;
            
            # Determine if it's a method (has $self or $class as first param)
            my $is_method = $self->_is_method($sub);
            
            my $line_text = $lines[$line_num] || '';
            my $char_pos = index($line_text, $name);
            $char_pos = $loc->{column} if $char_pos < 0;
            
            push @tokens, {
                line => $line_num,
                character => $char_pos,
                length => length($name),
                token_type => $is_method ? TOKEN_METHOD : TOKEN_FUNCTION,
                modifiers => MODIFIER_DEFINITION | MODIFIER_DECLARATION,
            };
        }
    }
    
    # 3. Variables (my, our, state)
    my $symbols = $ppi->find('PPI::Token::Symbol');
    if ($symbols) {
        my %declared_vars;  # Track declared variables to mark first occurrence
        
        foreach my $sym (@$symbols) {
            my $loc = $sym->location;
            next unless $loc && ref($loc) eq 'HASH';
            
            my $line_num = $loc->{line} - 1;
            next if $line_num < $start_line || $line_num > $end_line;
            
            my $content = $sym->content;
            next unless $content =~ /^[\$\@\%]/;
            
            # Check if this is a declaration
            my $is_declaration = $self->_is_variable_declaration($sym);
            my $modifiers = 0;
            
            if ($is_declaration) {
                $modifiers |= MODIFIER_DECLARATION;
                $declared_vars{$content} = 1;
            } elsif (!$declared_vars{$content}) {
                # First use without declaration (e.g., parameter)
                $modifiers |= MODIFIER_DECLARATION;
                $declared_vars{$content} = 1;
            }
            
            # Check for readonly (if declared with my and never reassigned)
            if ($content =~ /^\$/ && $is_declaration) {
                # Simple heuristic: my variables are potentially readonly
                $modifiers |= MODIFIER_READONLY;
            }
            
            my $var_name = $content;
            $var_name =~ s/^[\$\@\%]//;
            
            push @tokens, {
                line => $line_num,
                character => $loc->{column} - 1,
                length => length($content),
                token_type => TOKEN_VARIABLE,
                modifiers => $modifiers,
            };
        }
    }
    
    # 4. Keywords (use, require, package, sub, my, our, if, etc.)
    my $words = $ppi->find('PPI::Token::Word');
    if ($words) {
        my %keywords = map { $_ => 1 } qw(
            use require package sub my our state has
            if unless else elsif for foreach while until
            do given when default return last next redo
            bless ref defined undef shift push pop unshift
            join split map grep sort keys values each
            open close print say die warn eval try catch
            and or not xor eq ne lt gt le ge cmp
        );
        
        foreach my $word (@$words) {
            my $loc = $word->location;
            next unless $loc && ref($loc) eq 'HASH';
            
            my $line_num = $loc->{line} - 1;
            next if $line_num < $start_line || $line_num > $end_line;
            
            my $content = $word->content;
            next unless $keywords{$content};
            
            # Skip if it's a method call (followed by -> or bareword after sub)
            next if $self->_is_method_call($word);
            
            push @tokens, {
                line => $line_num,
                character => $loc->{column} - 1,
                length => length($content),
                token_type => TOKEN_KEYWORD,
                modifiers => 0,
            };
        }
    }
    
    # 5. Strings
    my $strings = $ppi->find(sub {
        my ($root, $node) = @_;
        return $node->isa('PPI::Token::Quote') || 
               $node->isa('PPI::Token::QuoteLike') ||
               $node->isa('PPI::Token::HereDoc');
    });
    
    if ($strings) {
        foreach my $str (@$strings) {
            my $loc = $str->location;
            next unless $loc && ref($loc) eq 'HASH';
            
            my $line_num = $loc->{line} - 1;
            next if $line_num < $start_line || $line_num > $end_line;
            
            my $content = $str->content;
            
            push @tokens, {
                line => $line_num,
                character => $loc->{column} - 1,
                length => length($content),
                token_type => TOKEN_STRING,
                modifiers => 0,
            };
        }
    }
    
    # 6. Numbers
    my $numbers = $ppi->find('PPI::Token::Number');
    if ($numbers) {
        foreach my $num (@$numbers) {
            my $loc = $num->location;
            next unless $loc && ref($loc) eq 'HASH';
            
            my $line_num = $loc->{line} - 1;
            next if $line_num < $start_line || $line_num > $end_line;
            
            my $content = $num->content;
            
            push @tokens, {
                line => $line_num,
                character => $loc->{column} - 1,
                length => length($content),
                token_type => TOKEN_NUMBER,
                modifiers => 0,
            };
        }
    }
    
    # 7. Comments
    my $comments = $ppi->find('PPI::Token::Comment');
    if ($comments) {
        foreach my $comment (@$comments) {
            my $loc = $comment->location;
            next unless $loc && ref($loc) eq 'HASH';
            
            my $line_num = $loc->{line} - 1;
            next if $line_num < $start_line || $line_num > $end_line;
            
            my $content = $comment->content;
            
            # Check if it's a documentation comment (POD starts with =)
            my $modifiers = 0;
            if ($content =~ /^=/) {
                $modifiers |= MODIFIER_DOCUMENTATION;
            }
            
            push @tokens, {
                line => $line_num,
                character => $loc->{column} - 1,
                length => length($content),
                token_type => TOKEN_COMMENT,
                modifiers => $modifiers,
            };
        }
    }
    
    # 8. Operators
    my $operators = $ppi->find('PPI::Token::Operator');
    if ($operators) {
        foreach my $op (@$operators) {
            my $loc = $op->location;
            next unless $loc && ref($loc) eq 'HASH';
            
            my $line_num = $loc->{line} - 1;
            next if $line_num < $start_line || $line_num > $end_line;
            
            my $content = $op->content;
            
            push @tokens, {
                line => $line_num,
                character => $loc->{column} - 1,
                length => length($content),
                token_type => TOKEN_OPERATOR,
                modifiers => 0,
            };
        }
    }
    
    return @tokens;
}

# Check if a subroutine is a method (has $self or $class as first param)
sub _is_method {
    my ($self, $sub) = @_;
    
    my $block = $sub->block;
    return 0 unless $block;
    
    # Find the signature or first statement
    my $first_stmt = $block->schild(1);  # Skip the opening brace
    return 0 unless $first_stmt;
    
    # Check for 'my $self' or 'my $class' pattern
    if ($first_stmt->isa('PPI::Statement::Variable')) {
        my $symbols = $first_stmt->find('PPI::Token::Symbol');
        if ($symbols) {
            foreach my $sym (@$symbols) {
                my $content = $sym->content;
                return 1 if $content eq '$self' || $content eq '$class' || $content eq '$this';
            }
        }
    }
    
    # Check for signatures (Perl 5.20+)
    my $sig = $sub->signature;
    if ($sig) {
        my $sig_text = $sig->content;
        return 1 if $sig_text =~ /^\s*\$self\b/ || $sig_text =~ /^\s*\$class\b/;
    }
    
    return 0;
}

# Check if a symbol is a variable declaration
sub _is_variable_declaration {
    my ($self, $sym) = @_;
    
    my $stmt = $sym->statement;
    return 0 unless $stmt;
    
    # Check if parent is a variable declaration statement
    if ($stmt->isa('PPI::Statement::Variable')) {
        return 1;
    }
    
    # Check for 'for my $var' or 'foreach my $var'
    if ($stmt->isa('PPI::Statement::Compound')) {
        my $content = $stmt->content;
        return 1 if $content =~ /^(?:for|foreach)\s+my\s+/;
    }
    
    return 0;
}

# Check if a word token is a method call (not a keyword)
sub _is_method_call {
    my ($self, $word) = @_;
    
    # Check if preceded by -> (method call)
    my $prev = $word->sprevious_sibling;
    if ($prev && $prev->isa('PPI::Token::Operator')) {
        return 1 if $prev->content eq '->';
    }
    
    # Check if it's after 'sub' (subroutine name)
    my $parent = $word->parent;
    if ($parent && $parent->isa('PPI::Statement::Sub')) {
        return 1;
    }
    
    return 0;
}

# Fallback: regex-based token extraction
sub _get_tokens_fallback {
    my ($self, $document, $range) = @_;
    
    my $text = $document->text;
    my @lines = split(/\n/, $text);
    my @tokens;
    
    # Get range boundaries
    my ($start_line, $end_line) = (0, scalar(@lines) - 1);
    if ($range) {
        $start_line = $range->{start}{line};
        $end_line = $range->{end}{line};
    }
    
    for (my $i = $start_line; $i <= $end_line && $i < @lines; $i++) {
        my $line = $lines[$i];
        my $offset = 0;
        
        # Comments
        while ($line =~ m/(#.*)$/g) {
            my $start = pos($line) - length($1);
            push @tokens, {
                line => $i,
                character => $start,
                length => length($1),
                token_type => TOKEN_COMMENT,
                modifiers => 0,
            };
        }
        
        # Package declarations
        if ($line =~ /\bpackage\s+([a-zA-Z_][a-zA-Z0-9_:]*)/) {
            my $pkg = $1;
            my $pos = index($line, $pkg);
            push @tokens, {
                line => $i,
                character => $pos,
                length => length($pkg),
                token_type => TOKEN_CLASS,
                modifiers => MODIFIER_DEFINITION | MODIFIER_DECLARATION,
            };
        }
        
        # Subroutines
        if ($line =~ /\bsub\s+([a-zA-Z_][a-zA-Z0-9_]*)/) {
            my $sub = $1;
            my $pos = index($line, $sub);
            
            # Simple heuristic: sub with $self is a method
            my $is_method = 0;
            # Look ahead for $self in next few lines
            for (my $j = $i + 1; $j <= $i + 3 && $j < @lines; $j++) {
                if ($lines[$j] =~ /\$self\b/) {
                    $is_method = 1;
                    last;
                }
            }
            
            push @tokens, {
                line => $i,
                character => $pos,
                length => length($sub),
                token_type => $is_method ? TOKEN_METHOD : TOKEN_FUNCTION,
                modifiers => MODIFIER_DEFINITION | MODIFIER_DECLARATION,
            };
        }
        
        # Keywords
        my @keywords = qw(use require my our state package sub if unless else elsif for foreach while until return last next redo);
        my $kw_pattern = join('|', map { quotemeta } @keywords);
        while ($line =~ /\b($kw_pattern)\b/g) {
            my $kw = $1;
            my $start = pos($line) - length($kw);
            
            # Skip if part of method call
            next if substr($line, $start - 2, 2) eq '->';
            
            push @tokens, {
                line => $i,
                character => $start,
                length => length($kw),
                token_type => TOKEN_KEYWORD,
                modifiers => 0,
            };
        }
        
        # Strings (simplified - handles "..." and '...')
        while ($line =~ /(["'])(.*?)\1/g) {
            my $str = $1 . $2 . $1;
            my $start = pos($line) - length($str);
            push @tokens, {
                line => $i,
                character => $start,
                length => length($str),
                token_type => TOKEN_STRING,
                modifiers => 0,
            };
        }
        
        # Numbers
        while ($line =~ /\b(\d+(?:\.\d+)?)\b/g) {
            my $num = $1;
            my $start = pos($line) - length($num);
            push @tokens, {
                line => $i,
                character => $start,
                length => length($num),
                token_type => TOKEN_NUMBER,
                modifiers => 0,
            };
        }
        
        # Variables (my declarations)
        while ($line =~ /\b(my)\s+([\$\@\%])([a-zA-Z_][a-zA-Z0-9_]*)/g) {
            my $var = $2 . $3;
            my $start = pos($line) - length($3) - 1;
            push @tokens, {
                line => $i,
                character => $start,
                length => length($var),
                token_type => TOKEN_VARIABLE,
                modifiers => MODIFIER_DECLARATION | MODIFIER_READONLY,
            };
        }
        
        # Operators
        my @operators = qw(+ - * / % = == != <= >= < > && || ! . => -> :: .. ... ** += -= *= /= %= .= ++ -- =~ !~ ~~ ~~.);
        for my $op (@operators) {
            my $pos = 0;
            while ((my $idx = index($line, $op, $pos)) >= 0) {
                push @tokens, {
                    line => $i,
                    character => $idx,
                    length => length($op),
                    token_type => TOKEN_OPERATOR,
                    modifiers => 0,
                };
                $pos = $idx + 1;
            }
        }
    }
    
    return @tokens;
}

1;
