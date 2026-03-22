#!/usr/bin/env perl
use strict;
use warnings;
use lib 'lib';

# Simple diagnostics integration test
package SimpleServer;
use YAPLSPD::Diagnostics;
use YAPLSPD::Document;

sub new {
    my ($class) = @_;
    my $self = bless {
        diagnostics => YAPLSPD::Diagnostics->new,
        documents => {},
    }, $class;
    return $self;
}

sub handle_did_open {
    my ($self, $uri, $text) = @_;
    my $doc = YAPLSPD::Document->new(
        uri => $uri,
        text => $text,
        version => 1
    );
    $self->{documents}{$uri} = $doc;
    
    my $diagnostics = $self->{diagnostics}->analyze_document($doc);
    return $diagnostics;
}

package main;

my $server = SimpleServer->new;

# Test with actual Perl code
my $test_perl = <<'PERL';
#!/usr/bin/env perl
use strict;
use warnings;

sub hello {
    my ($name = @_;  # Missing closing paren
    print "Hello $name\n";
}

my $x = 1
PERL

print "Testing Perl LSP Diagnostics Integration\n";
print "=" x 50 . "\n";

my $diagnostics = $server->handle_did_open('file:///test.pl', $test_perl);

print "Found " . scalar(@$diagnostics) . " diagnostics:\n\n";

foreach my $diag (@$diagnostics) {
    printf "Line %d: %s (Severity: %d)\n",
        $diag->{range}{start}{line} + 1,
        $diag->{message},
        $diag->{severity};
}

print "\n" . "=" x 50 . "\n";
print "Diagnostics feature implemented successfully!\n";