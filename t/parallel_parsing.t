#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use FindBin;
use lib "$FindBin::Bin/../lib";

use YAPLSPD::ParallelParsing;
use File::Temp qw(tempdir);
use File::Spec;

# Test 1: Module loads
my $parser = YAPLSPD::ParallelParsing->new();
ok($parser, 'ParallelParsing module loaded');
isa_ok($parser, 'YAPLSPD::ParallelParsing');

# Test 2: Create test workspace
my $test_dir = tempdir(CLEANUP => 1);
ok(-d $test_dir, 'Test directory created');

# Create test Perl files
my @test_files = (
    { name => 'Module1.pm', content => _make_module('Module1') },
    { name => 'Module2.pm', content => _make_module('Module2') },
    { name => 'script.pl', content => _make_script() },
    { name => 'test.t', content => _make_test() },
);

foreach my $tf (@test_files) {
    my $path = File::Spec->catfile($test_dir, $tf->{name});
    open(my $fh, '>', $path) or die "Cannot write $path: $!";
    print $fh $tf->{content};
    close $fh;
}

# Test 3: Scan workspace
my $files = $parser->scan_workspace($test_dir);
ok(ref($files) eq 'ARRAY', 'scan_workspace returns array ref');
is(scalar @$files, 4, 'Found 4 Perl files');

# Test 4: Build index
my $progress_calls = 0;
my $index = $parser->build_index($files, sub {
    my ($done, $total, $current) = @_;
    $progress_calls++;
    ok($done > 0, 'Progress callback: done > 0');
    ok($total > 0, 'Progress callback: total > 0');
});

ok($index, 'build_index returned index');
ok($progress_calls > 0, 'Progress callback was called');

# Test 5: Index contents
foreach my $file (@$files) {
    ok(exists $index->{$file}, "File '$file' is in index");
    ok(ref($index->{$file}) eq 'HASH', "Index entry for '$file' is hash ref");
    ok(exists $index->{$file}{symbols}, "Index entry has symbols");
    ok(exists $index->{$file}{line_count}, "Index entry has line_count");
}

# Test 6: Symbol types
my $module1_path = File::Spec->catfile($test_dir, 'Module1.pm');
my $module1_data = $index->{$module1_path};
my $symbols = $module1_data->{symbols};

my @packages = grep { $_->{type} eq 'package' } @$symbols;
my @subs = grep { $_->{type} eq 'subroutine' } @$symbols;

is(scalar @packages, 1, 'Module1.pm has 1 package');
is($packages[0]{name}, 'Module1', 'Package name is Module1');
is(scalar @subs, 2, 'Module1.pm has 2 subroutines');

# Test 7: Search symbols
my $search_results = $parser->search_symbols('new');
ok(ref($search_results) eq 'ARRAY', 'search_symbols returns array ref');
ok(scalar @$search_results >= 1, 'Found at least one match for "new"');

my @new_subs = grep { $_->{type} eq 'subroutine' && $_->{name} eq 'new' } @$search_results;
is(scalar @new_subs, 2, 'Found 2 "new" subroutines (one per module)');

# Test 8: Search with no results
my $no_results = $parser->search_symbols('XYZ_NonExistent_12345');
is(ref($no_results), 'ARRAY', 'search_symbols returns array even with no matches');
is(scalar @$no_results, 0, 'No matches for non-existent symbol');

# Test 9: Stats
my $stats = $parser->get_stats();
ok(ref($stats) eq 'HASH', 'get_stats returns hash ref');
ok(exists $stats->{total_files}, 'Stats has total_files');
ok(exists $stats->{total_symbols}, 'Stats has total_symbols');
ok(exists $stats->{symbol_types}, 'Stats has symbol_types');
is($stats->{total_files}, 4, 'Stats: total_files = 4');
ok($stats->{total_symbols} > 0, 'Stats: total_symbols > 0');

# Test 10: Update single file
my $updated_path = File::Spec->catfile($test_dir, 'Module1.pm');
open(my $ufh, '>>', $updated_path) or die "Cannot append to $updated_path: $!";
print $ufh "\nsub extra_sub { }\n";
close $ufh;

my $updated = $parser->update_file($updated_path);
ok($updated, 'update_file returned data');

# Re-check stats after update
my $new_stats = $parser->get_stats();
ok($new_stats->{total_files} >= 4, 'Stats after update still has files');

# Test 11: Remove file from index
$parser->remove_file($updated_path);
ok(!exists $parser->get_index->{$updated_path}, 'File removed from index');

# Test 12: Clear index
$parser->clear_index();
my $cleared_index = $parser->get_index();
is(scalar keys %$cleared_index, 0, 'Index cleared');

# Test 13: Empty directory
my $empty_dir = tempdir(CLEANUP => 1);
my $empty_files = $parser->scan_workspace($empty_dir);
is(scalar @$empty_files, 0, 'Empty directory returns empty list');

# Test 14: Non-existent directory
my $no_files = $parser->scan_workspace('/non/existent/path/xyz');
is(ref($no_files), 'ARRAY', 'Non-existent dir returns array ref');
is(scalar @$no_files, 0, 'Non-existent dir returns empty list');

# Test 15: Sequential fallback (force by using 1 worker)
my $seq_parser = YAPLSPD::ParallelParsing->new(worker_count => 1);
my $seq_index = $seq_parser->build_index($files);
ok($seq_index, 'Sequential parsing works');
is(scalar keys %$seq_index, 4, 'Sequential parsing indexed all 4 files');

# Helper functions
sub _make_module {
    my ($name) = @_;
    return <<"PERL";
package $name;
use strict;
use warnings;

sub new {
    my (\$class) = @_;
    return bless {}, \$class;
}

sub do_something {
    my (\$self) = @_;
    return 42;
}

1;
PERL
}

sub _make_script {
    return <<'PERL';
#!/usr/bin/env perl
use strict;
use warnings;

use Module1;

my \$obj = Module1->new();
print \$obj->do_something(), "\n";
PERL
}

sub _make_test {
    return <<'PERL';
#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use_ok('Module1');

my \$obj = Module1->new();
ok(\$obj, 'Object created');

is(\$obj->do_something(), 42, 'do_something returns 42');

done_testing();
PERL
}

done_testing();
