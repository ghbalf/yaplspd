use strict;
use warnings;
use Test::More;

# Add lib to path
use lib 'lib';
use YAPLSPD::TypeHierarchy;

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

# Test 1: Package with @ISA inheritance
subtest 'isa_inheritance' => sub {
    my $test_code = <<'PERL';
package BaseClass;
sub new { bless {}, shift }

package ChildClass;
our @ISA = ('BaseClass');

sub new {
    my $class = shift;
    return $class->SUPER::new(@_);
}
PERL
    $test_code =~ s/^\n//;
    
    my $doc = TestDocument->new(
        uri => 'file:///test1.pl',
        text => $test_code,
    );
    
    my $th = YAPLSPD::TypeHierarchy->new();
    
    # Find line numbers
    my @lines = split(/\n/, $test_code);
    my ($child_line, $base_line);
    for (my $i = 0; $i < @lines; $i++) {
        $child_line = $i if $lines[$i] =~ /^package ChildClass/;
        $base_line = $i if $lines[$i] =~ /^package BaseClass/;
    }
    
    # Test prepare_type_hierarchy for ChildClass
    my $items = $th->prepare_type_hierarchy($doc, { line => $child_line, character => 10 });
    is(scalar @$items, 1, 'Found one type hierarchy item');
    is($items->[0]{name}, 'ChildClass', 'Item name is ChildClass');
    is($items->[0]{kind}, 5, 'Kind is Class (5)');
    
    # Test supertypes - find parents of ChildClass
    my $supertypes = $th->supertypes($doc, $items->[0]);
    is(scalar @$supertypes, 1, 'Found one supertype');
    is($supertypes->[0]{name}, 'BaseClass', 'Supertype is BaseClass');
    
    # Test subtypes - find children of BaseClass
    my $base_item = {
        name => 'BaseClass',
        kind => 5,
        uri => 'file:///test1.pl',
        range => { start => { line => $base_line, character => 8 }, end => { line => $base_line, character => 17 } },
    };
    my $subtypes = $th->subtypes($doc, $base_item);
    is(scalar @$subtypes, 1, 'Found one subtype');
    is($subtypes->[0]{name}, 'ChildClass', 'Subtype is ChildClass');
};

# Test 2: Multiple inheritance via @ISA
subtest 'multiple_inheritance' => sub {
    my $test_code = <<'PERL';
package Parent1;
sub method1 {}

package Parent2;
sub method2 {}

package MultiChild;
our @ISA = qw(Parent1 Parent2);
PERL
    $test_code =~ s/^\n//;
    
    my $doc = TestDocument->new(
        uri => 'file:///test2.pl',
        text => $test_code,
    );
    
    my $th = YAPLSPD::TypeHierarchy->new();
    
    my @lines = split(/\n/, $test_code);
    my ($multi_line);
    for (my $i = 0; $i < @lines; $i++) {
        $multi_line = $i if $lines[$i] =~ /^package MultiChild/;
    }
    
    my $items = $th->prepare_type_hierarchy($doc, { line => $multi_line, character => 10 });
    my $supertypes = $th->supertypes($doc, $items->[0]);
    
    is(scalar @$supertypes, 2, 'Found two supertypes');
    my @parent_names = map { $_->{name} } @$supertypes;
    is_deeply([sort @parent_names], ['Parent1', 'Parent2'], 'Parents are Parent1 and Parent2');
};

# Test 3: use base inheritance
subtest 'use_base_inheritance' => sub {
    my $test_code = <<'PERL';
package BaseClass;
sub new { bless {}, shift }

package ChildClass;
use base 'BaseClass';

sub new {
    my $class = shift;
    return $class->SUPER::new(@_);
}
PERL
    $test_code =~ s/^\n//;
    
    my $doc = TestDocument->new(
        uri => 'file:///test3.pl',
        text => $test_code,
    );
    
    my $th = YAPLSPD::TypeHierarchy->new();
    
    my @lines = split(/\n/, $test_code);
    my ($child_line);
    for (my $i = 0; $i < @lines; $i++) {
        $child_line = $i if $lines[$i] =~ /^package ChildClass/;
    }
    
    my $items = $th->prepare_type_hierarchy($doc, { line => $child_line, character => 10 });
    my $supertypes = $th->supertypes($doc, $items->[0]);
    
    is(scalar @$supertypes, 1, 'Found one supertype via use base');
    is($supertypes->[0]{name}, 'BaseClass', 'Supertype is BaseClass');
};

