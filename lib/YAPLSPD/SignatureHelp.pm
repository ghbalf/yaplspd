package YAPLSPD::SignatureHelp;
use strict;
use warnings;

# Known signatures for Perl built-in functions
my %BUILTIN_SIGNATURES = (
    'print' => {
        label => 'print FILEHANDLE LIST',
        documentation => 'Prints a string or list of strings to the specified filehandle.',
        parameters => [
            { label => 'FILEHANDLE', documentation => 'Optional filehandle (defaults to STDOUT)' },
            { label => 'LIST', documentation => 'List of strings to print' },
        ],
    },
    'printf' => {
        label => 'printf FILEHANDLE FORMAT, LIST',
        documentation => 'Prints a formatted string to the specified filehandle.',
        parameters => [
            { label => 'FILEHANDLE', documentation => 'Optional filehandle' },
            { label => 'FORMAT', documentation => 'Format string' },
            { label => 'LIST', documentation => 'Values to format' },
        ],
    },
    'sprintf' => {
        label => 'sprintf FORMAT, LIST',
        documentation => 'Returns a formatted string.',
        parameters => [
            { label => 'FORMAT', documentation => 'Format string' },
            { label => 'LIST', documentation => 'Values to format' },
        ],
    },
    'open' => {
        label => 'open FILEHANDLE, EXPR',
        documentation => 'Opens a file for reading or writing.',
        parameters => [
            { label => 'FILEHANDLE', documentation => 'Filehandle to use' },
            { label => 'EXPR', documentation => 'Filename and mode expression' },
        ],
    },
    'close' => {
        label => 'close FILEHANDLE',
        documentation => 'Closes a filehandle.',
        parameters => [
            { label => 'FILEHANDLE', documentation => 'Filehandle to close' },
        ],
    },
    'split' => {
        label => 'split /PATTERN/, EXPR, LIMIT',
        documentation => 'Splits a string into an array.',
        parameters => [
            { label => 'PATTERN', documentation => 'Regular expression pattern' },
            { label => 'EXPR', documentation => 'String to split' },
            { label => 'LIMIT', documentation => 'Maximum number of splits' },
        ],
    },
    'join' => {
        label => 'join EXPR, LIST',
        documentation => 'Joins list elements into a string.',
        parameters => [
            { label => 'EXPR', documentation => 'Separator string' },
            { label => 'LIST', documentation => 'List to join' },
        ],
    },
    'substr' => {
        label => 'substr EXPR, OFFSET, LENGTH, REPLACEMENT',
        documentation => 'Extracts a substring from a string.',
        parameters => [
            { label => 'EXPR', documentation => 'Source string' },
            { label => 'OFFSET', documentation => 'Starting position' },
            { label => 'LENGTH', documentation => 'Optional length' },
            { label => 'REPLACEMENT', documentation => 'Optional replacement string' },
        ],
    },
    'index' => {
        label => 'index STR, SUBSTR, POSITION',
        documentation => 'Finds the position of a substring.',
        parameters => [
            { label => 'STR', documentation => 'String to search in' },
            { label => 'SUBSTR', documentation => 'Substring to find' },
            { label => 'POSITION', documentation => 'Optional starting position' },
        ],
    },
    'push' => {
        label => 'push ARRAY, LIST',
        documentation => 'Appends elements to an array.',
        parameters => [
            { label => 'ARRAY', documentation => 'Array to modify' },
            { label => 'LIST', documentation => 'Elements to append' },
        ],
    },
    'pop' => {
        label => 'pop ARRAY',
        documentation => 'Removes and returns the last element of an array.',
        parameters => [
            { label => 'ARRAY', documentation => 'Array to pop from' },
        ],
    },
    'shift' => {
        label => 'shift ARRAY',
        documentation => 'Removes and returns the first element of an array.',
        parameters => [
            { label => 'ARRAY', documentation => 'Array to shift from' },
        ],
    },
    'unshift' => {
        label => 'unshift ARRAY, LIST',
        documentation => 'Prepends elements to an array.',
        parameters => [
            { label => 'ARRAY', documentation => 'Array to modify' },
            { label => 'LIST', documentation => 'Elements to prepend' },
        ],
    },
    'keys' => {
        label => 'keys HASH',
        documentation => 'Returns all keys of a hash.',
        parameters => [
            { label => 'HASH', documentation => 'Hash to get keys from' },
        ],
    },
    'values' => {
        label => 'values HASH',
        documentation => 'Returns all values of a hash.',
        parameters => [
            { label => 'HASH', documentation => 'Hash to get values from' },
        ],
    },
    'exists' => {
        label => 'exists EXPR',
        documentation => 'Checks if a hash key or array index exists.',
        parameters => [
            { label => 'EXPR', documentation => 'Hash key or array index expression' },
        ],
    },
    'delete' => {
        label => 'delete EXPR',
        documentation => 'Deletes a hash key or array element.',
        parameters => [
            { label => 'EXPR', documentation => 'Hash key or array element to delete' },
        ],
    },
    'map' => {
        label => 'map BLOCK LIST',
        documentation => 'Transforms a list by applying a block to each element.',
        parameters => [
            { label => 'BLOCK', documentation => 'Code block to apply' },
            { label => 'LIST', documentation => 'Input list' },
        ],
    },
    'grep' => {
        label => 'grep BLOCK LIST',
        documentation => 'Filters a list based on a condition.',
        parameters => [
            { label => 'BLOCK', documentation => 'Condition block' },
            { label => 'LIST', documentation => 'Input list' },
        ],
    },
    'sort' => {
        label => 'sort BLOCK LIST',
        documentation => 'Sorts a list.',
        parameters => [
            { label => 'BLOCK', documentation => 'Optional comparison block' },
            { label => 'LIST', documentation => 'List to sort' },
        ],
    },
    'length' => {
        label => 'length EXPR',
        documentation => 'Returns the length of a string.',
        parameters => [
            { label => 'EXPR', documentation => 'String expression' },
        ],
    },
    'defined' => {
        label => 'defined EXPR',
        documentation => 'Checks if a value is defined.',
        parameters => [
            { label => 'EXPR', documentation => 'Expression to check' },
        ],
    },
    'scalar' => {
        label => 'scalar EXPR',
        documentation => 'Evaluates expression in scalar context.',
        parameters => [
            { label => 'EXPR', documentation => 'Expression to evaluate' },
        ],
    },
    'bless' => {
        label => 'bless REF, CLASSNAME',
        documentation => 'Turns a reference into an object.',
        parameters => [
            { label => 'REF', documentation => 'Reference to bless' },
            { label => 'CLASSNAME', documentation => 'Class name (optional, defaults to current package)' },
        ],
    },
    'ref' => {
        label => 'ref EXPR',
        documentation => 'Returns the type of a reference.',
        parameters => [
            { label => 'EXPR', documentation => 'Expression to check' },
        ],
    },
);

