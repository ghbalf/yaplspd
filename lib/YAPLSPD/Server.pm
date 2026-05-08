package YAPLSPD::Server;
use strict;
use warnings;
use JSON::PP;

sub new {
    my ($class, %args) = @_;
    
    # Initialize memory manager for long session optimization
    require YAPLSPD::MemoryManager;
    my $memory_manager = YAPLSPD::MemoryManager->new();
    
    my $self = bless {
        protocol => $args{protocol},
        documents => {},
        memory_manager => $memory_manager,
        completion => $args{completion},
        hover => $args{hover},
        definition => $args{definition},
        references => $args{references},
        document_symbol => $args{document_symbol},
        formatting => $args{formatting},
        diagnostics => $args{diagnostics},
        signature_help => $args{signature_help},
        rename => $args{rename},
        code_action => $args{code_action},
        folding_range => $args{folding_range},
        document_highlight => $args{document_highlight},
        code_lens => $args{code_lens},
        selection_range => $args{selection_range},
        workspace_symbol => $args{workspace_symbol},
        call_hierarchy => $args{call_hierarchy},
        type_hierarchy => $args{type_hierarchy},
        semantic_tokens => $args{semantic_tokens},
    }, $class;
    return $self;
}

sub handle_message {
    my ($self, $message) = @_;

    my $method = $message->{method};

    if ($method eq 'initialize') {
        $self->_handle_initialize($message);
    }
    elsif ($method eq 'textDocument/didOpen') {
        $self->_handle_did_open($message);
    }
    elsif ($method eq 'textDocument/didChange') {
        $self->_handle_did_change($message);
    }
    elsif ($method eq 'textDocument/didClose') {
        $self->_handle_did_close($message);
    }
    elsif ($method eq 'textDocument/completion') {
        $self->_handle_completion($message);
    }
    elsif ($method eq 'textDocument/hover') {
        $self->_handle_hover($message);
    }
    elsif ($method eq 'textDocument/definition') {
        $self->_handle_definition($message);
    }
    elsif ($method eq 'textDocument/references') {
        $self->_handle_references($message);
    }
    elsif ($method eq 'textDocument/documentSymbol') {
        $self->_handle_document_symbol($message);
    }
    elsif ($method eq 'textDocument/formatting') {
        $self->_handle_formatting($message);
    }
    elsif ($method eq 'textDocument/didSave') {
        $self->_handle_did_save($message);
    }
    elsif ($method eq 'textDocument/rangeFormatting') {
        $self->_handle_range_formatting($message);
    }
    elsif ($method eq 'textDocument/signatureHelp') {
        $self->_handle_signature_help($message);
    }
    elsif ($method eq 'textDocument/rename') {
        $self->_handle_rename($message);
    }
    elsif ($method eq 'textDocument/codeAction') {
        $self->_handle_code_action($message);
    }
    elsif ($method eq 'textDocument/foldingRange') {
        $self->_handle_folding_range($message);
    }
    elsif ($method eq 'textDocument/documentHighlight') {
        $self->_handle_document_highlight($message);
    }
    elsif ($method eq 'textDocument/codeLens') {
        $self->_handle_code_lens($message);
    }
    elsif ($method eq 'textDocument/selectionRange') {
        $self->_handle_selection_range($message);
    }
    elsif ($method eq 'workspace/symbol') {
        $self->_handle_workspace_symbol($message);
    }
    elsif ($method eq 'workspace/didChangeConfiguration') {
        $self->_handle_did_change_configuration($message);
    }
    elsif ($method eq 'workspace/didChangeWatchedFiles') {
        $self->_handle_did_change_watched_files($message);
    }
    elsif ($method eq 'textDocument/prepareCallHierarchy') {
        $self->_handle_prepare_call_hierarchy($message);
    }
    elsif ($method eq 'callHierarchy/incomingCalls') {
        $self->_handle_incoming_calls($message);
    }
    elsif ($method eq 'callHierarchy/outgoingCalls') {
        $self->_handle_outgoing_calls($message);
    }
    elsif ($method eq 'textDocument/prepareTypeHierarchy') {
        $self->_handle_prepare_type_hierarchy($message);
    }
    elsif ($method eq 'typeHierarchy/supertypes') {
        $self->_handle_supertypes($message);
    }
    elsif ($method eq 'typeHierarchy/subtypes') {
        $self->_handle_subtypes($message);
    }
    elsif ($method eq 'textDocument/semanticTokens/full') {
        $self->_handle_semantic_tokens_full($message);
    }
    elsif ($method eq 'textDocument/semanticTokens/range') {
        $self->_handle_semantic_tokens_range($message);
    }
    elsif ($method eq 'shutdown') {
        $self->_handle_shutdown($message);
    }
    else {
        warn "Unknown method: $method";
    }
}