# Test 4: use parent inheritance
subtest 'use_parent_inheritance' => sub {
    my $test_code = <<'PERL';
package BaseClass;
sub new { bless {}, shift }

package ChildClass;
use parent 'BaseClass';

sub new {
    my $class = shift;
    return $class->SUPER::new(@_);
}
PERL
    $test_code =~ s/^\n//;
    
    my $doc = TestDocument->new(
        uri => 'file:///test4.pl',
        text => $test_code,
    );
    
    my $th = YAPLSPD::TypeHierarchy->new();
    
    my @lines = split(/\n/, $test_code);
    my ($child_line);
    for (my $i = 0; $i < @lines; $i++) {
        $child_line = $i if $lines[$i] =~ /^package ChildClass/;
    }
    
    my $items = $th->prepare_type_hierarchy($doc, { line => $child_line, character => 10 });
    my $supertypes = $th->supertypes($doc, $items->[0]);
    
    is(scalar @$supertypes, 1, 'Found one supertype via use parent');
    is($supertypes->[0]{name}, 'BaseClass', 'Supertype is BaseClass');
};

# Test 5: Package without inheritance (no supertypes)
subtest 'no_inheritance' => sub {
    my $test_code = <<'PERL';
package StandaloneClass;
sub new { bless {}, shift }
sub method { "hello" }
PERL
    $test_code =~ s/^\n//;
    
    my $doc = TestDocument->new(
        uri => 'file:///test5.pl',
        text => $test_code,
    );
    
    my $th = YAPLSPD::TypeHierarchy->new();
    
    my @lines = split(/\n/, $test_code);
    my ($standalone_line);
    for (my $i = 0; $i < @lines; $i++) {
        $standalone_line = $i if $lines[$i] =~ /^package StandaloneClass/;
    }
    
    my $items = $th->prepare_type_hierarchy($doc, { line => $standalone_line, character => 10 });
    my $supertypes = $th->supertypes($doc, $items->[0]);
    
    is(scalar @$supertypes, 0, 'No supertypes for standalone class');
};

# Test 6: Multiple packages, complex hierarchy
subtest 'complex_hierarchy' => sub {
    my $test_code = <<'PERL';
package GrandParent;
sub new { bless {}, shift }

package Parent;
our @ISA = ('GrandParent');

package Child1;
our @ISA = ('Parent');

package Child2;
our @ISA = ('Parent');
PERL
    $test_code =~ s/^\n//;
    
    my $doc = TestDocument->new(
        uri => 'file:///test6.pl',
        text => $test_code,
    );
    
    my $th = YAPLSPD::TypeHierarchy->new();
    
    my @lines = split(/\n/, $test_code);
    my ($parent_line, $child1_line);
    for (my $i = 0; $i < @lines; $i++) {
        $parent_line = $i if $lines[$i] =~ /^package Parent;/;
        $child1_line = $i if $lines[$i] =~ /^package Child1;/;
    }
    
    # Test supertypes of Parent
    my $parent_item = {
        name => 'Parent',
        kind => 5,
        uri => 'file:///test6.pl',
        range => { start => { line => $parent_line, character => 8 }, end => { line => $parent_line, character => 14 } },
    };
    my $parent_supertypes = $th->supertypes($doc, $parent_item);
    is(scalar @$parent_supertypes, 1, 'Parent has one supertype');
    is($parent_supertypes->[0]{name}, 'GrandParent', 'Parent supertype is GrandParent');
    
    # Test subtypes of Parent (should have both Child1 and Child2)
    my $parent_subtypes = $th->subtypes($doc, $parent_item);
    is(scalar @$parent_subtypes, 2, 'Parent has two subtypes');
    my @child_names = map { $_->{name} } @$parent_subtypes;
    is_deeply([sort @child_names], ['Child1', 'Child2'], 'Subtypes are Child1 and Child2');
};

# Test 7: prepare_type_hierarchy returns empty for non-package position
subtest 'prepare_nonexistent' => sub {
    my $test_code = "package TestClass;\nsub method { 1 }\n";
    
    my $doc = TestDocument->new(
        uri => 'file:///test7.pl',
        text => $test_code,
    );
    
    my $th = YAPLSPD::TypeHierarchy->new();
    
    # Try position in the middle of "sub"
    my $items = $th->prepare_type_hierarchy($doc, { line => 1, character => 1 });
    is(scalar @$items, 0, 'No items for non-package position');
};

done_testing();
