package Firepear::Catechesis::TAP;

use warnings;
use strict;

use Firepear::Catechesis::Util;

=head1 NAME

Firepear::Catechesis::TAP - Output TAP based on input

=head1 VERSION

Version 1.000

=cut

our $VERSION = '1.000';


=head1 SYNOPSIS

    use Firepear::Catechesis::TAP;

    my $tap = Firepear::Catechesis::TAP->new;
    $tap->write($data)

=head1 METHODS

=head2 new

C<new> only requires an argument if you intend to run F::C::TAP under
a TAP-consuming test harness. In this case, an arg named C<test>
should be provided, and its value should be the name of the file to be
used for test output.

=cut

sub new {
  my ($class, %args) = @_;

  my $self = { _count => 0 };
  if ($args{test}) {
    open $self->{_testing}, '>', $args{test}
      or die "Bail out! Can't open test output file for F::C::TAP\n";
  }
  bless $self, $class;
  return $self;
}

=head2 emit

Generate TAP output from a passed structure (from L<Firepear::Catechesis>).

Typically, a struct will generate a single C<ok> or C<not ok> line.

Structs which contain C<diag> directives will generate a TAP
diagnostic line. Error structs with C<malformed> substructures will
generate possibly-extensive diagnostics explaining what has gone
wrong.

Calling C<emit> without passing a struct, or with a malformed struct,
will generate a TAP C<Bail out!> message, which should immediately
terminate all testing. Any error struct which has a code of C<BAILOUT>
(see L<Firepear::Catechesis::Util>) will also do this.

=cut

sub emit {
  my ($self, $struct) = @_;
  my $txt;

  # interal errors
  unless (defined $struct)
    { $self->_e("Bail out! No struct was passed to TAP emitter"); return }
  unless (ref $struct eq 'HASH' and $struct->{type})
    { $self->_e("Bail out! Malformed struct was passed to TAP emitter"); return }

  # increment count for tests
  $self->{_count}++ if ($struct->{type} eq 'test');

  # handle diags
  $self->_e("# $struct->{directives}{diag}")
    if $struct->{directives}{diag};

  # and errors
  if ($struct->{type} eq 'error') {
    if ($struct->{code} eq 'BAILOUT')
      { $self->_e("Bail out! $struct->{msg}"); return }

    $txt = "not ok $self->{_count} $struct->{code}: $struct->{msg}";
    $txt .= " in test '$struct->{directives}{desc}'" if $struct->{directives}{desc};
    $self->_e($txt);

    if ($struct->{mismatch}{expected}) {
      $self->_e("# the following keys were expected but not found in shim response:");
      $self->_e("#   " . join(", ", @{$struct->{mismatch}{expected}}));
    }

    if ($struct->{mismatch}{got}) {
      $self->_e("# the following keys are in the shim response but were not expected:");
      $self->_e("#   " . join(", ", @{$struct->{mismatch}{got}}));
    }

    if ($struct->{mismatch}{noteq}) {
      $self->_e("# there were mismatches between expected values and the shim response:");
      for my $key (sort keys %{$struct->{mismatch}{noteq}}) {
        $self->_e("#   $key: " .
                  "expected '$struct->{mismatch}{noteq}{$key}{expected}'; " .
                  "got '$struct->{mismatch}{noteq}{$key}{got}'");
      }
    }
  }

  # environment: plan lines
  if ($struct->{type} eq 'environment') {
    for my $key (sort keys %{$struct->{directives}}) {
      if ($key eq 'plan') {
        $self->_e("1..$struct->{directives}{plan}")
      }
    }
  }

  # and, finally and simply, successes
  if ($struct->{type} eq 'match') {
    $txt = "ok $self->{_count}";
    $txt .= " $struct->{directives}{desc}" if $struct->{directives}{desc};
    $self->_e($txt) 
  }
}


=head2 reset_count

Sets test count back to zero. Should be called when a new script is
opened.

=cut

sub reset_count {
  my ($self) = @_;
  $self->{_count} = 0;
}

# _e
# just a hack to allow testing TAP emission while under a TAP emitter
sub _e {
  my ($self, $msg) = @_;
  if ($self->{_testing}) {
    select $self->{_testing};
    $| = 1;
    print "$msg\n";
    select STDOUT;
    return;
  }
  print "$msg\n";
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

1; # End of Firepear::Catechesis::TAP