sub _handle_initialize {
    my ($self, $message) = @_;

    my $response = {
        jsonrpc => '2.0',
        id => $message->{id},
        result => {
            capabilities => {
                textDocumentSync => {
                    openClose => JSON::PP::true,
                    change => 2, # Incremental
                    save => JSON::PP::true,
                },
                completionProvider => {
                    triggerCharacters => ['.'],
                },
                hoverProvider => JSON::PP::true,
                definitionProvider => JSON::PP::true,
                referencesProvider => JSON::PP::true,
                documentSymbolProvider => JSON::PP::true,
                documentFormattingProvider => JSON::PP::true,
                documentRangeFormattingProvider => JSON::PP::true,
                signatureHelpProvider => {
                    triggerCharacters => ['(', ','],
                },
                renameProvider => JSON::PP::true,
                codeActionProvider => JSON::PP::true,
                foldingRangeProvider => JSON::PP::true,
                documentHighlightProvider => JSON::PP::true,
                codeLensProvider => JSON::PP::true,
                selectionRangeProvider => JSON::PP::true,
                workspaceSymbolProvider => JSON::PP::true,
                diagnosticProvider => {
                    interFileDependencies => JSON::PP::false,
                    workspaceDiagnostics => JSON::PP::false,
                },
                callHierarchyProvider => JSON::PP::true,
                typeHierarchyProvider => JSON::PP::true,
                semanticTokensProvider => {
                    legend => {
                        tokenTypes => \@YAPLSPD::SemanticTokens::TOKEN_TYPES,
                        tokenModifiers => \@YAPLSPD::SemanticTokens::TOKEN_MODIFIERS,
                    },
                    full => JSON::PP::true,
                    range => JSON::PP::true,
                },
            },
        },
    };

    $self->{protocol}->send_message($response);
}

sub _handle_did_close {
    my ($self, $message) = @_;
    my $uri = $message->{params}{textDocument}{uri};
    $self->{memory_manager}->remove_document($uri);
    delete $self->{documents}{$uri};
}

# Get document with memory management
sub _get_document {
    my ($self, $uri) = @_;
    
    # Try memory manager first
    my $doc = $self->{memory_manager}->get_document($uri);
    return $doc if $doc;
    
    # Fallback to direct hash (backward compatibility)
    return $self->{documents}{$uri};
}

sub _handle_completion {
    my ($self, $message) = @_;
    my $uri = $message->{params}{textDocument}{uri};
    my $position = $message->{params}{position};

    my $doc = $self->_get_document($uri) or return;
    my $completions = $self->{completion}->complete($doc, $position);

    my $response = {
        jsonrpc => '2.0',
        id => $message->{id},
        result => $completions
    };

    $self->{protocol}->send_message($response);
}

sub _handle_hover {
    my ($self, $message) = @_;
    my $uri = $message->{params}{textDocument}{uri};
    my $position = $message->{params}{position};

    my $doc = $self->_get_document($uri) or return;
    my $hover_info = $self->{hover}->get_hover_info($doc, $position);

    my $response = {
        jsonrpc => '2.0',
        id => $message->{id},
        result => $hover_info,
    };

    $self->{protocol}->send_message($response);
}

sub _handle_definition {
    my ($self, $message) = @_;
    my $uri = $message->{params}{textDocument}{uri};
    my $position = $message->{params}{position};

    my $doc = $self->_get_document($uri) or return;
    my $definition = $self->{definition}->find_definition($doc, $position);

    my $response = {
        jsonrpc => '2.0',
        id => $message->{id},
        result => $definition ? [$definition] : [],
    };

    $self->{protocol}->send_message($response);
}