sub new {
    my ($class) = @_;
    bless {}, $class;
}

sub get_signature_help {
    my ($self, $document, $position) = @_;
    
    my $line_num = $position->{line};
    my $char = $position->{character};
    
    # Get current line content
    my $line = $document->get_line($line_num);
    return undef unless defined $line;
    
    # Find function call at position
    my ($func_name, $active_param) = $self->_find_function_call($line, $char);
    return undef unless defined $func_name;
    
    # Look up signature
    my $signature = $BUILTIN_SIGNATURES{$func_name};
    
    # If not a builtin, try to extract from user subroutines
    if (!$signature) {
        $signature = $self->_extract_sub_signature($document, $func_name);
    }
    
    return undef unless $signature;
    
    return {
        signatures => [$signature],
        activeSignature => 0,
        activeParameter => $active_param || 0,
    };
}

sub _find_function_call {
    my ($self, $line, $char) = @_;
    
    # Look backwards from cursor to find function name and active parameter
    my $before_cursor = substr($line, 0, $char);
    
    # Match: function_name(...
    # Track parentheses to find the active parameter
    my $paren_depth = 0;
    my $active_param = 0;
    my $in_string = 0;
    my $string_char = '';
    my $func_name = '';
    
    # Count commas and track parentheses from the start of the current call
    my @chars = split('', $before_cursor);
    my $last_func_start = -1;
    
    for (my $i = 0; $i < @chars; $i++) {
        my $c = $chars[$i];
        
        # Handle strings
        if ($c eq '"' || $c eq "'") {
            if (!$in_string) {
                $in_string = 1;
                $string_char = $c;
            } elsif ($string_char eq $c) {
                $in_string = 0;
            }
            next;
        }
        
        next if $in_string;
        
        if ($c eq '(') {
            $paren_depth++;
            if ($paren_depth == 1) {
                # Find function name before this paren
                my $before_paren = substr($before_cursor, 0, $i);
                if ($before_paren =~ /(\w+)\s*$/) {
                    $func_name = $1;
                    $active_param = 0;
                }
            }
        }
        elsif ($c eq ')') {
            $paren_depth--;
            if ($paren_depth < 0) {
                $paren_depth = 0;
            }
        }
        elsif ($c eq ',' && $paren_depth == 1) {
            $active_param++;
        }
    }
    
    return ($func_name, $active_param) if $func_name;
    return (undef, undef);
}

sub _extract_sub_signature {
    my ($self, $document, $sub_name) = @_;
    
    # Try to find the subroutine definition and extract parameters
    my $text = $document->text;
    
    # Match: sub name { ... } or sub name (signature) { ... }
    # Try modern signature syntax first (Perl 5.20+)
    if ($text =~ /sub\s+\Q$sub_name\E\s*\(([^)]*)\)\s*\{/) {
        my $sig = $1;
        my @params = split(/,\s*/, $sig);
        @params = grep { $_ ne '' } @params;
        
        my $param_list = join(', ', @params) || '';
        return {
            label => "$sub_name($param_list)",
            documentation => "User-defined subroutine",
            parameters => [map { { label => $_, documentation => '' } } @params],
        };
    }
    
    # Match: sub name { my ($self, $x, $y) = @_; ... }
    if ($text =~ /sub\s+\Q$sub_name\E\s*\{[^}]*my\s*[\(\s]*([^\)]+)[\)\s]*=\s*\@_/) {
        my $sig = $1;
        # Clean up the signature
        $sig =~ s/\$//g;
        $sig =~ s/,?\s*\@_//g;  # Remove @_ itself if present
        my @params = split(/,\s*/, $sig);
        @params = map { '$' . $_ } grep { $_ ne '' } @params;
        
        my $param_list = join(', ', @params) || '';
        return {
            label => "$sub_name($param_list)",
            documentation => "User-defined subroutine",
            parameters => [map { { label => $_, documentation => '' } } @params],
        };
    }
    
    # Basic fallback - just the name with empty params
    return {
        label => "$sub_name(...)",
        documentation => "User-defined subroutine",
        parameters => [],
    };
}

1;