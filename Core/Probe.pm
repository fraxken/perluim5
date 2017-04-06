package Perluim::Core::Probe;

use Nimbus::API;
use Nimbus::Session;
use Data::Dumper;
use Perluim::Core::Events;

sub new {
    my ($class,$argRef) = @_;
    my @Subscribtions = ();
    my $this = {
        name => $argRef->{name},
        version => defined $argRef->{version} ? $argRef->{version} : "1.0",
        description => defined $argRef->{description} ? $argRef->{description} : $argRef->{name},
        interval => defined $argRef->{interval} ? $argRef->{interval} : 120,
        timeout => defined $argRef->{timeout} ? $argRef->{timeout} : 5000,
        _sess => undef,
        callbacks => {},
        subscribtions => \@Subscribtions,
        Emitter => Perluim::Core::Events->new
    };
    return bless($this,ref($class) || $class);
}

sub emit {
    my ($self,$eventName,$data) = @_;
    $self->{Emitter}->emit($eventName,$data);
}

sub on {
    my ($self,$eventName,$callbackRef) = @_;
    $self->{Emitter}->on($eventName,$callbackRef);
}

sub start {
    my ($self) = @_;
    $self->{_sess} = Nimbus::Session->new($self->{name});
    $self->{_sess}->setInfo($self->{version}, $self->{description});
    $self->{_sess}->setRetryInterval($self->{interval});

    sub timeout {
        $self->emit('timeout');
    }

    sub restart {
        $self->emit('restart');
    }

    sub hubpost {
        $self->emit('hubpost',{
            hMsg => $hMsg,
            data => $udata,
            full => $full
        });
    }

    foreach my $subject (@{$self->{subscribtions}}) {
        if($self->{_sess}->subscribe($subject)) {
            $self->emit('log',"unable to subscribe to $subject\n");
        }
    }
    
    if ($self->{_sess}->server(NIMPORT_ANY,\&timeout,\&restart) == 0 ) {
        foreach my $cbName (keys %{ $self->{callbacks} }) {
            my $argFormat = $self->{callbacks}->{$cbName};
            $self->emit('log',"addCallback => $cbName with argFormat => $argFormat");
            nimSessionAddCallbackPds($self->{_sess}->{SERVER_SESS},$cbName,$argFormat,0);
        }
        $self->{_sess}->dispatch($self->{timeout});
    }
}

sub _argToString {
    my ($self,$argRef) = @_;
    my $str = "";
    my $i   = 0;
    foreach my $argName (keys %{$argRef}) {
        my $argVal = $argRef->{$argName};
        my $prefix = $i == 0 ? "" : ",";
        if($argVal eq "String") {
            $str.="${prefix}${argName}"
        }
        elsif($argVal eq "Int") {
            $str.="${prefix}${argName}%d"
        }
        $i++;
    }
    return $str;
}

sub subscribe {
    my ($self,$subject) = @_;
    push(@{$self->{subscribtions}},$subject);
}

sub registerCallback {
    my ($self,$cbName,$argRef) = @_;
    $self->{callbacks}->{$cbName} = $self->_argToString($argRef);
}

1;
