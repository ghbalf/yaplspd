use strict;
use warnings;
use Test::More;
use FindBin qw($Bin);
use lib "$Bin/../lib";

use YAPLSPD::MemoryManager;
use YAPLSPD::Document;

# Test 1: MemoryManager creation
my $mm = YAPLSPD::MemoryManager->new();
ok($mm, 'MemoryManager created');
isa_ok($mm, 'YAPLSPD::MemoryManager');

# Test 2: Default configuration
is($mm->{max_documents}, 50, 'Default max_documents is 50');
is($mm->{max_memory_mb}, 512, 'Default max_memory_mb is 512');
is($mm->{ppi_timeout_sec}, 300, 'Default ppi_timeout_sec is 300');

# Test 3: Custom configuration
my $mm_custom = YAPLSPD::MemoryManager->new(
    max_documents => 10,
    max_memory_mb => 256,
    ppi_timeout_sec => 60,
);
is($mm_custom->{max_documents}, 10, 'Custom max_documents set');
is($mm_custom->{max_memory_mb}, 256, 'Custom max_memory_mb set');
is($mm_custom->{ppi_timeout_sec}, 60, 'Custom ppi_timeout_sec set');

# Test 4: Document storage
my $doc1 = YAPLSPD::Document->new(
    uri => 'file:///test1.pm',
    text => "package Test1;\nsub foo { 1 }",
    version => 1,
);
$mm->store_document('file:///test1.pm', $doc1);
is($mm->_document_count, 1, 'Document stored');
ok($mm->has_document('file:///test1.pm'), 'Document exists check');

# Test 5: Document retrieval
my $retrieved = $mm->get_document('file:///test1.pm');
is($retrieved, $doc1, 'Document retrieved');
is($mm->{stats}{hits}, 1, 'Hit counter incremented');

# Test 6: Non-existent document
my $missing = $mm->get_document('file:///nonexistent.pm');
is($missing, undef, 'Non-existent document returns undef');
is($mm->{stats}{misses}, 1, 'Miss counter incremented');

# Test 7: Multiple documents
my $doc2 = YAPLSPD::Document->new(uri => 'file:///test2.pm', text => 'package Test2;', version => 1);
my $doc3 = YAPLSPD::Document->new(uri => 'file:///test3.pm', text => 'package Test3;', version => 1);
$mm->store_document('file:///test2.pm', $doc2);
$mm->store_document('file:///test3.pm', $doc3);
is($mm->_document_count, 3, 'Multiple documents stored');

# Test 8: Document removal
$mm->remove_document('file:///test2.pm');
is($mm->_document_count, 2, 'Document removed');
ok(!$mm->has_document('file:///test2.pm'), 'Removed document not found');

# Test 9: LRU eviction with small limit
my $mm_lru = YAPLSPD::MemoryManager->new(max_documents => 3);
$mm_lru->store_document('file:///a.pm', $doc1);
$mm_lru->store_document('file:///b.pm', $doc2);
$mm_lru->store_document('file:///c.pm', $doc3);
is($mm_lru->_document_count, 3, '3 documents stored');

my $doc4 = YAPLSPD::Document->new(uri => 'file:///d.pm', text => 'package D;', version => 1);
$mm_lru->store_document('file:///d.pm', $doc4);
is($mm_lru->_document_count, 3, 'Still 3 documents (eviction occurred)');
is($mm_lru->{stats}{evictions}, 1, 'Eviction counter incremented');

# Oldest document should be evicted
ok(!$mm_lru->has_document('file:///a.pm'), 'Oldest document evicted');
ok($mm_lru->has_document('file:///d.pm'), 'Newest document present');

# Test 10: Access updates LRU order
$mm_lru->get_document('file:///b.pm');  # Access b, now it should be newest
my $doc5 = YAPLSPD::Document->new(uri => 'file:///e.pm', text => 'package E;', version => 1);
$mm_lru->store_document('file:///e.pm', $doc5);
# Now c should be evicted (oldest), not b
ok($mm_lru->has_document('file:///b.pm'), 'Recently accessed document kept');
ok(!$mm_lru->has_document('file:///c.pm'), 'Least recently used evicted');

