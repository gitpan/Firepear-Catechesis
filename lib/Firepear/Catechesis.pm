package Firepear::Catechesis;

use warnings;
use strict;

use Firepear::Catechesis::Parser;
use Firepear::Catechesis::Verifier;
use Firepear::Catechesis::TAP;
use Firepear::Catechesis::Util;

=head1 NAME

Firepear::Catechesis - The great new Firepear::Catechesis!

=head1 VERSION

Version 1.000

=cut

our $VERSION = '1.000';


=head1 IMPORTANT

You should only be reading this if you wish to modify the Catechesis
software itself, or if you are interested in its internals.

If you wish to use Catechesis to author test suites, please see the
documentation at the project's homepage at
L<http://firepear.net/catechesis/> or the file C<main.html> in this
distribution's C<docs> directory.

If you wish to run existing Catechesis test suites, see the
C<catechist> manpage.

Thank you for your attention in this matter.

=head1 SYNOPSIS

    use Firepear::Catechesis;
    my $cat = Firepear::Catechesis->new( tests => \@script_files );

    ...

    my $stanza = $cat->fetch;
    if ($cat->has_err) {
      exit if $stanza->{msg} eq "EOF" # out of tests when this happens
      next; # never send a stanza with an error to the shim
    }
    print SHIM_WRITE_PIPE encode_json($stanza),"\n";

    my $answer = <SHIM_READ_PIPE>;
    $cat->compare($test->{expected}, $answer);

=head1 DESCRIPTION

Firepear::Catechesis handles the parsing and validation of Catechesis
scripts, the comparison of computed with expected results, and
produces TAP output based upon those comparisons.

=head1 METHODS

=head2 new

The constructor requires one argument, C<tests>, which is a Catechesis
test script filename or an arrayref containing several such filenames.

On error, the constructor will die.

=cut

sub new {
  my ($class, %args) = @_;
  die "No test scripts provided to Firepear::Catechesis::new! Cannot run without tests.\n"
    unless $args{tests};
  die "The 'tests' argument to Firepear::Catechesis::new must be a scalar or arrayref.\n"
    if (ref $args{tests} eq 'HASH');

  $args{tests} = [ $args{tests} ] unless (ref $args{tests} eq 'ARRAY');

  my $self = bless { _scripts => $args{tests},
                     _env => { error => 0 } }, $class;

  $self->{shh} = 1 if $args{shh}; # be quiet (for testing)

  my $script = shift @{$self->{_scripts}};
  $self->{_p} = Firepear::Catechesis::Parser->new(tests => $script);
  die "Error instantiating F::C::Parser: ", $self->{_p}{code}, ": ", $self->{_p}{msg}, "\n"
    unless (ref $self->{_p} eq "Firepear::Catechesis::Parser");

  $self->{_v} = Firepear::Catechesis::Verifier->new;
  die "Error instantiating F::C::Verifier\n"
    unless (ref $self->{_v} eq "Firepear::Catechesis::Verifier");

  $self->{_t} = Firepear::Catechesis::TAP->new;

  return $self;
}

=head2 fetch

Returns the next stanza from the script(s) given in the call to C<new>.

On success, a stanza struct will be returned; on error, an error
struct will be returned. See L</DATA STRUCTURES>, later in this
document, for more information.

    my $stanza = $cat->fetch;

If there is an error, the driver program B<should not> send the struct
to the shim. Shims should be able to trust their input is properly
formatted, and an error here means that cannot be true.

Errors are checked for using L</has_err>, as in

    my $stanza = $cat->fetch;
    abort() if $cat->has_err;

Other than this, drivers do not I<need> to implement any error
handling in these cases. Everything neccessary is handled internally,
and appropriate TAP will be generated.

Additionally, the C<plan> and C<diag> directives in stanzas are
handled here; drivers need take no action on them.

=cut

