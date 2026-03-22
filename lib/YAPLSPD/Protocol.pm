package YAPLSPD::Protocol;
use strict;
use warnings;
use JSON::PP;

sub new {
    my ($class) = @_;
    my $self = {
        json => JSON::PP->new()->utf8()->pretty(1),
        server => undef,
    };
    bless $self, $class;
    return $self;
}

sub set_server {
    my ($self, $server) = @_;
    $self->{server} = $server;
}

sub read_message {
    my ($self) = @_;
    
    # Read Content-Length header
    my $line = <STDIN>;
    return undef unless defined $line;
    
    chomp $line;
    if ($line =~ /Content-Length:\s*(\d+)/i) {
        my $length = $1;
        
        # Skip empty line
        <STDIN>;
        
        # Read message body
        my $buffer;
        read(STDIN, $buffer, $length);
        
        return $self->{json}->decode($buffer);
    }
    
    return undef;
}

sub send_message {
    my ($self, $message) = @_;
    
    my $json_str = $self->{json}->encode($message);
    my $length = length($json_str);
    
    print "Content-Length: $length\r\n\r\n";
    print $json_str;
    
    # Ensure output is flushed
    STDOUT->flush();
}

sub run {
    my ($self) = @_;
    
    while (1) {
        my $message = $self->read_message();
        last unless defined $message;
        
        # Handle exit notification
        if ($message->{method} && $message->{method} eq 'exit') {
            last;
        }
        
        # Pass to server for handling
        if ($self->{server}) {
            $self->{server}->handle_message($message);
        }
    }
}

1;