sub _handle_references {
    my ($self, $message) = @_;
    my $uri = $message->{params}{textDocument}{uri};
    my $position = $message->{params}{position};
    my $context = $message->{params}{context} || {};

    my $doc = $self->_get_document($uri) or return;
    my $references = $self->{references}->find_references($doc, $position);

    # Update URI for each reference
    foreach my $ref (@$references) {
        $ref->{uri} = $uri;
    }

    my $response = {
        jsonrpc => '2.0',
        id => $message->{id},
        result => $references,
    };

    $self->{protocol}->send_message($response);
}

sub _handle_document_symbol {
    my ($self, $message) = @_;
    my $uri = $message->{params}{textDocument}{uri};

    my $doc = $self->_get_document($uri) or return;
    my $symbols = $self->{document_symbol}->get_document_symbols($doc);

    my $response = {
        jsonrpc => '2.0',
        id => $message->{id},
        result => $symbols,
    };

    $self->{protocol}->send_message($response);
}

sub _handle_formatting {
    my ($self, $message) = @_;
    my $uri = $message->{params}{textDocument}{uri};
    my $options = $message->{params}{options} || {};

    my $doc = $self->_get_document($uri) or return;
    my $edits = $self->{formatting}->format_document($doc);

    my $response = {
        jsonrpc => '2.0',
        id => $message->{id},
        result => $edits || [],
    };

    $self->{protocol}->send_message($response);
}

sub _handle_range_formatting {
    my ($self, $message) = @_;
    my $uri = $message->{params}{textDocument}{uri};
    my $range = $message->{params}{range};
    my $options = $message->{params}{options} || {};

    my $doc = $self->_get_document($uri) or return;
    my $edits = $self->{formatting}->format_range($doc, $range);

    my $response = {
        jsonrpc => '2.0',
        id => $message->{id},
        result => $edits || [],
    };

    $self->{protocol}->send_message($response);
}

sub _publish_diagnostics {
    my ($self, $uri) = @_; 
    
    my $doc = $self->_get_document($uri) or return;
    my $diagnostics = $self->{diagnostics}->analyze_document($doc);

    my $notification = {
        jsonrpc => '2.0',
        method => 'textDocument/publishDiagnostics',
        params => {
            uri => $uri,
            diagnostics => $diagnostics,
        },
    };

    $self->{protocol}->send_message($notification);
}

sub _handle_did_open {
    my ($self, $message) = @_;    
    my $uri = $message->{params}{textDocument}{uri};
    my $text = $message->{params}{textDocument}{text};
    my $version = $message->{params}{textDocument}{version} || 1;
    
    require YAPLSPD::Document;
    my $doc = YAPLSPD::Document->new(
        uri => $uri,
        text => $text,
        version => $version
    );
    
    # Store in both legacy hash and memory manager
    $self->{documents}{$uri} = $doc;
    $self->{memory_manager}->store_document($uri, $doc);
    
    # Publish diagnostics on open
    $self->_publish_diagnostics($uri);
}

sub _handle_did_change {
    my ($self, $message) = @_;
    my $uri = $message->{params}{textDocument}{uri};
    my $changes = $message->{params}{contentChanges};
    my $version = $message->{params}{textDocument}{version};

    my $doc = $self->_get_document($uri);
    if ($doc) {
        $doc->apply_changes($changes);
        $doc->version($version) if defined $version;
        
        # Track access via memory manager
        $self->{memory_manager}->get_document($uri);
        
        # Publish diagnostics on change
        $self->_publish_diagnostics($uri);
    }
}

sub _handle_did_save {
    my ($self, $message) = @_;
    my $uri = $message->{params}{textDocument}{uri};
    
    # Track access via memory manager
    $self->{memory_manager}->get_document($uri);
    
    # Publish diagnostics on save
    $self->_publish_diagnostics($uri);
}

sub _handle_signature_help {
    my ($self, $message) = @_;
    my $uri = $message->{params}{textDocument}{uri};
    my $position = $message->{params}{position};

    my $doc = $self->_get_document($uri) or return;
    my $signature_help = $self->{signature_help}->get_signature_help($doc, $position);

    my $response = {
        jsonrpc => '2.0',
        id => $message->{id},
        result => $signature_help,
    };

    $self->{protocol}->send_message($response);
}

