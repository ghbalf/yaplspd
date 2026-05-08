use strict;
use warnings;
use Test::More;

# Add lib to path
use lib 'lib';
use YAPLSPD::SemanticTokens;

# Simple document mock that doesn't require PPI
{
    package TestDocument;
    sub new {
        my ($class, %args) = @_;
        bless { text => $args{text}, uri => $args{uri} }, $class;
    }
    sub text { shift->{text} }
    sub uri { shift->{uri} }
}

# Test 1: Package declaration tokens
subtest 'package_tokens' => sub {
    my $test_code = <<'PERL';
package MyClass;
use strict;
use warnings;

sub new {
    my $class = shift;
    return bless {}, $class;
}
PERL
    $test_code =~ s/^\n//;
    
    my $doc = TestDocument->new(
        uri => 'file:///test1.pl',
        text => $test_code,
    );
    
    my $st = YAPLSPD::SemanticTokens->new();
    my $result = $st->get_semantic_tokens_full($doc);
    
    ok(exists $result->{data}, 'Result has data field');
    ok(ref $result->{data} eq 'ARRAY', 'Data is an array');
    
    # Data is delta encoded: [line_delta, char_delta, length, token_type, modifiers]
    my @data = @{$result->{data}};
    ok(scalar @data > 0, 'Has semantic tokens');
    ok(scalar @data % 5 == 0, 'Data is multiple of 5 (delta encoding)');
    
    # First token should be 'package' keyword or 'MyClass' class
    # line 0, char 0 is where 'package' starts
    my ($line, $char, $length, $token_type, $modifiers) = @data[0..4];
    
    # Check that we got tokens (either keyword 'package' or class 'MyClass')
    ok(defined $line, 'First token has line');
    ok(defined $char, 'First token has char');
};

# Test 2: Subroutine and function tokens
subtest 'subroutine_tokens' => sub {
    my $test_code = <<'PERL';
sub my_function {
    my ($arg1, $arg2) = @_;
    return $arg1 + $arg2;
}

sub my_method {
    my $self = shift;
    return $self->{value};
}
PERL
    $test_code =~ s/^\n//;
    
    my $doc = TestDocument->new(
        uri => 'file:///test2.pl',
        text => $test_code,
    );
    
    my $st = YAPLSPD::SemanticTokens->new();
    my $result = $st->get_semantic_tokens_full($doc);
    
    ok(exists $result->{data}, 'Result has data field');
    my @data = @{$result->{data}};
    ok(scalar @data > 0, 'Has semantic tokens for subroutines');
};

# Test 3: Variable tokens
subtest 'variable_tokens' => sub {
    my $test_code = <<'PERL';
my $scalar = 42;
my @array = (1, 2, 3);
my %hash = (key => 'value');
our $global = 'global';
PERL
    $test_code =~ s/^\n//;
    
    my $doc = TestDocument->new(
        uri => 'file:///test3.pl',
        text => $test_code,
    );
    
    my $st = YAPLSPD::SemanticTokens->new();
    my $result = $st->get_semantic_tokens_full($doc);
    
    ok(exists $result->{data}, 'Result has data field');
    my @data = @{$result->{data}};
    ok(scalar @data > 0, 'Has semantic tokens for variables');
};

# Test 4: String and number tokens
subtest 'string_number_tokens' => sub {
    my $test_code = <<'PERL';
my $str = "hello world";
my $num = 123;
my $float = 3.14159;
my $single = 'single quoted';
PERL
    $test_code =~ s/^\n//;
    
    my $doc = TestDocument->new(
        uri => 'file:///test4.pl',
        text => $test_code,
    );
    
    my $st = YAPLSPD::SemanticTokens->new();
    my $result = $st->get_semantic_tokens_full($doc);
    
    ok(exists $result->{data}, 'Result has data field');
    my @data = @{$result->{data}};
    ok(scalar @data > 0, 'Has semantic tokens for strings and numbers');
};

# Test 5: Keyword tokens
subtest 'keyword_tokens' => sub {
    my $test_code = <<'PERL';
use strict;
use warnings;

if ($condition) {
    return 1;
} elsif ($other) {
    return 2;
} else {
    return 0;
}
PERL
    $test_code =~ s/^\n//;
    
    my $doc = TestDocument->new(
        uri => 'file:///test5.pl',
        text => $test_code,
    );
    
    my $st = YAPLSPD::SemanticTokens->new();
    my $result = $st->get_semantic_tokens_full($doc);
    
    ok(exists $result->{data}, 'Result has data field');
    my @data = @{$result->{data}};
    ok(scalar @data > 0, 'Has semantic tokens for keywords');
};

# Test 6: Comment tokens
subtest 'comment_tokens' => sub {
    my $test_code = <<'PERL';
# This is a comment
my $x = 1;  # inline comment
# Another comment
PERL
    $test_code =~ s/^\n//;
    
    my $doc = TestDocument->new(
        uri => 'file:///test6.pl',
        text => $test_code,
    );
    
    my $st = YAPLSPD::SemanticTokens->new();
    my $result = $st->get_semantic_tokens_full($doc);
    
    ok(exists $result->{data}, 'Result has data field');
    my @data = @{$result->{data}};
    ok(scalar @data > 0, 'Has semantic tokens for comments');
};

