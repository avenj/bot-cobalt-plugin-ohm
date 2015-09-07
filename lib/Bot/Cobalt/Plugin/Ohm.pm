package Bot::Cobalt::Plugin::Ohm;

use strictures 2;

use Bot::Cobalt;
use Bot::Cobalt::Common;

use Object::Pluggable::Constants 'PLUGIN_EAT_NONE';

sub new { bless [], shift }

sub Cobalt_register {
  my ($self, $core) = splice @_, 0, 2;

  my @events = map { 'public_cmd_'.$_ } 
    qw/ ohm watt amp volt / ;

  register $self, SERVER => [ @events ];

  $core->log->info("Loaded Ohm");

  PLUGIN_EAT_NONE
}

sub Cobalt_unregister {
  my ($self, $core) = splice @_, 0, 2;
  $core->log->info("Unloaded Ohm");
  PLUGIN_EAT_NONE
}

for (qw/watt amp volt/) {
  no strict 'refs';
  my $meth = 'Bot_public_cmd_'.$_;
  *{__PACKAGE__.'::'.$meth} = *Bot_public_cmd_ohm
}

sub Bot_public_cmd_ohm {
  my ($self, $core) = splice @_, 0, 2;
  my $msg = ${ $_[0] };

  my $context  = $msg->context;
  my $src_nick = $msg->src_nick;
  
  my $str = join '', @{ $msg->message_array };
  my %parsed = $self->_parse_values($str);

  my $resp;
  RESP: {
    unless (keys %parsed) {
      # FIXME better errors
      $resp = "Parser failure; malformed input";
      last RESP
    }

    $resp = $self->_calc(%parsed);

    unless (length $resp) {
      $resp = "Calc failure; malformed input from parser";
      last RESP
    }
  } # RESP

  broadcast message => $context, $msg->channel, "${src_nick}: $resp";
  
  PLUGIN_EAT_NONE
}

sub _parse_values {
  my ($self, $message) = @_;
  my %values = ();

  if ( $message =~ /(\d+(?:\.\d+)?)o/ ) {
    $values{o} = $1;
  } 
  if ( $message =~ /(\d+(?:\.\d+)?)w/ ) {
    $values{w} = $1;
  } 
  if ( $message =~ /(\d+(?:\.\d+)?)a/ ) {
    $values{a} = $1;
  } 
  if ( $message =~ /(\d+(?:\.\d+)?)v/ ) {
    $values{v} = $1;
  } 

  %values
}

sub _calc {
  my ($self, %values) = @_;
  #  A = V / O
  #  A = W / V
  #  A = sqrt(W / O)
  if ( ! $values{a} ) {
    if ( $values{v} && $values{o} ) {
      $values{a} = ( $values{v} / $values{o} );
    } elsif ( $values{w} && $values{v} ) {
      $values{a} = ( $values{w} / $values{v} );
    } elsif ( $values{w} && $values{o} ) {
      $values{a} = sqrt( ( $values{w} / $values{o} ) );
    } else {
      return ""
    }
  }
  # W = ( V * V ) / O
  # W = ( A * A ) * O
  # W = V * R
  if ( ! $values{w} ) {
    if ( $values{v} && $values{o} ) {
      $values{w} = ( ( $values{v} * $values{v} ) / $values{o} );
    } elsif ( $values{a} && $values{o} ) {
      $values{w} = ( ( $values{a} * $values{a} ) * $values{o} );
    } elsif ( $values{v} && $values{a} ) {
      $values{w} = ( $values{v} * $values{a} );
    } else {
      return ""
    }
  }
  # O = V / A
  # O = ( V * V ) * W
  # O = W / ( A * A )
  if ( ! $values{o} ) {
    if ( $values{v} && $values{a} ) {
      $values{o} = ( $values{v} / $values{a} );
    } elsif ( $values{v} && $values{w} ) {
      $values{o} = ( ( $values{v} * $values{v} ) * $values{w} );
    } elsif ( $values{w} && $values{a} ) {
      $values{o} = ( $values{w} / ( $values{a} * $values{a} ) );
    } else {
      return ""
    }
  }
  # V = sqrt( W * O )
  # V = W / A
  # V = A * O
  if ( ! $values{v} ) {
    if ( $values{w} && $values{o} ) {
      $values{v} = sqrt( $values{w} * $values{o} );
    } elsif ( $values{w} && $values{a} ) {
      $values{v} = ( $values{w} / $values{a} );
    } elsif ( $values{a} && $values{o} ) {
      $values{v} = ( $values{a} * $values{o} );
    } else {
       return ""
    }
  }

  sprintf 
    "%.2fw/%.2fv @ %.2famps against %.2fohm" =>
      map {; $values{$_} } qw/ w v a o/
}

1;

=pod

=cut
