#!perl -T
use Test::More tests => 24;

BEGIN {
	use_ok( 'Firepear::Catechesis::TAP' );
}

# bad path fail
eval { 
  my $tap = Firepear::Catechesis::TAP->new(test => "/l/m/n/o/p/z/fctap.txt");
};
is ($@, "Bail out! Can't open test output file for F::C::TAP\n");

# no struct fail
my $tap = Firepear::Catechesis::TAP->new(test => "/tmp/fctap.txt");
$tap->emit;
open TAP,'<',"/tmp/fctap.txt";
my $tapout = <TAP>;
is ($tapout, "Bail out! No struct was passed to TAP emitter\n");
close TAP;

# not hashref/proper struct fails
$tap = Firepear::Catechesis::TAP->new(test => "/tmp/fctap.txt");
$tap->emit("foo");
open TAP,'<',"/tmp/fctap.txt";
$tapout = <TAP>;
is ($tapout, "Bail out! Malformed struct was passed to TAP emitter\n");
close TAP;
$tap = Firepear::Catechesis::TAP->new(test => "/tmp/fctap.txt");
$tap->emit({foo => 1});
open TAP,'<',"/tmp/fctap.txt";
$tapout = <TAP>;
is ($tapout, "Bail out! Malformed struct was passed to TAP emitter\n");
close TAP;
$tap = Firepear::Catechesis::TAP->new(test => "/tmp/fctap.txt");
$tap->emit( { directives => { diag => "diag msg" } } );
open TAP,'<',"/tmp/fctap.txt";
$tapout = <TAP>;
is ($tapout, "Bail out! Malformed struct was passed to TAP emitter\n");
close TAP;

# diags
$tap = Firepear::Catechesis::TAP->new(test => "/tmp/fctap.txt");
$tap->emit( { type => "environment", directives => { diag => "diag msg" } } );
open TAP,'<',"/tmp/fctap.txt";
$tapout = <TAP>;
is ($tapout, "# diag msg\n");
close TAP;

# errors
#
# bailout
my $struct = { type => 'error', code => 'BAILOUT', msg => 'test' };
$tap = Firepear::Catechesis::TAP->new(test => "/tmp/fctap.txt");
$tap->emit($struct);
open TAP,'<',"/tmp/fctap.txt";
$tapout = <TAP>;
is ($tapout, "Bail out! test\n");
close TAP;
# "normal"
$struct = { type => 'error', code => 'FOO', msg => 'test' };
$tap = Firepear::Catechesis::TAP->new(test => "/tmp/fctap.txt");
$tap->emit($struct);
open TAP,'<',"/tmp/fctap.txt";
$tapout = <TAP>;
is ($tapout, "not ok 0 FOO: test\n");
close TAP;
# normal with desc
$struct = { type => 'error', code => 'FOO', msg => 'test',
            directives => {desc => 'bar'} };
$tap = Firepear::Catechesis::TAP->new(test => "/tmp/fctap.txt");
$tap->emit($struct);
open TAP,'<',"/tmp/fctap.txt";
$tapout = <TAP>;
is ($tapout, "not ok 0 FOO: test in test 'bar'\n");
close TAP;
# mismatches
$struct = { type => 'error', code => 'FOO', msg => 'test',
            mismatch => { expected => ['a','b','c'],
                          got => ['d','e'],
                          noteq => { f => {expected => 1, got => 2},
                                     g => {expected => 'x', got => 'y'} } } };
$tap = Firepear::Catechesis::TAP->new(test => "/tmp/fctap.txt");
$tap->emit($struct);
open TAP,'<',"/tmp/fctap.txt";
@tapout = <TAP>;
is ($tapout[0], "not ok 0 FOO: test\n");
is ($tapout[1], "# the following keys were expected but not found in shim response:\n");
is ($tapout[2], "#   a, b, c\n");
is ($tapout[3], "# the following keys are in the shim response but were not expected:\n");
is ($tapout[4], "#   d, e\n");
is ($tapout[5], "# there were mismatches between expected values and the shim response:\n");
is ($tapout[6], "#   f: expected '1'; got '2'\n");
is ($tapout[7], "#   g: expected 'x'; got 'y'\n");
is ($tapout[8], undef);
close TAP;

# environment
$struct = { type => 'environment',
            directives => { shim => 'foo', plan => 6  } };
$tap = Firepear::Catechesis::TAP->new(test => "/tmp/fctap.txt");
$tap->emit($struct);
open TAP,'<',"/tmp/fctap.txt";
@tapout = <TAP>;
is ($tapout[0], "1..6\n");

# success
my $tstruct = { type => 'test' };
$struct = { type => 'match' };
$tap = Firepear::Catechesis::TAP->new(test => "/tmp/fctap.txt");
$tap->emit($tstruct);
$tap->emit($struct);
$tap->emit($tstruct);
$tap->emit($struct);
$tap->emit($tstruct);
$tap->emit($struct);
open TAP,'<',"/tmp/fctap.txt";
@tapout = <TAP>;
is ($tapout[0], "ok 1\n");
is ($tapout[1], "ok 2\n");
is ($tapout[2], "ok 3\n");
is ($tapout[3], undef);
