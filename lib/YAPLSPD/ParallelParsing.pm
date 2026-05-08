package YAPLSPD::ParallelParsing;
use strict;
use warnings;

# Parallel Parsing für große Projekte
# Pure Perl Implementierung - nutzt fork() wenn verfügbar,
# sonst sequentielles Parsing

my $CAN_FORK = 0;
eval {
    require POSIX;
    require IO::Pipe;
    $CAN_FORK = 1;
};

# Configuration
my $WORKER_COUNT = $ENV{YAPLSPD_WORKERS} || 4;
my $MIN_FILES_FOR_PARALLEL = 5;  # Minimum files to use parallel processing

sub new {
    my ($class, %args) = @_;
    my $self = bless {
        worker_count => $args{worker_count} || $WORKER_COUNT,
        use_fork => $args{use_fork} // $CAN_FORK,
        symbol_index => {},
        file_cache => {},
    }, $class;
    return $self;
}

# Scan workspace for Perl files
sub scan_workspace {
    my ($self, $root_path) = @_;
    
    return [] unless defined $root_path && -d $root_path;
    
    my @perl_files;
    
    # Common Perl file extensions
    my @extensions = qw(.pm .pl .t);
    
    # Use File::Find if available, otherwise simple recursion
    my $use_file_find = 0;
    eval {
        require File::Find;
        $use_file_find = 1;
    };
    
    if ($use_file_find) {
        File::Find::find({
            wanted => sub {
                return unless -f $_;
                my $file = $_;
                foreach my $ext (@extensions) {
                    if ($file =~ /\Q$ext\E$/) {
                        push @perl_files, $File::Find::name;
                        last;
                    }
                }
            },
            no_chdir => 1,
        }, $root_path);
    } else {
        # Simple recursive fallback
        @perl_files = $self->_simple_find($root_path, \@extensions);
    }
    
    return \@perl_files;
}

# Simple recursive file finder (fallback)
sub _simple_find {
    my ($self, $dir, $extensions) = @_;
    my @found;
    
    opendir(my $dh, $dir) or return @found;
    my @entries = readdir($dh);
    closedir($dh);
    
    foreach my $entry (@entries) {
        next if $entry eq '.' || $entry eq '..';
        next if $entry eq '.git';  # Skip git directory
        
        my $full_path = "$dir/$entry";
        
        if (-d $full_path) {
            push @found, $self->_simple_find($full_path, $extensions);
        } elsif (-f $full_path) {
            foreach my $ext (@$extensions) {
                if ($entry =~ /\Q$ext\E$/) {
                    push @found, $full_path;
                    last;
                }
            }
        }
    }
    
    return @found;
}

# Parse files and build symbol index
sub build_index {
    my ($self, $files, $progress_callback) = @_;
    
    $files ||= [];
    my $total = scalar @$files;
    
    # Use parallel processing only if beneficial
    my $use_parallel = $self->{use_fork} 
        && $CAN_FORK 
        && $total >= $MIN_FILES_FOR_PARALLEL;
    
    if ($use_parallel) {
        $self->_build_index_parallel($files, $progress_callback);
    } else {
        $self->_build_index_sequential($files, $progress_callback);
    }
    
    return $self->{symbol_index};
}

# Sequential parsing (fallback)
sub _build_index_sequential {
    my ($self, $files, $progress_callback) = @_;
    
    my $total = scalar @$files;
    my $count = 0;
    
    foreach my $file (@$files) {
        my $symbols = $self->_parse_file($file);
        $self->{symbol_index}{$file} = $symbols if $symbols;
        $count++;
        
        if ($progress_callback && $total > 0) {
            $progress_callback->($count, $total, $file);
        }
    }
}

# Parallel parsing using fork()
sub _build_index_parallel {
    my ($self, $files, $progress_callback) = @_;
    
    my $total = scalar @$files;
    my $worker_count = $self->{worker_count};
    $worker_count = $total if $total < $worker_count;
    
    # Split files into batches for workers
    my @batches = $self->_split_into_batches($files, $worker_count);
    
    my @pipes;
    my @pids;
    
    # Spawn workers
    for my $i (0 .. $#batches) {
        my $batch = $batches[$i];
        
        my $pipe = IO::Pipe->new();
        push @pipes, $pipe;
        
        my $pid = fork();
        
        if (!defined $pid) {
            # Fork failed - fall back to sequential for this batch
            my $symbols = $self->_parse_batch($batch);
            $self->{symbol_index}{$_} = $symbols->{$_} for keys %$symbols;
        } elsif ($pid == 0) {
            # Child process
            $pipe->writer();
            $pipe->autoflush(1);
            
            my $results = $self->_parse_batch($batch);
            
            # Serialize results
            require JSON::PP;
            my $json = JSON::PP::encode_json($results);
            print $pipe $json;
            close $pipe;
            
            exit(0);
        } else {
            # Parent process
            $pipe->reader();
            push @pids, $pid;
        }
    }
    
    # Collect results from children
    for my $i (0 .. $#pipes) {
        my $pipe = $pipes[$i];
        local $/;
        my $json = <$pipe>;
        close $pipe;
        
        if ($json) {
            require JSON::PP;
            my $results = eval { JSON::PP::decode_json($json) } || {};
            $self->{symbol_index}{$_} = $results->{$_} for keys %$results;
        }
        
        # Report progress
        if ($progress_callback) {
            my $done = $i + 1;
            $progress_callback->($done, scalar(@batches), "batch_$done");
        }
    }
    
    # Wait for all children
    foreach my $pid (@pids) {
        waitpid($pid, 0);
    }
}

