#!/usr/bin/env perl
use strict;
use warnings;
use lib 'lib';
use YAPLSPD::Server;
use YAPLSPD::Protocol;
use YAPLSPD::Document;
use YAPLSPD::Formatting;
use YAPLSPD::Completion;
use YAPLSPD::Hover;
use YAPLSPD::Definition;
use YAPLSPD::References;
use YAPLSPD::DocumentSymbol;
use JSON::PP;

# Mock protocol for testing
package MockProtocol {
    sub new { bless { messages => [] }, shift }
    sub send_message { 
        my ($self, $msg) = @_; 
        push @{$self->{messages}}, $msg;
    }
    sub get_last_message { shift->{messages}[-1] }
    sub clear { shift->{messages} = [] }
}

# Test formatting functionality
print "Testing YAPLSPD document formatting...\n";

# Create test server
my $protocol = MockProtocol->new;
my $formatting = YAPLSPD::Formatting->new;
my $completion = YAPLSPD::Completion->new;
my $hover = YAPLSPD::Hover->new;
my $definition = YAPLSPD::Definition->new;
my $references = YAPLSPD::References->new;
my $document_symbol = YAPLSPD::DocumentSymbol->new;

my $server = YAPLSPD::Server->new(
    protocol => $protocol,
    formatting => $formatting,
    completion => $completion,
    hover => $hover,
    definition => $definition,
    references => $references,
    document_symbol => $document_symbol,
);

# Test with messy Perl code
my $messy_code = <<'PERL';
sub messy_function  {
my($x,$y)=@_;if($x>0){return $x+$y;}else{return $y-$x;}}
my $var=42;
if($var==42){
print"Hello";}
PERL

# Initialize document
$server->handle_message({
    jsonrpc => '2.0',
    method => 'textDocument/didOpen',
    params => {
        textDocument => {
            uri => 'file:///test.pl',
            languageId => 'perl',
            version => 1,
            text => $messy_code
        }
    }
});

# Test formatting request
$protocol->clear;
$server->handle_message({
    jsonrpc => '2.0',
    id => 1,
    method => 'textDocument/formatting',
    params => {
        textDocument => { uri => 'file:///test.pl' },
        options => {
            tabSize => 4,
            insertSpaces => JSON::PP::true
        }
    }
});

my $response = $protocol->get_last_message;
if ($response && $response->{result}) {
    print "✅ Formatting successful!\n";
    print "Edits returned: " . scalar(@{$response->{result}}) . "\n";
    
    if (@{$response->{result}}) {
        my $edit = $response->{result}[0];
        print "Formatted code:\n";
        print "=" x 50 . "\n";
        print $edit->{newText};
        print "=" x 50 . "\n";
    } else {
        print "No formatting changes needed.\n";
    }
} else {
    print "❌ Formatting failed or no response\n";
    print "Response: " . JSON::PP->new->pretty->encode($response) if $response;
}

# Test error handling - invalid Perl
print "\nTesting with invalid Perl code...\n";
my $invalid_code = "sub { invalid perl syntax here";

$server->handle_message({
    jsonrpc => '2.0',
    method => 'textDocument/didOpen',
    params => {
        textDocument => {
            uri => 'file:///invalid.pl',
            languageId => 'perl',
            version => 1,
            text => $invalid_code
        }
    }
});

$protocol->clear;
$server->handle_message({
    jsonrpc => '2.0',
    id => 2,
    method => 'textDocument/formatting',
    params => {
        textDocument => { uri => 'file:///invalid.pl' },
        options => { tabSize => 4, insertSpaces => JSON::PP::true }
    }
});

$response = $protocol->get_last_message;
if ($response && ref($response->{result}) eq 'ARRAY') {
    print "✅ Graceful handling of invalid code - empty edits returned\n";
} else {
    print "❌ Unexpected response for invalid code\n";
}

print "\nFormatting test complete!\n";