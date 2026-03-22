package YAPLSPD::CodeLens;
use strict;
use warnings;

sub new {
    my ($class) = @_;
    bless {}, $class;
}

sub get_code_lenses {
    my ($self, $document) = @_;
    
    my @lenses;
    my $text = $document->text;
    my @lines = split(/\n/, $text);
    
    # Track package context
    my $current_package = 'main';
    
    for (my $i = 0; $i < @lines; $i++) {
        my $line = $lines[$i];
        
        # Update package context
        if ($line =~ /^\s*package\s+(\w+(?:::\w+)*)/) {
            $current_package = $1;
        }
        
        # Find subroutines
        if ($line =~ /^\s*sub\s+(\w+)/) {
            my $sub_name = $1;
            my $full_name = "${current_package}::$sub_name";
            
            # Count references to this subroutine
            my $ref_count = $self->_count_references($text, $sub_name);
            
            # Add CodeLens for reference count
            push @lenses, {
                range => {
                    start => { line => $i, character => 0 },
                    end => { line => $i, character => length($line) },
                },
                command => {
                    title => $ref_count == 1 ? "1 reference" : "$ref_count references",
                    command => 'perl.showReferences',
                    arguments => [$document->uri, { line => $i, character => 0 }, $full_name],
                },
            };
            
            # Add "Run Test" lens if it looks like a test sub
            if ($sub_name =~ /^(test_|check_|verify_)/i) {
                push @lenses, {
                    range => {
                        start => { line => $i, character => 0 },
                        end => { line => $i, character => length($line) },
                    },
                    command => {
                        title => "▶ Run Test",
                        command => 'perl.runTest',
                        arguments => [$document->uri, $sub_name],
                    },
                };
            }
        }
        
        # Find TODO/FIXME comments
        if ($line =~ /#\s*(TODO|FIXME|XXX|HACK)/i) {
            my $tag = uc($1);
            push @lenses, {
                range => {
                    start => { line => $i, character => 0 },
                    end => { line => $i, character => length($line) },
                },
                command => {
                    title => "⚠ $tag",
                    command => 'perl.showTodo',
                    arguments => [$document->uri, $i],
                },
            };
        }
        
        # Find use statements with outdated modules (heuristic)
        if ($line =~ /^\s*use\s+(\w+(?:::\w+)*)\s+([^;]*);/) {
            my $module = $1;
            my $version = $2;
            
            # Check if there's no version specified
            if ($module =~ /^(Moose|Moo|DBI|LWP|Dancer|Catalyst|Mojolicious)$/ && $version !~ /\d/) {
                push @lenses, {
                    range => {
                        start => { line => $i, character => 0 },
                        end => { line => $i, character => length($line) },
                    },
                    command => {
                        title => "Add version check",
                        command => 'perl.addVersionCheck',
                        arguments => [$document->uri, $i, $module],
                    },
                };
            }
        }
    }
    
    return \@lenses;
}

sub _count_references {
    my ($self, $text, $sub_name) = @_;
    
    my $count = 0;
    my $escaped = quotemeta($sub_name);
    
    # Count subroutine calls (excluding definition)
    while ($text =~ /\b$escaped\s*(?:\(|\s+\w|;)/g) {
        $count++;
    }
    
    # Count method calls
    pos($text) = 0;
    while ($text =~ /->\s*$escaped\b/g) {
        $count++;
    }
    
    return $count;
}

1;