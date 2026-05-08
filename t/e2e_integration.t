#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use lib 'lib';

# E2E Integration Tests for YAPLSPD
# Tests complete LSP server lifecycle: initialize -> document sync -> features -> shutdown

use YAPLSPD::Server;
use YAPLSPD::Document;
use YAPLSPD::Completion;
use YAPLSPD::Hover;
use YAPLSPD::Definition;
use YAPLSPD::References;
use YAPLSPD::DocumentSymbol;
use YAPLSPD::Formatting;
use YAPLSPD::Diagnostics;
use YAPLSPD::SignatureHelp;
use YAPLSPD::Rename;
use YAPLSPD::CodeAction;
use YAPLSPD::FoldingRange;
use YAPLSPD::DocumentHighlight;
use YAPLSPD::CodeLens;
use YAPLSPD::SelectionRange;
use YAPLSPD::WorkspaceSymbol;

# Mock Protocol handler to capture server responses
package MockProtocol {
    sub new {
        my ($class) = @_;
        return bless { messages => [] }, $class;
    }
    
    sub send_message {
        my ($self, $msg) = @_;
        push @{$self->{messages}}, $msg;
    }
    
    sub last_message {
        my ($self) = @_;
        return $self->{messages}[-1];
    }
    
    sub clear {
        my ($self) = @_;
        $self->{messages} = [];
    }
};

# Test helper to create server instance
sub create_test_server {
    my $protocol = MockProtocol->new();
    my $server = YAPLSPD::Server->new(
        protocol => $protocol,
        completion => YAPLSPD::Completion->new(),
        hover => YAPLSPD::Hover->new(),
        definition => YAPLSPD::Definition->new(),
        references => YAPLSPD::References->new(),
        document_symbol => YAPLSPD::DocumentSymbol->new(),
        formatting => YAPLSPD::Formatting->new(),
        diagnostics => YAPLSPD::Diagnostics->new(),
        signature_help => YAPLSPD::SignatureHelp->new(),
        rename => YAPLSPD::Rename->new(),
        code_action => YAPLSPD::CodeAction->new(),
        folding_range => YAPLSPD::FoldingRange->new(),
        document_highlight => YAPLSPD::DocumentHighlight->new(),
        code_lens => YAPLSPD::CodeLens->new(),
        selection_range => YAPLSPD::SelectionRange->new(),
        workspace_symbol => YAPLSPD::WorkspaceSymbol->new(),
    );
    return ($server, $protocol);
}

# ============================================
# Test 1: Initialize Request
# ============================================
subtest 'LSP Initialize' => sub {
    my ($server, $protocol) = create_test_server();
    
    $server->handle_message({
        id => 1,
        method => 'initialize',
        params => {
            processId => $$,
            rootUri => 'file:///test/project',
            capabilities => {}
        }
    });
    
    my $response = $protocol->last_message();
    is($response->{jsonrpc}, '2.0', 'JSON-RPC version correct');
    is($response->{id}, 1, 'Response ID matches request');
    ok(exists $response->{result}{capabilities}, 'Server returns capabilities');
    ok(exists $response->{result}{capabilities}{textDocumentSync}, 'TextDocumentSync capability present');
    ok(exists $response->{result}{capabilities}{completionProvider}, 'Completion capability present');
    ok(exists $response->{result}{capabilities}{hoverProvider}, 'Hover capability present');
    ok(exists $response->{result}{capabilities}{definitionProvider}, 'Definition capability present');
    ok(exists $response->{result}{capabilities}{referencesProvider}, 'References capability present');
};