# Test 11: Get all URIs
my @uris = $mm_lru->get_all_uris();
is(scalar @uris, 3, 'get_all_uris returns 3 URIs');

# Test 12: Stats
my $stats = $mm_lru->get_stats();
ok(exists $stats->{documents_in_memory}, 'Stats has documents_in_memory');
ok(exists $stats->{hit_rate}, 'Stats has hit_rate');
ok(exists $stats->{hits}, 'Stats has hits');
ok(exists $stats->{misses}, 'Stats has misses');
ok(exists $stats->{evictions}, 'Stats has evictions');
is($stats->{evictions}, 2, 'Stats shows correct eviction count');

# Test 13: Reset stats
$mm_lru->reset_stats();
$stats = $mm_lru->get_stats();
is($stats->{hits}, 0, 'Stats reset - hits');
is($stats->{misses}, 0, 'Stats reset - misses');
is($stats->{evictions}, 0, 'Stats reset - evictions');

# Test 14: Release inactive PPI (with negative timeout to force release)
my $mm_ppi = YAPLSPD::MemoryManager->new(ppi_timeout_sec => -1);
my $ppi_doc = YAPLSPD::Document->new(
    uri => 'file:///ppi.pm',
    text => "package PPI;\nsub test { 1 }",
    version => 1,
);
$mm_ppi->store_document('file:///ppi.pm', $ppi_doc);
$ppi_doc->ppi_document;  # Force PPI parsing
ok($ppi_doc->{ppi}, 'PPI document exists');

# Manually set last_access to old time to simulate inactivity
$mm_ppi->{documents}{'file:///ppi.pm'}{last_access} = time() - 10;

my $freed = $mm_ppi->release_inactive_ppi();
is($freed, 1, 'Inactive PPI freed');
is($mm_ppi->{stats}{ppi_frees}, 1, 'PPI free counter incremented');

# Test 15: GC run
my $gc_result = $mm_ppi->run_gc();
ok(exists $gc_result->{ppi_documents_freed}, 'GC result has ppi_documents_freed');
ok(exists $gc_result->{documents_in_memory}, 'GC result has documents_in_memory');
is($mm_ppi->{stats}{gc_runs}, 1, 'GC run counter incremented');

# Test 16: LRU list
my $mm_lru_list = YAPLSPD::MemoryManager->new();
$mm_lru_list->store_document('file:///x.pm', $doc1);
$mm_lru_list->store_document('file:///y.pm', $doc2);
my $lru = $mm_lru_list->get_lru_list(2);
is(scalar @$lru, 2, 'LRU list returns 2 items');
is($lru->[0]{uri}, 'file:///y.pm', 'Most recent first');
is($lru->[1]{uri}, 'file:///x.pm', 'Least recent second');
ok(exists $lru->[0]{access_count}, 'LRU entry has access_count');
ok(exists $lru->[0]{age_seconds}, 'LRU entry has age_seconds');

# Test 17: Environment variable configuration (keep last to avoid polluting other tests)
{
    local $ENV{YAPLSPD_MAX_DOCUMENTS} = 25;
    local $ENV{YAPLSPD_MAX_MEMORY_MB} = 128;
    local $ENV{YAPLSPD_PPI_TIMEOUT} = 120;
    local $ENV{YAPLSPD_GC_INTERVAL} = 30;
    my $mm_env = YAPLSPD::MemoryManager->new();
    is($mm_env->{max_documents}, 25, 'ENV max_documents');
    is($mm_env->{max_memory_mb}, 128, 'ENV max_memory_mb');
    is($mm_env->{ppi_timeout_sec}, 120, 'ENV ppi_timeout_sec');
    is($mm_env->{gc_interval}, 30, 'ENV gc_interval');
}

done_testing();