# Split files into batches
sub _split_into_batches {
    my ($self, $files, $num_batches) = @_;
    
    my @batches;
    my $batch_size = int((scalar @$files + $num_batches - 1) / $num_batches);
    $batch_size = 1 if $batch_size < 1;
    
    for (my $i = 0; $i < @$files; $i += $batch_size) {
        my $end = $i + $batch_size - 1;
        $end = $#$files if $end > $#$files;
        push @batches, [@$files[$i .. $end]];
    }
    
    return @batches;
}

# Parse a batch of files
sub _parse_batch {
    my ($self, $files) = @_;
    my %results;
    
    foreach my $file (@$files) {
        my $symbols = $self->_parse_file($file);
        $results{$file} = $symbols if $symbols;
    }
    
    return \%results;
}

# Parse a single file and extract symbols
sub _parse_file {
    my ($self, $file) = @_;
    
    return undef unless -f $file && -r $file;
    
    # Skip very large files (> 1MB)
    my $size = -s $file;
    return undef if $size && $size > 1024 * 1024;
    
    open(my $fh, '<', $file) or return undef;
    local $/;
    my $content = <$fh>;
    close $fh;
    
    return undef unless defined $content;
    
    my @symbols;
    my $current_package = 'main';
    my @lines = split(/\n/, $content);
    
    for (my $i = 0; $i < @lines; $i++) {
        my $line = $lines[$i];
        
        # Package declarations
        if ($line =~ /^\s*package\s+([\w:]+)/) {
            my $name = $1;
            $current_package = $name;
            push @symbols, {
                type => 'package',
                name => $name,
                line => $i,
                container => undef,
            };
        }
        
        # Subroutines
        if ($line =~ /^\s*sub\s+(\w+)/) {
            my $name = $1;
            push @symbols, {
                type => 'subroutine',
                name => $name,
                full_name => "$current_package\::$name",
                line => $i,
                container => $current_package,
            };
        }
        
        # Constants (use constant)
        if ($line =~ /^\s*use\s+constant\s+(\w+)/) {
            push @symbols, {
                type => 'constant',
                name => $1,
                line => $i,
                container => $current_package,
            };
        }
    }
    
    return {
        symbols => \@symbols,
        package => $current_package,
        line_count => scalar(@lines),
    };
}

# Get symbol index
sub get_index {
    my ($self) = @_;
    return $self->{symbol_index};
}

# Clear index
sub clear_index {
    my ($self) = @_;
    $self->{symbol_index} = {};
    $self->{file_cache} = {};
}

# Update index for a single file (incremental)
sub update_file {
    my ($self, $file) = @_;
    
    my $symbols = $self->_parse_file($file);
    if ($symbols) {
        $self->{symbol_index}{$file} = $symbols;
    } else {
        delete $self->{symbol_index}{$file};
    }
    
    return $symbols;
}

# Remove file from index
sub remove_file {
    my ($self, $file) = @_;
    delete $self->{symbol_index}{$file};
}

# Search symbols across all indexed files
sub search_symbols {
    my ($self, $query) = @_;
    
    return [] unless defined $query;
    
    my $query_re = qr/\Q$query\E/i;
    my @matches;
    
    foreach my $file (keys %{$self->{symbol_index}}) {
        my $data = $self->{symbol_index}{$file};
        next unless $data && $data->{symbols};
        
        foreach my $sym (@{$data->{symbols}}) {
            if ($sym->{name} =~ /$query_re/ || 
                ($sym->{full_name} && $sym->{full_name} =~ /$query_re/)) {
                push @matches, {
                    %$sym,
                    file => $file,
                };
            }
        }
    }
    
    return \@matches;
}

# Get statistics about the index
sub get_stats {
    my ($self) = @_;
    
    my $total_files = scalar keys %{$self->{symbol_index}};
    my $total_symbols = 0;
    my %symbol_types;
    
    foreach my $file (keys %{$self->{symbol_index}}) {
        my $data = $self->{symbol_index}{$file};
        next unless $data && $data->{symbols};
        
        $total_symbols += scalar @{$data->{symbols}};
        
        foreach my $sym (@{$data->{symbols}}) {
            $symbol_types{$sym->{type}}++;
        }
    }
    
    return {
        total_files => $total_files,
        total_symbols => $total_symbols,
        symbol_types => \%symbol_types,
    };
}

1;

__END__

=head1 NAME

YAPLSPD::ParallelParsing - Parallel workspace parsing for large projects

=head1 DESCRIPTION

Parses Perl files in parallel using fork() to build a project-wide symbol index.
Falls back to sequential parsing when fork is unavailable or for small projects.

=head1 SYNOPSIS

    use YAPLSPD::ParallelParsing;
    
    my $parser = YAPLSPD::ParallelParsing->new(
        worker_count => 4,  # Number of parallel workers
    );
    
    # Scan workspace
    my $files = $parser->scan_workspace('/path/to/project');
    
    # Build index with progress callback
    $parser->build_index($files, sub {
        my ($done, $total, $current) = @_;
        print "Progress: $done/$total\n";
    });
    
    # Search symbols
    my $matches = $parser->search_symbols('MySub');

=cut