# ============================================
# Test 2: Document Lifecycle
# ============================================
subtest 'Document Lifecycle: Open -> Change -> Close' => sub {
    my ($server, $protocol) = create_test_server();
    
    my $uri = 'file:///test/e2e.pl';
    my $content = <<'PERL';
use strict;
use warnings;

sub greet {
    my ($name) = @_;
    return "Hello, $name!";
}

my $result = greet('World');
print $result;
PERL

    # Open document
    $server->handle_message({
        method => 'textDocument/didOpen',
        params => {
            textDocument => {
                uri => $uri,
                languageId => 'perl',
                version => 1,
                text => $content
            }
        }
    });
    
    ok(exists $server->{documents}{$uri}, 'Document stored in server');
    is($server->{documents}{$uri}->version, 1, 'Document version correct');
    
    # Change document
    $server->handle_message({
        method => 'textDocument/didChange',
        params => {
            textDocument => { uri => $uri, version => 2 },
            contentChanges => [{ text => "use strict;\n\nsub new_func { 42 }" }]
        }
    });
    
    is($server->{documents}{$uri}->version, 2, 'Document version incremented');
    like($server->{documents}{$uri}->text, qr/new_func/, 'Document content updated');
    
    # Close document
    $server->handle_message({
        method => 'textDocument/didClose',
        params => {
            textDocument => { uri => $uri }
        }
    });
    
    ok(!exists $server->{documents}{$uri}, 'Document removed from server');
};

# ============================================
# Test 3: Completion E2E
# ============================================
subtest 'Completion E2E' => sub {
    my ($server, $protocol) = create_test_server();
    
    my $uri = 'file:///test/completion.pl';
    my $content = <<'PERL';
use strict;
use warnings;

sub calculate {
    my ($x, $y) = @_;
    return $x + $y;
}

my $result = calc
PERL

    # Open document
    $server->handle_message({
        method => 'textDocument/didOpen',
        params => {
            textDocument => {
                uri => $uri,
                languageId => 'perl',
                version => 1,
                text => $content
            }
        }
    });
    
    # Request completion at line 8, after "calc"
    $server->handle_message({
        id => 10,
        method => 'textDocument/completion',
        params => {
            textDocument => { uri => $uri },
            position => { line => 8, character => 15 }
        }
    });
    
    my $response = $protocol->last_message();
    is($response->{id}, 10, 'Completion response has correct ID');
    ok(exists $response->{result}, 'Completion returns result');
};

# ============================================
# Test 4: Hover E2E
# ============================================
subtest 'Hover E2E' => sub {
    my ($server, $protocol) = create_test_server();
    
    my $uri = 'file:///test/hover.pl';
    my $content = <<'PERL';
use strict;
use warnings;

sub add_numbers {
    my ($a, $b) = @_;
    return $a + $b;
}

my $sum = add_numbers(5, 3);
PERL

    $server->handle_message({
        method => 'textDocument/didOpen',
        params => {
            textDocument => {
                uri => $uri,
                languageId => 'perl',
                version => 1,
                text => $content
            }
        }
    });
    
    $server->handle_message({
        id => 20,
        method => 'textDocument/hover',
        params => {
            textDocument => { uri => $uri },
            position => { line => 7, character => 12 }
        }
    });
    
    my $response = $protocol->last_message();
    is($response->{id}, 20, 'Hover response has correct ID');
    ok(exists $response->{result}, 'Hover returns result');
};

# ============================================
# Test 5: Go to Definition E2E
# ============================================
subtest 'Definition E2E' => sub {
    my ($server, $protocol) = create_test_server();
    
    my $uri = 'file:///test/definition.pl';
    my $content = <<'PERL';
use strict;
use warnings;

sub my_function {
    return 42;
}

my $result = my_function();
PERL

    $server->handle_message({
        method => 'textDocument/didOpen',
        params => {
            textDocument => {
                uri => $uri,
                languageId => 'perl',
                version => 1,
                text => $content
            }
        }
    });
    
    $server->handle_message({
        id => 30,
        method => 'textDocument/definition',
        params => {
            textDocument => { uri => $uri },
            position => { line => 6, character => 15 }
        }
    });
    
    my $response = $protocol->last_message();
    is($response->{id}, 30, 'Definition response has correct ID');
    ok(exists $response->{result}, 'Definition returns result');
};

