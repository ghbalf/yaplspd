#!/usr/bin/env perl
use strict;
use warnings;
use lib 'lib';
use YAPLSPD::Diagnostics;
use YAPLSPD::Document;

# Create diagnostics analyzer
my $diagnostics = YAPLSPD::Diagnostics->new;

# Test with a Perl file with syntax issues
my $test_code = <<'PERL';
#!/usr/bin/env perl
use strict;
use warnings;

sub test_function {
    my ($param1, $param2 = @_;  # Missing closing paren
    
    my $unused_variable = "never used";   
    
    return 1;
}

if (1 {
    print "Missing closing paren\n";
}
PERL

# Create document
my $document = YAPLSPD::Document->new(
    uri => 'file:///test.pl',
    text => $test_code,
    version => 1
);

# Analyze document
my $results = $diagnostics->analyze_document($document);

print "Diagnostics test results:\n";
print "=" x 50 . "\n";

if (@$results) {
    foreach my $diag (@$results) {
        printf "Line %d: %s\n", 
            $diag->{range}{start}{line} + 1,
            $diag->{message};
        printf "  Severity: %d\n", $diag->{severity};
        printf "  Range: %d:%d to %d:%d\n",
            $diag->{range}{start}{line},
            $diag->{range}{start}{character},
            $diag->{range}{end}{line},
            $diag->{range}{end}{character};
        print "\n";
    }
} else {
    print "No diagnostics found.\n";
}

print "Test completed.\n";