sub _handle_rename {
    my ($self, $message) = @_;
    my $uri = $message->{params}{textDocument}{uri};
    my $position = $message->{params}{position};
    my $new_name = $message->{params}{newName};

    my $doc = $self->_get_document($uri) or return;
    my $workspace_edit = $self->{rename}->rename($doc, $position, $new_name);

    my $response = {
        jsonrpc => '2.0',
        id => $message->{id},
        result => $workspace_edit,
    };

    $self->{protocol}->send_message($response);
}

sub _handle_code_action {
    my ($self, $message) = @_;
    my $uri = $message->{params}{textDocument}{uri};
    my $range = $message->{params}{range};
    my $context = $message->{params}{context} || {};

    my $doc = $self->_get_document($uri) or return;
    my $actions = $self->{code_action}->get_code_actions($doc, $range, $context);

    my $response = {
        jsonrpc => '2.0',
        id => $message->{id},
        result => $actions || [],
    };

    $self->{protocol}->send_message($response);
}

sub _handle_folding_range {
    my ($self, $message) = @_;
    my $uri = $message->{params}{textDocument}{uri};

    my $doc = $self->_get_document($uri) or return;
    my $ranges = $self->{folding_range}->get_folding_ranges($doc);

    my $response = {
        jsonrpc => '2.0',
        id => $message->{id},
        result => $ranges || [],
    };

    $self->{protocol}->send_message($response);
}

sub _handle_document_highlight {
    my ($self, $message) = @_;
    my $uri = $message->{params}{textDocument}{uri};
    my $position = $message->{params}{position};

    my $doc = $self->_get_document($uri) or return;
    my $highlights = $self->{document_highlight}->get_highlights($doc, $position);

    my $response = {
        jsonrpc => '2.0',
        id => $message->{id},
        result => $highlights || [],
    };

    $self->{protocol}->send_message($response);
}

sub _handle_code_lens {
    my ($self, $message) = @_;
    my $uri = $message->{params}{textDocument}{uri};

    my $doc = $self->_get_document($uri) or return;
    my $lenses = $self->{code_lens}->get_code_lenses($doc);

    my $response = {
        jsonrpc => '2.0',
        id => $message->{id},
        result => $lenses || [],
    };

    $self->{protocol}->send_message($response);
}

sub _handle_selection_range {
    my ($self, $message) = @_;
    my $uri = $message->{params}{textDocument}{uri};
    my $positions = $message->{params}{positions} || [];

    my $doc = $self->_get_document($uri) or return;
    my $ranges = $self->{selection_range}->get_selection_ranges($doc, $positions);

    my $response = {
        jsonrpc => '2.0',
        id => $message->{id},
        result => $ranges || [],
    };

    $self->{protocol}->send_message($response);
}

sub _handle_workspace_symbol {
    my ($self, $message) = @_;
    my $query = $message->{params}{query} || '';

    my $symbols = $self->{workspace_symbol}->get_workspace_symbols($self->{documents}, $query);

    my $response = {
        jsonrpc => '2.0',
        id => $message->{id},
        result => $symbols || [],
    };

    $self->{protocol}->send_message($response);
}

sub _handle_did_change_configuration {
    my ($self, $message) = @_;
    # Configuration changes - can be used to update settings
    # For now, just acknowledge
    my $settings = $message->{params}{settings} || {};
    # Store settings if needed
    $self->{settings} = $settings;
}

sub _handle_did_change_watched_files {
    my ($self, $message) = @_;
    # Watched file changes
    my $changes = $message->{params}{changes} || [];
    foreach my $change (@$changes) {
        my $uri = $change->{uri};
        my $type = $change->{type}; # 1=Created, 2=Changed, 3=Deleted
        
        if ($type == 3) {
            # Deleted
            delete $self->{documents}{$uri};
        }
    }
}

sub _handle_shutdown {
    my ($self, $message) = @_;
    
    # Return null result as per LSP spec
    my $response = {
        jsonrpc => '2.0',
        id => $message->{id},
        result => undef,
    };
    
    $self->{protocol}->send_message($response);
}