# ============================================
# Test 6: Find References E2E
# ============================================
subtest 'References E2E' => sub {
    my ($server, $protocol) = create_test_server();
    
    my $uri = 'file:///test/references.pl';
    my $content = <<'PERL';
use strict;
use warnings;

sub helper {
    return 1;
}

helper();
my $x = helper();
PERL

    $server->handle_message({
        method => 'textDocument/didOpen',
        params => {
            textDocument => {
                uri => $uri,
                languageId => 'perl',
                version => 1,
                text => $content
            }
        }
    });
    
    $server->handle_message({
        id => 40,
        method => 'textDocument/references',
        params => {
            textDocument => { uri => $uri },
            position => { line => 3, character => 5 },
            context => { includeDeclaration => JSON::PP::true }
        }
    });
    
    my $response = $protocol->last_message();
    is($response->{id}, 40, 'References response has correct ID');
    ok(exists $response->{result}, 'References returns result');
};

# ============================================
# Test 7: Document Symbol E2E
# ============================================
subtest 'Document Symbol E2E' => sub {
    my ($server, $protocol) = create_test_server();
    
    my $uri = 'file:///test/symbols.pl';
    my $content = <<'PERL';
use strict;
use warnings;

sub first_sub { }
sub second_sub { }
my $var = 1;
PERL

    $server->handle_message({
        method => 'textDocument/didOpen',
        params => {
            textDocument => {
                uri => $uri,
                languageId => 'perl',
                version => 1,
                text => $content
            }
        }
    });
    
    $server->handle_message({
        id => 50,
        method => 'textDocument/documentSymbol',
        params => {
            textDocument => { uri => $uri }
        }
    });
    
    my $response = $protocol->last_message();
    is($response->{id}, 50, 'DocumentSymbol response has correct ID');
    ok(exists $response->{result}, 'DocumentSymbol returns result');
};

# ============================================
# Test 8: Formatting E2E
# ============================================
subtest 'Formatting E2E' => sub {
    my ($server, $protocol) = create_test_server();
    
    my $uri = 'file:///test/format.pl';
    my $content = <<'PERL';
use strict;
use warnings;

sub messy{
my $x=1;
return $x;
}
PERL

    $server->handle_message({
        method => 'textDocument/didOpen',
        params => {
            textDocument => {
                uri => $uri,
                languageId => 'perl',
                version => 1,
                text => $content
            }
        }
    });
    
    $server->handle_message({
        id => 60,
        method => 'textDocument/formatting',
        params => {
            textDocument => { uri => $uri },
            options => { tabSize => 4, insertSpaces => JSON::PP::true }
        }
    });
    
    my $response = $protocol->last_message();
    is($response->{id}, 60, 'Formatting response has correct ID');
    ok(exists $response->{result}, 'Formatting returns result');
};