# Test 7: Range-based tokens
subtest 'range_tokens' => sub {
    my $test_code = <<'PERL';
package MyClass;
use strict;
sub method1 { 1 }
sub method2 { 2 }
sub method3 { 3 }
PERL
    $test_code =~ s/^\n//;
    
    my $doc = TestDocument->new(
        uri => 'file:///test7.pl',
        text => $test_code,
    );
    
    my $st = YAPLSPD::SemanticTokens->new();
    
    # Get tokens for lines 2-3 only (method1 and method2)
    my $range = {
        start => { line => 2, character => 0 },
        end => { line => 3, character => 20 },
    };
    
    my $result = $st->get_semantic_tokens_range($doc, $range);
    ok(exists $result->{data}, 'Range result has data field');
    
    my @data = @{$result->{data}};
    ok(scalar @data > 0, 'Has semantic tokens for range');
};

# Test 8: Token type and modifier constants
subtest 'token_constants' => sub {
    # Check that all token type constants are defined
    ok(defined YAPLSPD::SemanticTokens::TOKEN_NAMESPACE, 'TOKEN_NAMESPACE defined');
    ok(defined YAPLSPD::SemanticTokens::TOKEN_TYPE, 'TOKEN_TYPE defined');
    ok(defined YAPLSPD::SemanticTokens::TOKEN_CLASS, 'TOKEN_CLASS defined');
    ok(defined YAPLSPD::SemanticTokens::TOKEN_FUNCTION, 'TOKEN_FUNCTION defined');
    ok(defined YAPLSPD::SemanticTokens::TOKEN_METHOD, 'TOKEN_METHOD defined');
    ok(defined YAPLSPD::SemanticTokens::TOKEN_VARIABLE, 'TOKEN_VARIABLE defined');
    ok(defined YAPLSPD::SemanticTokens::TOKEN_KEYWORD, 'TOKEN_KEYWORD defined');
    ok(defined YAPLSPD::SemanticTokens::TOKEN_STRING, 'TOKEN_STRING defined');
    ok(defined YAPLSPD::SemanticTokens::TOKEN_NUMBER, 'TOKEN_NUMBER defined');
    ok(defined YAPLSPD::SemanticTokens::TOKEN_COMMENT, 'TOKEN_COMMENT defined');
    ok(defined YAPLSPD::SemanticTokens::TOKEN_OPERATOR, 'TOKEN_OPERATOR defined');
    
    # Check token type legend
    ok(scalar @YAPLSPD::SemanticTokens::TOKEN_TYPES > 0, 'Token types legend exists');
    ok(scalar @YAPLSPD::SemanticTokens::TOKEN_MODIFIERS > 0, 'Token modifiers legend exists');
    
    # Verify legend matches constants
    is($YAPLSPD::SemanticTokens::TOKEN_TYPES[YAPLSPD::SemanticTokens::TOKEN_CLASS], 'class', 'Token type legend matches constant');
    is($YAPLSPD::SemanticTokens::TOKEN_TYPES[YAPLSPD::SemanticTokens::TOKEN_FUNCTION], 'function', 'Function type legend matches constant');
};

# Test 9: Complex Perl code with multiple token types
subtest 'complex_code_tokens' => sub {
    my $test_code = <<'PERL';
package Animal;
use strict;
use warnings;

sub new {
    my ($class, $name) = @_;
    my $self = { name => $name };
    return bless $self, $class;
}

sub speak {
    my $self = shift;
    print $self->{name} . " says something\n";
}

package Dog;
use base 'Animal';

sub speak {
    my $self = shift;
    print $self->{name} . " barks!\n";
}
PERL
    $test_code =~ s/^\n//;
    
    my $doc = TestDocument->new(
        uri => 'file:///test9.pl',
        text => $test_code,
    );
    
    my $st = YAPLSPD::SemanticTokens->new();
    my $result = $st->get_semantic_tokens_full($doc);
    
    ok(exists $result->{data}, 'Result has data field');
    my @data = @{$result->{data}};
    ok(scalar @data >= 5, 'Has multiple semantic tokens for complex code');
    ok(scalar @data % 5 == 0, 'Data is properly delta encoded');
};

# Test 10: Empty document
subtest 'empty_document' => sub {
    my $doc = TestDocument->new(
        uri => 'file:///test10.pl',
        text => '',
    );
    
    my $st = YAPLSPD::SemanticTokens->new();
    my $result = $st->get_semantic_tokens_full($doc);
    
    ok(exists $result->{data}, 'Empty document result has data field');
    ok(ref $result->{data} eq 'ARRAY', 'Empty document data is an array');
    is(scalar @{$result->{data}}, 0, 'Empty document has no tokens');
};

done_testing();
