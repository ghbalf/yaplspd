#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use JSON::PP;
use IPC::Open2;
use File::Temp qw(tempdir);
use File::Spec;
use File::Basename;

# E2E Integration Test for YAPLSPD
# Tests real LSP communication via stdin/stdout

plan tests => 10;

my $bindir = File::Spec->catfile(dirname(__FILE__), '..', 'bin');
my $yaplspd = File::Spec->catfile($bindir, 'yaplspd');

SKIP: {
    skip "yaplspd not found at $yaplspd", 12 unless -x $yaplspd;
    
    my $tempdir = tempdir(CLEANUP => 1);
    my $test_file = File::Spec->catfile($tempdir, 'test.pl');
    
    # Create test Perl file
    open my $fh, '>', $test_file or die "Cannot create test file: $!";
    print $fh <<'PERL';
package TestModule;
use strict;
use warnings;

sub greet {
    my ($name) = @_;
    return "Hello, $name!";
}

my $result = greet("World");
1;
PERL
    close $fh;
    
    # Start yaplspd server using open2
    my $pid = open2(my $out, my $in, $^X, $yaplspd);
    ok(defined $pid, "Server started with PID $pid");
    
    my $json = JSON::PP->new->utf8->canonical;
    my $request_id = 0;
    
    sub send_request {
        my ($method, $params) = @_;
        $request_id++;
        my $msg = {
            jsonrpc => '2.0',
            id => $request_id,
            method => $method,
            params => $params
        };
        my $content = $json->encode($msg);
        print $in sprintf("Content-Length: %d\r\n\r\n%s", length($content), $content);
        return $request_id;
    }
    
    sub send_notification {
        my ($method, $params) = @_;
        my $msg = {
            jsonrpc => '2.0',
            method => $method,
            params => $params
        };
        my $content = $json->encode($msg);
        print $in sprintf("Content-Length: %d\r\n\r\n%s", length($content), $content);
    }
    
    sub read_response {
        my $timeout = shift || 10;
        my $response = '';
        my $content_length;
        my $start_time = time;
        
        while (time - $start_time < $timeout) {
            my $char;
            if (read($out, $char, 1)) {
                $response .= $char;
                
                # Check if we have complete header
                if (!defined $content_length && $response =~ /^Content-Length:\s*(\d+)\r?\n\r?\n/) {
                    $content_length = $1;
                    my $header_end = $+[0];
                    my $body_received = length($response) - $header_end;
                    
                    if ($body_received >= $content_length) {
                        my $body = substr($response, $header_end, $content_length);
                        return $json->decode($body);
                    }
                }
                elsif (defined $content_length) {
                    my $header_end = index($response, "\r\n\r\n") + 4;
                    my $body_received = length($response) - $header_end;
                    
                    if ($body_received >= $content_length) {
                        my $body = substr($response, $header_end, $content_length);
                        return $json->decode($body);
                    }
                }
            }
            else {
                select(undef, undef, undef, 0.01);
            }
        }
        return undef;
    }
    
    # Test 1: Initialize - core LSP method
    diag("Testing initialize...");
    send_request('initialize', {
        processId => $$,
        rootUri => 'file://' . $tempdir,
        capabilities => {}
    });
    
    my $resp = read_response();
    ok(defined $resp, "Received initialize response");
    ok($resp->{result}->{capabilities}, "Server returned capabilities");
    ok($resp->{result}->{capabilities}->{textDocumentSync}, "textDocumentSync capability present");
    ok($resp->{result}->{capabilities}->{completionProvider}, "completionProvider capability present");
    ok($resp->{result}->{capabilities}->{hoverProvider}, "hoverProvider capability present");
    
    # Test 2: textDocument/didOpen - notification (no response expected)
    diag("Testing textDocument/didOpen...");
    my $file_content = do { local $/; open my $f, '<', $test_file; <$f> };
    send_notification('textDocument/didOpen', {
        textDocument => {
            uri => 'file://' . $test_file,
            languageId => 'perl',
            version => 1,
            text => $file_content
        }
    });
    
    select(undef, undef, undef, 0.3);
    pass("textDocument/didOpen processed");
    
    # Test 3: textDocument/hover - common LSP method
    diag("Testing textDocument/hover...");
    send_request('textDocument/hover', {
        textDocument => { uri => 'file://' . $test_file },
        position => { line => 1, character => 0 }
    });
    
    $resp = read_response();
    ok(defined $resp, "Received hover response");
    
    # Test 4: Shutdown
    diag("Testing shutdown...");
    send_request('shutdown', {});
    
    $resp = read_response();
    ok(defined $resp, "Received shutdown response");
    
    # Test 5: Exit notification
    diag("Testing exit...");
    send_notification('exit', {});
    
    # Wait for server to exit
    select(undef, undef, undef, 0.5);
    close $in;
    close $out;
    
    my $kid = waitpid($pid, 0);
    ok($kid == $pid, "Server process reaped cleanly");
}
