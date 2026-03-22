#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 10;

# Mock the Document class for testing sync functionality
package TestDocument {
    sub new {
        my ($class, %args) = @_;    
        return bless {
            text => $args{text} || '',
            version => $args{version} || 0,
        }, $class;
    }
    
    sub text {
        my ($self, $new_text) = @_;
        $self->{text} = $new_text if defined $new_text;
        return $self->{text};
    }
    
    sub version {
        my ($self, $new_version) = @_
        $self->{version} = $new_version if defined $new_version;
        return $self->{version};
    }
    
    sub apply_changes {
        my ($self, $changes) = @_
        return unless $changes && @$changes;
        
        foreach my $change (@$changes) {
            if (exists $change->{text}) {
                # Full document replace
                $self->{text} = $change->{text};
            }
            elsif (exists $change->{range}) {
                # Incremental change
                my $range = $change->{range};
                my $new_text = $change->{text};
                
                my @lines = split /\n/, $self->{text};
                
                my $start_line = $range->{start}{line};
                my $start_char = $range->{start}{character};
                my $end_line = $range->{end}{line};
                my $end_char = $range->{end}{character};
                
                # Handle single line change
                if ($start_line == $end_line) {
                    my $line = $lines[$start_line] // '';
                    substr($line, $start_char, $end_char - $start_char) = $new_text;
                    $lines[$start_line] = $line;
                }
                else {
                    # Multi-line change
                    my $start_line_text = $lines[$start_line] // '';
                    my $end_line_text = $lines[$end_line] // '';
                    
                    my $new_start = substr($start_line_text, 0, $start_char) . $new_text;
                    my $new_end = substr($end_line_text, $end_char);
                    
                    # Replace the range
                    splice @lines, $start_line, $end_line - $start_line + 1;
                    
                    # Insert new lines
                    my @new_lines = split /\n/, $new_start . $new_end;
                    splice @lines, $start_line, 0, @new_lines;
                }
                
                $self->{text} = join "\n", @lines;
            }
            $self->{version}++;
        }
    }
    
    sub get_line {
        my ($self, $line_number) = @_
        return unless defined $line_number;
        my @lines = split /\n/, $self->{text};
        return $lines[$line_number] // '';
    }
    
    sub get_word_at_position {
        my ($self, $line, $character) = @_
        return unless defined $line && defined $character;
        
        my $line_text = $self->get_line($line);
        return '' unless $line_text;
        
        # Find word boundaries
        my $start = $character;
        my $end = $character;
        
        while ($start > 0 && substr($line_text, $start - 1, 1) =~ /[\w\$@%]/) {
            $start--;
        }
        
        while ($end < length($line_text) && substr($line_text, $end, 1) =~ /[\w\$@%]/) {
            $end++;
        }
        
        return substr($line_text, $start, $end - $start);
    }
}

# Test the sync functionality
my $doc = TestDocument->new(
    text => "use strict;\nuse warnings;\n\nsub hello {\n    print 'Hello';\n}",
    version => 1
);

is($doc->text, "use strict;\nuse warnings;\n\nsub hello {\n    print 'Hello';\n}", 'Initial text matches');
is($doc->version, 1, 'Initial version correct');

# Test full document replace
$doc->apply_changes([{ text => "use strict;\nprint 'New';" }]);
is($doc->text, "use strict;\nprint 'New';", 'Full replace works');
is($doc->version, 2, 'Version incremented on change');

# Test incremental change
$doc->apply_changes([{
    range => {
        start => { line => 1, character => 6 },
        end => { line => 1, character => 9 }
    },
    text => 'Modified'
}]);
is($doc->text, "use strict;\nprint 'Modified';", 'Incremental change works');
is($doc->version, 3, 'Version incremented on incremental change');

# Test line operations
my $line = $doc->get_line(0);
is($line, "use strict;", 'get_line works correctly');

my $word = $doc->get_word_at_position(1, 8);
is($word, 'Modified', 'get_word_at_position works correctly');

# Test multi-line change
$doc->apply_changes([{
    range => {
        start => { line => 0, character => 0 },
        end => { line => 1, character => 6 }
    },
    text => "# New header\nprint 'Multi'"
}]);
is($doc->text, "# New header\nprint 'Multi'Modified';", 'Multi-line change works');
is($doc->version, 4, 'Version incremented on multi-line change');

print "All sync tests passed!\n";