# ============================================
# Test 9: Signature Help E2E
# ============================================
subtest 'Signature Help E2E' => sub {
    my ($server, $protocol) = create_test_server();
    
    my $uri = 'file:///test/signature.pl';
    my $content = <<'PERL';
use strict;
use warnings;

sub process_data {
    my ($input, $options) = @_;
    return $input;
}

process_data(
PERL

    $server->handle_message({
        method => 'textDocument/didOpen',
        params => {
            textDocument => {
                uri => $uri,
                languageId => 'perl',
                version => 1,
                text => $content
            }
        }
    });
    
    $server->handle_message({
        id => 70,
        method => 'textDocument/signatureHelp',
        params => {
            textDocument => { uri => $uri },
            position => { line => 7, character => 12 }
        }
    });
    
    my $response = $protocol->last_message();
    is($response->{id}, 70, 'SignatureHelp response has correct ID');
    ok(exists $response->{result}, 'SignatureHelp returns result');
};

# ============================================
# Test 10: Full Workflow - Multiple Operations
# ============================================
subtest 'Full Workflow: Multiple Operations' => sub {
    my ($server, $protocol) = create_test_server();
    
    my $uri = 'file:///test/workflow.pl';
    my $content = <<'PERL';
use strict;
use warnings;

sub calculate_sum {
    my ($a, $b) = @_;
    return $a + $b;
}

my $result = calculate_sum(10, 20);
print $result;
PERL

    # Initialize
    $server->handle_message({
        id => 1,
        method => 'initialize',
        params => { processId => $$, rootUri => 'file:///test', capabilities => {} }
    });
    ok($protocol->last_message()->{result}{capabilities}, 'Initialize successful');
    
    # Open document
    $server->handle_message({
        method => 'textDocument/didOpen',
        params => {
            textDocument => {
                uri => $uri,
                languageId => 'perl',
                version => 1,
                text => $content
            }
        }
    });
    ok(exists $server->{documents}{$uri}, 'Document opened');
    
    # Get document symbols
    $server->handle_message({
        id => 2,
        method => 'textDocument/documentSymbol',
        params => { textDocument => { uri => $uri } }
    });
    ok($protocol->last_message()->{result}, 'Document symbols retrieved');
    
    # Get hover info (on calculate_sum subroutine call)
    $server->handle_message({
        id => 3,
        method => 'textDocument/hover',
        params => { textDocument => { uri => $uri }, position => { line => 7, character => 17 } }
    });
    # Hover returns result (may be undef if no info at position - that's valid LSP behavior)
    ok(exists $protocol->last_message()->{result}, 'Hover response has result field');
    
    # Find references
    $server->handle_message({
        id => 4,
        method => 'textDocument/references',
        params => {
            textDocument => { uri => $uri },
            position => { line => 3, character => 5 },
            context => { includeDeclaration => JSON::PP::true }
        }
    });
    ok($protocol->last_message()->{result}, 'References found');
    
    # Shutdown
    $server->handle_message({
        id => 99,
        method => 'shutdown',
        params => {}
    });
    is($protocol->last_message()->{id}, 99, 'Shutdown response received');
    
    # Close document
    $server->handle_message({
        method => 'textDocument/didClose',
        params => { textDocument => { uri => $uri } }
    });
    ok(!exists $server->{documents}{$uri}, 'Document closed');
};

# ============================================
# Test 11: Error Handling - Invalid Document
# ============================================
subtest 'Error Handling: Operations on Non-existent Document' => sub {
    my ($server, $protocol) = create_test_server();
    
    my $fake_uri = 'file:///nonexistent/file.pl';
    
    # Try to get symbols for non-existent document
    $server->handle_message({
        id => 100,
        method => 'textDocument/documentSymbol',
        params => { textDocument => { uri => $fake_uri } }
    });
    
    # Server should handle gracefully without crashing
    pass('Server handles non-existent document gracefully');
};

# ============================================
# Test 12: Multiple Documents
# ============================================
subtest 'Multiple Documents Management' => sub {
    my ($server, $protocol) = create_test_server();
    
    my @uris = (
        'file:///test/file1.pl',
        'file:///test/file2.pl',
        'file:///test/file3.pl'
    );
    
    # Open multiple documents
    for my $i (0..$#uris) {
        $server->handle_message({
            method => 'textDocument/didOpen',
            params => {
                textDocument => {
                    uri => $uris[$i],
                    languageId => 'perl',
                    version => 1,
                    text => "# File $i\nsub func$i { }"
                }
            }
        });
    }
    
    is(scalar(keys %{$server->{documents}}), 3, 'All 3 documents tracked');
    
    # Verify each document
    for my $i (0..$#uris) {
        ok(exists $server->{documents}{$uris[$i]}, "Document $i exists");
        like($server->{documents}{$uris[$i]}->text, qr/func$i/, "Document $i has correct content");
    }
    
    # Close one document
    $server->handle_message({
        method => 'textDocument/didClose',
        params => { textDocument => { uri => $uris[1] } }
    });
    
    is(scalar(keys %{$server->{documents}}), 2, 'Document count after close');
    ok(!exists $server->{documents}{$uris[1]}, 'Closed document removed');
    ok(exists $server->{documents}{$uris[0]}, 'Other documents still exist');
    ok(exists $server->{documents}{$uris[2]}, 'Other documents still exist');
};

done_testing();
