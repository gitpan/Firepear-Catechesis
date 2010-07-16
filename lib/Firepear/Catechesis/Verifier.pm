package Firepear::Catechesis::Verifier;

use warnings;
use strict;

use JSON;
use Firepear::Catechesis::Util;

=head1 NAME

Firepear::Catechesis::Verifier - See if two things are the same

=head1 VERSION

Version 1.000

=cut

our $VERSION = '1.000';


=head1 SYNOPSIS

    use Firepear::Catechesis::Verifier;

    my $v = Firepear::Catechesis::Verifier->new;
    my $results = $v->verify($expected, $got);

=head1 METHODS

=head2 new

The constructor. Takes no arguments.

=cut

sub new {
  my ($class, %args) = @_;
  my $self = { _expected => 0,
               _got      => 0,
               _stack    => [],
               _test     => {} };
  bless $self, $class;
  return $self;
}

=head2 verify

Requires two JSON-encoded strings. The first is the value of the
C<expected> directive from a test. The second is the result given for
that test by a shim program. The datastructures represented by these
strings are then compared.

See L<Firepear::Catechesis/DATA STRUCTURES> for information on return
values.

=cut

sub verify {
  my ($self, $expected_str, $got_str) = @_;
  $self->_init_verify;
  my $test = $self->{_test};

  # expected and got must exist and vivify
  return $self->error('NOEXPECT') unless $expected_str;
  return $self->error('NOGOT') unless $got_str;
  my $decoded_expected;
  eval { $decoded_expected = decode_json($expected_str) };
  return $self->error('EXPECTNOTJSON') if $@;
  my $decoded_got;
  eval { $decoded_got = decode_json($got_str) };
  return $self->error('GOTNOTJSON') if $@;

  # and must be hashrefs
  return $self->error('EXPECTNOTHASH')
    unless (ref $decoded_expected eq 'HASH');
  return $self->error('GOTNOTHASH')
    unless (ref $decoded_got eq 'HASH');

  # ok, stow vivified structs
  $self->{_expected} = $decoded_expected;
  $self->{_got} = $decoded_got;


  # hash both structs and return comparison
  $self->_hash;
  return $self->_compare;
}

sub _compare {
  my ($self) = @_;
  for my $which (qw(expected got)) {
    my $other = $which eq 'expected' ? 'got' : 'expected';
    for (keys %{$self->{_hash}{$which}}) {
      # check existance
      unless (exists $self->{_hash}{$other}{$_})
        { push @{$self->{_test}{mismatch}{$which}}, $_; next }
      # check value
      my $a = $self->{_hash}{$which}{$_};
      my $b = $self->{_hash}{$other}{$_};
      $self->{_test}{mismatch}{noteq}{$_} = { $which => $a, $other => $b }
        unless (($a eq $b) or exists $self->{_test}{mismatch}{noteq}{$_});
    }
  }

  delete $self->{_test}{mismatch}{noteq} unless keys %{$self->{_test}{mismatch}{noteq}};
  delete $self->{_test}{mismatch} unless keys %{$self->{_test}{mismatch}};
  return $self->error('EXPECTGOTMISMATCH') if exists $self->{_test}{mismatch};
  $self->{_test}{type} = 'match';
  return $self->{_test};
}

sub _hash {
  my ($self) = @_;
  $self->_hashgen('expected', $_, $self->{_expected}{$_})
    for (keys %{$self->{_expected}});
  $self->_hashgen('got', $_, $self->{_got}{$_})
    for (keys %{$self->{_got}});
}

sub _hashgen {
  my ($self, $which, $key, $chunk) = @_;

  # push our name onto stack so we don't have to track it
  push @{$self->{_stack}}, $key;

  if (ref $chunk eq 'HASH') {
    # we are a hashref. descend.
    for my $elem (keys %{$chunk})
      { $self->_hashgen($which, $elem, $chunk->{$elem}) }
  } elsif (ref $chunk eq 'ARRAY') {
    # we are an arrayref. descend, using indices as 'keys'
    my $i = 0;
    for my $elem (@{$chunk}) {
      $self->_hashgen($which, $i, $chunk->[$i]);
      $i++;
    }
  } else {
    # we are a leafnode
    # generate the key for the memoization hash
    my $hashkey = join(':',@{$self->{_stack}});
    # and store our value there
    $self->{_hash}{$which}{$hashkey} = $chunk;
  }

  # pop the stack to get ourselves off it
  pop @{$self->{_stack}};
}

sub _init_verify {
  my ($self) = @_;
  undef  $self->{_test}{type};
  delete $self->{_test}{mismatch};
  $self->{_hash} = {};
}

=head1 AUTHOR

Firepear Informatics, C<< <firepear at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-firepear-catechesis at rt.cpan.org>, or through the web
interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Firepear-Catechesis>.
I will be notified, and then you'll automatically be notified of
progress on your bug as I make changes.


=head1 COPYRIGHT & LICENSE

Copyright 2010 Firepear Informatics, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

1; # End of Firepear::Catechesis::Validator
