package LSP::Types;

use strict;
use warnings;
use base 'Exporter';

our @EXPORT = qw(
    SymbolKind
);
our @EXPORT_OK = qw(
    FILE MODULE NAMESPACE PACKAGE CLASS METHOD PROPERTY FIELD
    CONSTRUCTOR ENUM INTERFACE FUNCTION VARIABLE CONSTANT
    STRING NUMBER BOOLEAN ARRAY OBJECT KEY NULL ENUM_MEMBER
    STRUCT EVENT OPERATOR TYPE_PARAMETER
);
our %EXPORT_TAGS = (
    all => [@EXPORT, @EXPORT_OK],
);

# LSP SymbolKind enumeration
# https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#symbolKind
use constant FILE          => 1;
use constant MODULE        => 2;
use constant NAMESPACE     => 3;
use constant PACKAGE       => 4;
use constant CLASS         => 5;
use constant METHOD        => 6;
use constant PROPERTY      => 7;
use constant FIELD         => 8;
use constant CONSTRUCTOR   => 9;
use constant ENUM          => 10;
use constant INTERFACE     => 11;
use constant FUNCTION      => 12;
use constant VARIABLE      => 13;
use constant CONSTANT      => 14;
use constant STRING        => 15;
use constant NUMBER        => 16;
use constant BOOLEAN       => 17;
use constant ARRAY         => 18;
use constant OBJECT        => 19;
use constant KEY           => 20;
use constant NULL          => 21;
use constant ENUM_MEMBER   => 22;
use constant STRUCT        => 23;
use constant EVENT         => 24;
use constant OPERATOR      => 25;
use constant TYPE_PARAMETER => 26;

# Backward compatibility - export a hash ref
use constant SymbolKind => {
    FILE          => FILE(),
    MODULE        => MODULE(),
    NAMESPACE     => NAMESPACE(),
    PACKAGE       => PACKAGE(),
    CLASS         => CLASS(),
    METHOD        => METHOD(),
    PROPERTY      => PROPERTY(),
    FIELD         => FIELD(),
    CONSTRUCTOR   => CONSTRUCTOR(),
    ENUM          => ENUM(),
    INTERFACE     => INTERFACE(),
    FUNCTION      => FUNCTION(),
    VARIABLE      => VARIABLE(),
    CONSTANT      => CONSTANT(),
    STRING        => STRING(),
    NUMBER        => NUMBER(),
    BOOLEAN       => BOOLEAN(),
    ARRAY         => ARRAY(),
    OBJECT        => OBJECT(),
    KEY           => KEY(),
    NULL          => NULL(),
    ENUM_MEMBER   => ENUM_MEMBER(),
    STRUCT        => STRUCT(),
    EVENT         => EVENT(),
    OPERATOR      => OPERATOR(),
    TYPE_PARAMETER => TYPE_PARAMETER(),
};

1;

__END__

=head1 NAME

LSP::Types - Type constants for Language Server Protocol

=head1 SYNOPSIS

  use LSP::Types qw(:all);
  
  my $kind = FUNCTION;  # 12
  my $module = MODULE;  # 2

=head1 DESCRIPTION

Minimal implementation of LSP type constants for yaplspd.
Exports both individual constants (FUNCTION, MODULE, etc.) and 
a SymbolKind hashref for backward compatibility.

=cut
