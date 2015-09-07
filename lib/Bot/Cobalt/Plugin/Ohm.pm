package Bot::Cobalt::Plugin::Ohm;

# A simple Ohm's law calculator borrowed from SYMKAT:
# https://gist.github.com/symkat/da287f0993e708b53701

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

# The rest of this is pulled directly from SYMKAT's irssi script mentioned
# in the header of this file:

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
    $values{a} = 
        $values{v} && $values{o} ? $values{v} / $values{o}
      : $values{w} && $values{v} ? $values{w} / $values{v}
      : $values{w} && $values{o} ? sqrt( $values{w} / $values{o} )
      : undef
    ;
    return '' unless defined $values{a}
  }
  # W = ( V * V ) / O
  # W = ( A * A ) * O
  # W = V * R
  if ( ! $values{w} ) {
    $values{w} =
        $values{v} && $values{o} ? ($values{v} ** 2) / $values{o}
      : $values{a} && $values{o} ? ($values{a} ** 2) * $values{o}
      : $values{v} && $values{a} ? $values{v} * $values{a}
      : undef
    ;
    return '' unless defined $values{w}
  }
  # O = V / A
  # O = ( V * V ) * W
  # O = W / ( A * A )
  if ( ! $values{o} ) {
    $values{o} =
        $values{v} && $values{a} ? $values{v} / $values{a}
      : $values{v} && $values{w} ? ($values{v} ** 2) * $values{w}
      : $values{w} && $values{a} ? $values{w} / ($values{a} ** 2)
      : undef
    ;
    return '' unless defined $values{o}
  }
  # V = sqrt( W * O )
  # V = W / A
  # V = A * O
  if ( ! $values{v} ) {
    $values{v} =
        $values{w} && $values{o} ? sqrt( $values{w} * $values{o} )
      : $values{w} && $values{a} ? $values{w} / $values{a}
      : $values{a} && $values{o} ? $values{a} * $values{o}
      : undef
    ;
    return '' unless defined $values{v}
  }

  sprintf 
    "%.2fw/%.2fv @ %.2famps against %.2fohm" =>
      map {; $values{$_} } qw/ w v a o/
}

1;

=pod

=head1 NAME

Bot::Cobalt::Plugin::Ohm - Simple Ohm's law calculator

=head1 SYNOPSIS

  # What's my voltage and amperage firing my 0.87 Ohm coil at 25W?
  !ohm 0.87o 25w

=head1 DESCRIPTION

A simple Ohm's law calculator; given a string specifying parameters in the
form of C<< <N>a <N>o <N>w <N>v >>, attempts to fill in the blanks.

=head1 AUTHOR

Kaitlyn Parkhurst (CPAN: C<SYMKAT>) wrote the calculator as an irssi script.

Adapted (with permission) to L<Bot::Cobalt> by Jon Portnoy <avenj@cobaltirc.org>

=cut
