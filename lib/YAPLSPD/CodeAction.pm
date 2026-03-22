package YAPLSPD::CodeAction;
use strict;
use warnings;

sub new {
    my ($class) = @_;
    bless {}, $class;
}

sub get_code_actions {
    my ($self, $document, $range, $context) = @_;
    
    my @actions;
    my $diagnostics = $context->{diagnostics} || [];
    
    # Get selected text
    my $selected_text = $self->_get_selected_text($document, $range);
    
    # Add actions based on diagnostics (quick fixes)
    foreach my $diag (@$diagnostics) {
        my $fix_actions = $self->_get_fix_for_diagnostic($document, $diag);
        push @actions, @$fix_actions if $fix_actions;
    }
    
    # Add general refactoring actions
    push @actions, $self->_get_refactor_actions($document, $range, $selected_text);
    
    # Add source actions
    push @actions, $self->_get_source_actions($document, $range);
    
    return \@actions;
}

sub _get_selected_text {
    my ($self, $document, $range) = @_;
    
    my $start_line = $range->{start}{line};
    my $start_char = $range->{start}{character};
    my $end_line = $range->{end}{line};
    my $end_char = $range->{end}{character};
    
    my @lines = @{$document->lines};
    
    if ($start_line == $end_line) {
        my $line = $lines[$start_line] // '';
        return substr($line, $start_char, $end_char - $start_char);
    }
    
    # Multi-line selection
    my @selected;
    for (my $i = $start_line; $i <= $end_line; $i++) {
        my $line = $lines[$i] // '';
        if ($i == $start_line) {
            push @selected, substr($line, $start_char);
        }
        elsif ($i == $end_line) {
            push @selected, substr($line, 0, $end_char);
        }
        else {
            push @selected, $line;
        }
    }
    return join("\n", @selected);
}

sub _get_fix_for_diagnostic {
    my ($self, $document, $diag) = @_;
    
    my @actions;
    my $message = $diag->{message} // '';
    my $range = $diag->{range};
    
    # Common Perl diagnostics and fixes
    if ($message =~ /syntax error/i) {
        # Can't auto-fix syntax errors
    }
    elsif ($message =~ /Global symbol.*requires explicit package name/) {
        # Add 'my' declaration
        my $line = $range->{start}{line};
        my $char = $range->{start}{character};
        my $word = $document->get_word_at_position($line, $char);
        
        if ($word && $word =~ /^[\$@%]/) {
            push @actions, {
                title => "Add 'my' declaration",
                kind => 'quickfix',
                diagnostics => [$diag],
                edit => {
                    changes => {
                        $document->uri => [
                            {
                                range => {
                                    start => { line => $line, character => $char },
                                    end => { line => $line, character => $char },
                                },
                                newText => 'my ',
                            },
                        ],
                    },
                },
            };
        }
    }
    elsif ($message =~ /Use of uninitialized value/) {
        # Suggest adding defined check
        push @actions, {
            title => "Add defined check",
            kind => 'quickfix',
            diagnostics => [$diag],
            edit => {
                changes => {
                    $document->uri => [
                        {
                            range => $range,
                            newText => 'defined(' . $self->_get_selected_text($document, $range) . ')',
                        },
                    ],
                },
            },
        };
    }
    
    return \@actions;
}

sub _get_refactor_actions {
    my ($self, $document, $range, $selected_text) = @_;
    
    my @actions;
    
    # Extract subroutine
    if ($selected_text =~ /\n/ || length($selected_text) > 50) {
        push @actions, {
            title => "Extract subroutine",
            kind => 'refactor.extract',
            command => {
                title => "Extract subroutine",
                command => 'perl.extractSubroutine',
                arguments => [$document->uri, $range],
            },
        };
    }
    
    # Extract variable
    if ($selected_text =~ /^[\$@%]/ || $selected_text =~ /^['"]/ || $selected_text =~ /^\d/) {
        push @actions, {
            title => "Extract variable",
            kind => 'refactor.extract',
            command => {
                title => "Extract variable",
                command => 'perl.extractVariable',
                arguments => [$document->uri, $range],
            },
        };
    }
    
    # Inline variable (if single variable is selected)
    if ($selected_text =~ /^[\$@%]\w+$/) {
        push @actions, {
            title => "Inline variable",
            kind => 'refactor.inline',
            command => {
                title => "Inline variable",
                command => 'perl.inlineVariable',
                arguments => [$document->uri, $range],
            },
        };
    }
    
    return @actions;
}

sub _get_source_actions {
    my ($self, $document, $range) = @_;
    
    my @actions;
    
    # Add 'use strict' and 'use warnings'
    push @actions, {
        title => "Add 'use strict' and 'use warnings'",
        kind => 'source',
        edit => {
            changes => {
                $document->uri => [
                    {
                        range => {
                            start => { line => 0, character => 0 },
                            end => { line => 0, character => 0 },
                        },
                        newText => "use strict;\nuse warnings;\n\n",
                    },
                ],
            },
        },
    };
    
    # Sort imports
    my $text = $document->text;
    if ($text =~ /\buse\s+\w+/m) {
        push @actions, {
            title => "Sort imports",
            kind => 'source.organizeImports',
            command => {
                title => "Sort imports",
                command => 'perl.sortImports',
                arguments => [$document->uri],
            },
        };
    }
    
    return @actions;
}

1;