sub _handle_prepare_call_hierarchy {
    my ($self, $message) = @_;
    my $uri = $message->{params}{textDocument}{uri};
    my $position = $message->{params}{position};

    my $doc = $self->_get_document($uri) or return;
    my $items = $self->{call_hierarchy}->prepare_call_hierarchy($doc, $position);

    my $response = {
        jsonrpc => '2.0',
        id => $message->{id},
        result => $items,
    };

    $self->{protocol}->send_message($response);
}

sub _handle_incoming_calls {
    my ($self, $message) = @_;
    my $item = $message->{params}{item};

    # Find the document for this item
    my $uri = $item->{uri};
    my $doc = $self->{documents}{$uri};
    
    if (!$doc) {
        my $response = {
            jsonrpc => '2.0',
            id => $message->{id},
            result => [],
        };
        $self->{protocol}->send_message($response);
        return;
    }
    
    my $calls = $self->{call_hierarchy}->incoming_calls($doc, $item);

    my $response = {
        jsonrpc => '2.0',
        id => $message->{id},
        result => $calls,
    };

    $self->{protocol}->send_message($response);
}

sub _handle_outgoing_calls {
    my ($self, $message) = @_;
    my $item = $message->{params}{item};

    # Find the document for this item
    my $uri = $item->{uri};
    my $doc = $self->{documents}{$uri};
    
    if (!$doc) {
        my $response = {
            jsonrpc => '2.0',
            id => $message->{id},
            result => [],
        };
        $self->{protocol}->send_message($response);
        return;
    }
    
    my $calls = $self->{call_hierarchy}->outgoing_calls($doc, $item);

    my $response = {
        jsonrpc => '2.0',
        id => $message->{id},
        result => $calls,
    };

    $self->{protocol}->send_message($response);
}

sub _handle_prepare_type_hierarchy {
    my ($self, $message) = @_;
    my $uri = $message->{params}{textDocument}{uri};
    my $position = $message->{params}{position};

    my $doc = $self->_get_document($uri) or return;
    my $items = $self->{type_hierarchy}->prepare_type_hierarchy($doc, $position);

    my $response = {
        jsonrpc => '2.0',
        id => $message->{id},
        result => $items,
    };

    $self->{protocol}->send_message($response);
}

sub _handle_supertypes {
    my ($self, $message) = @_;
    my $item = $message->{params}{item};

    # Find the document for this item
    my $uri = $item->{uri};
    my $doc = $self->{documents}{$uri};
    
    if (!$doc) {
        my $response = {
            jsonrpc => '2.0',
            id => $message->{id},
            result => [],
        };
        $self->{protocol}->send_message($response);
        return;
    }
    
    my $types = $self->{type_hierarchy}->supertypes($doc, $item);

    my $response = {
        jsonrpc => '2.0',
        id => $message->{id},
        result => $types,
    };

    $self->{protocol}->send_message($response);
}

sub _handle_subtypes {
    my ($self, $message) = @_;
    my $item = $message->{params}{item};

    # Find the document for this item
    my $uri = $item->{uri};
    my $doc = $self->{documents}{$uri};
    
    if (!$doc) {
        my $response = {
            jsonrpc => '2.0',
            id => $message->{id},
            result => [],
        };
        $self->{protocol}->send_message($response);
        return;
    }
    
    my $types = $self->{type_hierarchy}->subtypes($doc, $item);

    my $response = {
        jsonrpc => '2.0',
        id => $message->{id},
        result => $types,
    };

    $self->{protocol}->send_message($response);
}

sub _handle_semantic_tokens_full {
    my ($self, $message) = @_;
    my $uri = $message->{params}{textDocument}{uri};

    my $doc = $self->_get_document($uri) or return;
    my $tokens = $self->{semantic_tokens}->get_semantic_tokens_full($doc);

    my $response = {
        jsonrpc => '2.0',
        id => $message->{id},
        result => $tokens,
    };

    $self->{protocol}->send_message($response);
}

sub _handle_semantic_tokens_range {
    my ($self, $message) = @_;
    my $uri = $message->{params}{textDocument}{uri};
    my $range = $message->{params}{range};

    my $doc = $self->_get_document($uri) or return;
    my $tokens = $self->{semantic_tokens}->get_semantic_tokens_range($doc, $range);

    my $response = {
        jsonrpc => '2.0',
        id => $message->{id},
        result => $tokens,
    };

    $self->{protocol}->send_message($response);
}

1;