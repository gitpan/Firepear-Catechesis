package Firepear::Catechesis::Util;

use warnings;
use strict;

=head1 NAME

Firepear::Catechesis::Util - Helper Methods

=head1 VERSION

Version 1.000

=cut

our $VERSION = '1.000';

our @ISA    = qw(Exporter);
our @EXPORT = qw(&error);

my %errormsgs = ( NOSCRIPT          => "No test script was provided",
                  NOSCRIPTACCESS    => "Can't read script file =fn=",
                  TEXTOUTSIDESTANZA => "Non-comment text found outside stanza at =fn= line =ln=",
                  BEGINWITHOUTLABEL => "No label on 'begin' at =fn= line =ln=",
                  BADLABEL          => "Unknown label '=x1=' on 'begin' at =fn= line =ln=",
                  BEGINWITHOUTEND   => "Found 'begin' while inside stanza at =fn= line =ln=",
                  BADDIRECTIVE      => "Unknown directive '=x1=' in stanza ending at =fn= line =ln=",
                  TESTBEFOREPLAN    => "Test found in stanza ending at =fn= line =ln= before a plan was defined",
                  NOSENDINTEST      => "No 'send' directive was found in stanza ending at =fn= line =ln=",
                  NOEXPECTINTEST    => "No 'expect' directive was found in stanza ending at =fn= line =ln=",
                  EOF               => "EOF",
                  NOEXPECT          => "No 'expect' string was provided",
                  NOGOT             => "No 'got' string was provided",
                  EXPECTNOTJSON     => "Passed 'expected' string is not valid JSON/did not vivify",
                  GOTNOTJSON        => "Passed 'got' string is not valid JSON/did not vivify",
                  EXPECTNOTHASH     => "Vivified 'expect' struct is not a key/value store",
                  GOTNOTHASH        => "Vivified 'got' struct is not a key/value store",
                  EXPECTGOTMISMATCH => "Vivified 'expect' and 'got' structs are not equivalent",
                  BAILOUT           => "Bail out! =x1=",
                );

=head1 SYNOPSIS

    use Firepear::Catechesis::Util;

=head1 METHODS

=head2 error

Does nasty, spooky-action-at-a-distance things to wrap error semantics
onto existing stanza structures.

=cut

sub error {
  my ($self, $error, %args) = @_;
  $self->{_test}{type} = 'error';
  $self->{_test}{code} = $error;
  $self->{_test}{msg}  = errormsg($error, \%args);
  return $self->{_test};
}

sub errormsg {
  my ($error, $args) = @_;
  die "No error type provided" unless defined $error;
  die "Unknown error type '$error'" unless $errormsgs{$error};
  my $msg = $errormsgs{$error};
  for (keys %{$args}) {
    my $subtext = $args->{$_};
    $msg =~ s/=$_=/$subtext/
  }
  return $msg;
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

1; # End of Firepear::Catechesis::Util
