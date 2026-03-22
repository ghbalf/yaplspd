#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use lib 'lib';

use YAPLSPD::Document;
use YAPLSPD::DocumentSymbol;

# Test-Dokument mit verschiedenen Symbolen
my $perl_code = <<'PERL';
package My::Test::Module;

use strict;
use warnings;

our $VERSION = '0.01';

sub new {
    my ($class, %args) = @_;
    return bless \%args, $class;
}

sub hello_world {
    my ($self) = @_;
    my $message = "Hello, World!";
    return $message;
}

sub _private_method {
    my ($self) = @_;
    return "private";
}

1;
PERL

my $document = YAPLSPD::Document->new(text => $perl_code);
my $symbol_provider = YAPLSPD::DocumentSymbol->new($document);
my $symbols = $symbol_provider->get_document_symbols;

# Debug-Ausgabe
note "Gefundene Symbole:";
foreach my $symbol (@$symbols) {
    note sprintf("  - %s (%s) at line %d", 
                 $symbol->{name}, 
                 $symbol->{kind}, 
                 $symbol->{range}{start}{line} + 1);
}

# Teste dass wir Symbole gefunden haben
ok(scalar(@$symbols) > 0, 'Es wurden Symbole gefunden');

# Teste Package-Symbol
my ($package) = grep { $_->{kind} == 2 } @$symbols; # 2 = MODULE per LSP spec
ok($package, 'Package-Symbol gefunden');
is($package->{name}, 'My::Test::Module', 'Package-Name korrekt');

# Teste Subroutine-Symbole
my @subs = grep { $_->{kind} == 12 } @$symbols; # 12 = FUNCTION
is(scalar(@subs), 3, 'Alle 3 Subroutinen gefunden');

my %sub_names = map { $_->{name} => 1 } @subs;
ok($sub_names{new}, 'new()-Methode gefunden');
ok($sub_names{hello_world}, 'hello_world()-Methode gefunden');
ok($sub_names{_private_method}, '_private_method()-Methode gefunden');

# Teste dass die Reihenfolge korrekt ist (nach Zeilennummer sortiert)
is($subs[0]->{name}, 'new', 'Erste Subroutine ist new()');
is($subs[1]->{name}, 'hello_world', 'Zweite Subroutine ist hello_world()');
is($subs[2]->{name}, '_private_method', 'Dritte Subroutine ist _private_method()');

done_testing;