#!/usr/bin/env perl
use strict;
use warnings;
use lib 'lib';
use YAPLSPD::Formatting;

print "Testing YAPLSPD document formatting (basic)...\n";

# Create test document package
{
    package TestDocument;
    sub new { bless { text => $_[1] }, shift }
    sub text { shift->{text} }
}

my $formatter = YAPLSPD::Formatting->new;

# Test with messy Perl code
my $messy_code = <<'PERL';
sub messy_function  {
my($x,$y)=@_;if($x>0){return $x+$y;}else{return $y-$x;}}
my $var=42;
if($var==42){
print"Hello";}
PERL

my $doc = TestDocument->new($messy_code);

# Test formatting
my $edits = $formatter->format_document($doc);

if ($edits && ref($edits) eq 'ARRAY') {
    print "✅ Formatting successful!\n";
    print "Edits returned: " . scalar(@$edits) . "\n";
    
    if (@$edits) {
        my $edit = $edits->[0];
        print "Formatted code:\n";
        print "=" x 50 . "\n";
        print $edit->{newText};
        print "=" x 50 . "\n";
    } else {
        print "No formatting changes needed.\n";
    }
} else {
    print "❌ Formatting failed\n";
}

print "\nBasic formatting test complete!\n";