package YAPLSPD::MemoryManager;
use strict;
use warnings;

# Memory optimization for long-running LSP sessions
# Features: LRU eviction, document limits, PPI cache management, memory stats

our $DEFAULT_MAX_DOCUMENTS = 50;      # Max documents in memory
our $DEFAULT_MAX_MEMORY_MB = 512;     # Soft memory limit
our $DEFAULT_PPI_TIMEOUT_SEC = 300;   # Free PPI after 5 min inactivity
our $DEFAULT_GC_INTERVAL = 60;        # GC every 60 seconds

sub new {
    my ($class, %args) = @_;
    my $self = bless {
        max_documents => $args{max_documents} || $ENV{YAPLSPD_MAX_DOCUMENTS} || $DEFAULT_MAX_DOCUMENTS,
        max_memory_mb => $args{max_memory_mb} || $ENV{YAPLSPD_MAX_MEMORY_MB} || $DEFAULT_MAX_MEMORY_MB,
        ppi_timeout_sec => $args{ppi_timeout_sec} || $ENV{YAPLSPD_PPI_TIMEOUT} || $DEFAULT_PPI_TIMEOUT_SEC,
        gc_interval => $args{gc_interval} || $ENV{YAPLSPD_GC_INTERVAL} || $DEFAULT_GC_INTERVAL,
        documents => {},      # uri => { doc, last_access, access_count }
        access_order => [],   # LRU queue: [uri, uri, ...]
        stats => {
            hits => 0,
            misses => 0,
            evictions => 0,
            ppi_frees => 0,
            gc_runs => 0,
        },
        last_gc => time(),
    }, $class;
    return $self;
}

# Get document (with LRU tracking)
sub get_document {
    my ($self, $uri) = @_;
    
    my $entry = $self->{documents}{$uri};
    unless ($entry) {
        $self->{stats}{misses}++;
        return undef;
    }
    
    # Update access time and move to front of LRU
    $entry->{last_access} = time();
    $entry->{access_count}++;
    $self->_update_lru($uri);
    
    $self->{stats}{hits}++;
    return $entry->{doc};
}

# Store document
sub store_document {
    my ($self, $uri, $doc) = @_;
    
    # Evict if at capacity
    $self->_evict_if_needed() if $self->_document_count >= $self->{max_documents};
    
    # Store new document
    $self->{documents}{$uri} = {
        doc => $doc,
        last_access => time(),
        access_count => 1,
        created_at => time(),
    };
    
    unshift @{$self->{access_order}}, $uri;
    $self->_trim_access_order();
    
    # Run GC if needed
    $self->_maybe_gc();
    
    return $doc;
}

# Remove document
sub remove_document {
    my ($self, $uri) = @_;
    
    my $entry = delete $self->{documents}{$uri};
    return undef unless $entry;
    
    # Remove from LRU
    $self->{access_order} = [grep { $_ ne $uri } @{$self->{access_order}}];
    
    return $entry->{doc};
}

# Check if document exists (without updating LRU)
sub has_document {
    my ($self, $uri) = @_;
    return exists $self->{documents}{$uri};
}

# Get all document URIs
sub get_all_uris {
    my ($self) = @_;
    return keys %{$self->{documents}};
}

# Release PPI documents for inactive files
sub release_inactive_ppi {
    my ($self, $max_age_sec) = @_;
    $max_age_sec ||= $self->{ppi_timeout_sec};
    
    my $now = time();
    my $freed = 0;
    
    foreach my $uri (keys %{$self->{documents}}) {
        my $entry = $self->{documents}{$uri};
        my $inactive_time = $now - $entry->{last_access};
        
        if ($inactive_time > $max_age_sec && $entry->{doc}) {
            # Free PPI document (can be re-parsed on demand)
            if ($entry->{doc}->{ppi}) {
                $entry->{doc}->{ppi} = undef;
                $freed++;
            }
        }
    }
    
    $self->{stats}{ppi_frees} += $freed;
    return $freed;
}

# Force garbage collection
sub run_gc {
    my ($self) = @_;
    
    $self->{stats}{gc_runs}++;
    $self->{last_gc} = time();
    
    # Release inactive PPI documents
    my $ppi_freed = $self->release_inactive_ppi();
    
    # On Perl < 5.38, try to force garbage collection
    my $freed_memory = 0;
    if ($] < 5.038) {
        # Old Perl - no explicit GC hook
        $freed_memory = 'unknown';
    }
    
    return {
        ppi_documents_freed => $ppi_freed,
        documents_in_memory => $self->_document_count,
        memory_freed => $freed_memory,
    };
}

# Get memory statistics
sub get_stats {
    my ($self) = @_;
    
    my $total = $self->{stats}{hits} + $self->{stats}{misses};
    my $hit_rate = $total > 0 ? sprintf("%.1f%%", ($self->{stats}{hits} / $total) * 100) : "N/A";
    
    return {
        documents_in_memory => $self->_document_count,
        max_documents => $self->{max_documents},
        hit_rate => $hit_rate,
        hits => $self->{stats}{hits},
        misses => $self->{stats}{misses},
        evictions => $self->{stats}{evictions},
        ppi_frees => $self->{stats}{ppi_frees},
        gc_runs => $self->{stats}{gc_runs},
        uptime_seconds => time() - ($self->{_start_time} || time()),
    };
}

# Reset statistics
sub reset_stats {
    my ($self) = @_;
    $self->{stats} = {
        hits => 0,
        misses => 0,
        evictions => 0,
        ppi_frees => 0,
        gc_runs => 0,
    };
}

# Internal: Document count
sub _document_count {
    my ($self) = @_;
    return scalar keys %{$self->{documents}};
}

# Internal: Update LRU position
sub _update_lru {
    my ($self, $uri) = @_;
    
    # Remove from current position
    $self->{access_order} = [grep { $_ ne $uri } @{$self->{access_order}}];
    
    # Add to front
    unshift @{$self->{access_order}}, $uri;
    $self->_trim_access_order();
}

# Internal: Trim access order to match document count
sub _trim_access_order {
    my ($self) = @_;
    my $count = $self->_document_count;
    if (@{$self->{access_order}} > $count) {
        $self->{access_order} = [@{$self->{access_order}}[0..$count-1]];
    }
}

# Internal: Evict oldest documents if over limit
sub _evict_if_needed {
    my ($self) = @_;
    
    while ($self->_document_count >= $self->{max_documents} && @{$self->{access_order}}) {
        # Get least recently used
        my $lru_uri = pop @{$self->{access_order}};
        next unless exists $self->{documents}{$lru_uri};
        
        # Remove document
        delete $self->{documents}{$lru_uri};
        $self->{stats}{evictions}++;
    }
}

# Internal: Maybe run GC
sub _maybe_gc {
    my ($self) = @_;
    
    my $time_since_gc = time() - $self->{last_gc};
    if ($time_since_gc >= $self->{gc_interval}) {
        $self->run_gc();
    }
}

# Get least recently used documents (for debugging)
sub get_lru_list {
    my ($self, $limit) = @_;
    $limit ||= 10;
    
    my @list;
    foreach my $uri (@{$self->{access_order}}) {
        last if @list >= $limit;
        my $entry = $self->{documents}{$uri};
        next unless $entry;
        
        push @list, {
            uri => $uri,
            last_access => $entry->{last_access},
            access_count => $entry->{access_count},
            age_seconds => time() - $entry->{last_access},
        };
    }
    
    return \@list;
}

1;
