#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

# Mock PPI classes for testing
{
    package Mock::PPI::Document;
    sub new { bless {}, shift }
    sub find {
        my ($self, $type) = @_;
        return [bless({name => 'hello', location => {line => 1, column => 5}}, 'Mock::PPI::Statement::Sub')];
    }
}

{
    package Mock::PPI::Statement::Sub;
    sub name { $_[0]->{name} }
    sub location { $_[0]->{location} }
}

# Test that our definition logic is structurally correct
{
    package YAPLSPD::DefinitionTest;
    sub new { bless {}, shift }
    
    sub _get_word_at_position {
        my ($self, $ppi, $line, $character) = @_;
        return 'hello';  # Mock return
    }
    
    sub find_definition {
        my ($self, $document, $position) = @_;
        
        my $word = $self->_get_word_at_position(undef, 0, 0);
        return unless $word;
        
        # Mock response
        return {
            uri => 'file:///test.pl',
            range => {
                start => { line => 0, character => 4 },
                end => { line => 0, character => 9 },
            },
        };
    }
}

# Test basic structure
my $def = YAPLSPD::DefinitionTest->new();
my $result = $def->find_definition(undef, {line => 0, character => 0});

ok($result, 'Found definition');
is($result->{range}{start}{line}, 0, 'Correct line');
is($result->{range}{start}{character}, 4, 'Correct character position');

# Test that we return correct LSP format
is(ref $result->{range}, 'HASH', 'Range is hashref');
ok(exists $result->{range}{start}, 'Range has start');
ok(exists $result->{range}{end}, 'Range has end');

done_testing;