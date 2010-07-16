package Firepear::Catechesis::Parser;

use warnings;
use strict;

use Firepear::Catechesis::Util;

=head1 NAME

Firepear::Catechesis::Parser - Read test scripts

=head1 VERSION

Version 1.000

=cut

our $VERSION = '1.000';


=head1 SYNOPSIS

    use Firepear::Catechesis::Parser;

    my $p = Firepear::Catechesis::Parser->new(tests => "testfile");

    while (CONDITION) {
        my $stanza = $p->yeild;
        dispatch($stanza);
    }

=head1 METHODS

=head2 new

The constructor requires one argument, C<tests>, which is a Catechesis
test script filename.

On failure, an error construct will be returned.

=cut

sub new {
  my ($class, %args) = @_;
  my $self = { _stanzas => { environment => { diag => 1,
                                              plan => 1, },
                             test => { diag => 1,
                                       desc => 1,
                                       send => 1,
                                       expect => 1, }, },
               _test => {},
             };
  bless $self, $class;
  my $rv = $self->file($args{tests});
  return (ref $rv eq 'HASH') ? $rv : $self;
}

=head2 yeild

Yeilds the next stanza from the current file. See
L<Firepear::Catechesis/DATA STRUCTURES> for more information.

=cut

sub yield {
  my ($self) = @_;
  my $test = $self->{_test};
  my $fh = $self->{_fh};
  my $begin = 0;

  undef $test->{type};
  undef $test->{directives};

  while (my $line = <$fh>) {
    $line =~ s/^\s+//;
    $line =~ s/\s+$//;
    next unless $line =~ m/\S/;
    next if $line =~ m/^#/;

    # nothing happens until we reach a 'begin' line
    if ($line =~ m/^begin/i) {
      return $self->error('BEGINWITHOUTEND', fn => $self->{_filename}, ln => $.)
        if $begin;
      $begin = 1;

      # all begins must have a label
      my @chunks = split /\s+/, $line;
      $test->{type} = $chunks[1];
      return $self->error('BEGINWITHOUTLABEL', fn => $self->{_filename}, ln => $.)
        unless defined $test->{type};

      next;
    }
    # if we get down here and haven't seen a 'begin' yet, then we have
    # illegal text outside a stanza
    return $self->error('TEXTOUTSIDESTANZA', fn => $self->{_filename}, ln => $.)
      unless $begin;

    # end terminates stanza processing
    last if $line =~ m/^end/i;

    # handle line continuations
    if ($line =~ /\\$/) {
      $line =~ s/\s*\\$/ /;
      $self->{_continuline} .= $line;
      next;
    } 
    $line = $self->{_continuline} . $line if $self->{_continuline};

    # and then shove things into the test
    my @chunks = split /\s+/, $line;
    my $directive = shift @chunks;
    $test->{directives}{$directive} = join ' ', @chunks;
    $self->{_continuline} = '';
  }

  return $self->error('EOF') unless defined $test->{type};
  return $self->_validate;
}

=head2 file

Given a file name, it opens that file for parsing as a test script.

=cut

sub file {
  my ($self,$file) = @_;
  return $self->error('NOSCRIPT') unless defined $file;
  open $self->{_fh}, '<', $file
    or return $self->error('NOSCRIPTACCESS', fn => $file);
  $self->{_filename} = $file;
}


# _validate
#
# internal method which takes a test struct as input and checks it for
# validity according to the following rules:
#
# 1. the test type must be one of those defined in $self->{_stanzas}
# 2. all directives within the test must be likewise defined
#

sub _validate {
  my ($self) = @_;
  my $test = $self->{_test};

  # type must be valid
  return $self->error('BADLABEL', fn => $self->{_filename}, ln => $., x1 => $test->{type})
    unless defined $self->{_stanzas}{ $test->{type} };
  # and that's all unless we have directives or are a test stanza
  return $self->{_test} unless ($test->{type} eq 'test' or defined $test->{directives});

  # and all directives must be valid
  for my $given ( keys %{$test->{directives}} ) {
    return $self->error('BADDIRECTIVE', fn => $self->{_filename}, ln => $., x1 => $given)
      unless $self->{_stanzas}{ $test->{type} }{$given};
  }

  # 'send' and 'expect' must exist in 'test' stanzas
  if ($self->{_test}{type} eq 'test') {
    return $self->error('NOSENDINTEST', fn => $self->{_filename}, ln => $.)
      unless $self->{_test}{directives}{send};
    return $self->error('NOEXPECTINTEST', fn => $self->{_filename}, ln => $.)
      unless $self->{_test}{directives}{expect};
  }
  return $self->{_test};
}

=head1 AUTHOR

Firepear Informatics, C<< <firepear at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-firepear-catechesis at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Firepear-Catechesis>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.


=head1 COPYRIGHT & LICENSE

Copyright 2010 Firepear Informatics, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

1; # End of Firepear::Catechesis::Parser