sub fetch {
  my ($self) = @_;
  my $p = $self->{_p};
  my $tap = $self->{_t};
  $self->{_env}{error} = 0;

  # get stanza, stow, and set it as last received
  $self->{_test} = $p->yield;
  my $stanza = $self->{_test};
  $self->{_last}{stanza} = $stanza;
  $self->{_last}{ptr}    = 'stanza';

  # handle EOFs ourself, as they're not true errors
  if ($self->has_err and $stanza->{code} eq 'EOF') {
    return $stanza unless @{$self->{_scripts}};
    $self->{_env}{plan} = 0;
    $tap->reset_count;
    my $rv = $p->file(shift @{$self->{_scripts}});
    if (ref $rv eq 'HASH') { # error on file transition
      $stanza = $self->error('BAILOUT', x1 => $rv->{code} . ": " . $rv->{msg});
      $tap->emit($stanza) unless $self->{shh};
      return $stanza;
    }
    return $self->fetch;
  }

  # set that we've seen a plan being set if we have
  $self->{_env}{plan} = 1 if $stanza->{directives}{plan};
  # and throw an error if we're seeing a test before a shim
  $stanza = $self->error('TESTBEFOREPLAN', fn => $p->{_filename}, ln => $.)
    if ($stanza->{type} eq 'test' and not $self->{_env}{plan});

  # emit TAP and return stanza to driver
  $tap->emit($stanza) unless $self->{shh};
  return $stanza;
}

=head2 compare

Requires two JSON-encoded strings. The first is the value of the
C<expected> directive from a test. The second is the result given for
that test by a shim program. Both should represent a
hash/dictionary/object/associative array (in Perl terms, they must
vivify to a hashref).

The datastructures represented by these strings are then compared.

    $cat->compare($stanza->{directives}{expected}, $got_from_shim);

Calls to C<compare> do return a value (documented in L</DATA
STRUCTURES>), but it should rarely be neccessary for a driver to do
anything with it. C<compare> will handle production of TAP, including
verbose diagnostics when the comparison is a mismatch.

=cut

sub compare {
  my ($self, $expected, $got) = @_;
  my $v = $self->{_v};
  my $tap = $self->{_t};

  # get results, stow, and set as last received
  $self->{_test} = $v->verify($expected, $got);
  my $results = $self->{_test};
  $self->{_last}{answer} = $results;
  $self->{_last}{ptr}    = 'answer';
  $results->{directives}{desc} = $self->{_last}{stanza}{directives}{desc}
    if $self->{_last}{stanza}{directives}{desc};
  $tap->emit($results) unless $self->{shh};
  return $results;
}

=head2 has_err

Check the Catechesis object for an error condition in the
last-returned data structure. Returns C<1> on error and C<0>
otherwise.

=cut

sub has_err {
  my ($self) = @_;
  return 1 if $self->{_env}{error};
  return 0 unless defined $self->{_last};
  my $msg = $self->{_last}{ $self->{_last}{ptr} };
  return 1 if ($msg->{type} eq 'error');
  return 0;
}


=head1 DATA STRUCTURES

=head2 Structs from C<fetch>

Successful calls to L</fetch> will return a structure shaped like
this:

    {
      type       => [ 'environment' | 'test' ],
      directives => { foo => 'bar',
                      baz => 'quux',
                      ... }
    }

The C<type> indicates the stanza type. The C<directives> hashref
contains all the directives from the stanza.

=head2 Structs from C<compare>

Successful calls to L</ccompare> will return a struct which is
basically empty; only C<type> will be defined, and its value will be
C<match>.

    { type => 'match' }

=head2 Error structs

In all cases of error -- both for L</fetch> and L</compare> -- the
struct returned will have C<type> set to C<error>, and it will include
two additional keys:

=over

=item  C<code>

The mnemonic error code

=item C<msg>

The human-readable error message

=back

When the error is from a call to C<compare> and C<code> is
C<EXPECTGOTMISMATCH>, the call has worked properly, but something was
wrong with the data from the shim. In this case, an additional field,
C<mismatch> will appear, which may contain any of three additional
subfields:

=over

=item C<expected>

An arrayref of field names which appear in the C<expected> data but
not in the data received from the shim.

=item C<got>

An arrayref of field names which appear in the data from the shim, but
not in the C<expected> data.

=item C<noteq>

A hashref containing entries where the values from the C<expected> and
received datasets are not equal. They keys will be the field names and
the values will be another hashref, containing both values:

    noteq => { field_x => { expected => 1, got => 2 },
               field_y => { expected => 'a', got => 'b' } }

=back

When the missing/mismatched fields are in a nested structure -- and
they usually will be -- field names will appear in a "flattened",
colon-separated format, as viewed from the top of the structure. For
example, if the 3rd element of a list -- which is an element of a
hash, which is an element of a top-level hash -- isn't equal to its
expected value, it would have

    tophash:hash:2

as its name in the C<noteq> hashref.

    noteq => { field_x => { expected => 1, got => 2 },
               tophash:hash:2 => { expected => 'p', got => 'q' } }



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

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.


=cut

1; # End of Firepear::Catechesis
