#!/usr/bin/env perl
use strict;
use warnings;
use lib 'lib';
use YAPLSPD::Server;
use YAPLSPD::Protocol;
use YAPLSPD::Completion;
use YAPLSPD::Hover;
use YAPLSPD::Definition;
use YAPLSPD::References;
use YAPLSPD::DocumentSymbol;
use YAPLSPD::Formatting;
use YAPLSPD::Diagnostics;

# Mock protocol for testing
package MockProtocol;
sub new { bless {}, shift }
sub send_message {
    my ($self, $message) = @_;
    print "SEND: " . (defined $message ? join("", @$message) : "undef") . "\n" if $ENV{DEBUG};
}

package main;

# Create server with all components
my $protocol = MockProtocol->new;
my $completion = YAPLSPD::Completion->new;
my $hover = YAPLSPD::Hover->new;
my $definition = YAPLSPD::Definition->new;
my $references = YAPLSPD::References->new;
my $document_symbol = YAPLSPD::DocumentSymbol->new;
my $formatting = YAPLSPD::Formatting->new;
my $diagnostics = YAPLSPD::Diagnostics->new;

my $server = YAPLSPD::Server->new(
    protocol => $protocol,
    completion => $completion,
    hover => $hover,
    definition => $definition,
    references => $references,
    document_symbol => $document_symbol,
    formatting => $formatting,
    diagnostics => $diagnostics,
);

# Test with a sample Perl file with syntax issues
my $test_perl_code = <<'PERL';
#!/usr/bin/env perl
use strict;
use warnings;

my $undeclared_var = "test";
print "Hello World\n";

sub test_function {
    my ($param1, $param2) = @_;  # Missing closing brace
    
    my $unused_variable = "never used";
    
    return 1;
    
    print "Unreachable code";  # This will never execute
}

if ($undeclared_var eq "test") {
    print "Test\n";
PERL

# Simulate didOpen
my $did_open_message = {
    jsonrpc => '2.0',
    method => 'textDocument/didOpen',
    params => {
        textDocument => {
            uri => 'file:///test.pl',
            languageId => 'perl',
            version => 1,
            text => $test_perl_code
        }
    }
};

print "Testing diagnostics...\n";
print "=" x 50 . "\n";

$server->handle_message($did_open_message);

print "Diagnostics test completed.\n";
print "Expected diagnostics:\n";
print "1. Unclosed block at end of file\n";
print "2. Unused variable 'unused_variable'\n";
print "3. Unreachable code after return\n";
print "4. Trailing whitespace (if any)\n";

# Test with a clean file
my $clean_perl_code = <<'PERL';
#!/usr/bin/env perl
use strict;
use warnings;

sub hello {
    my ($name) = @_;
    return "Hello, $name!";
}

print hello("World") . "\n";
PERL

print "\nTesting with clean code...\n";
print "=" x 30 . "\n";

my $did_change_message = {
    jsonrpc => '2.0',
    method => 'textDocument/didChange',
    params => {
        textDocument => { uri => 'file:///test.pl', version => 2 },
        contentChanges => [{
            text => $clean_perl_code
        }]
    }
};

$server->handle_message($did_change_message);

print "Clean code test completed.\n";