#!perl -T

use Test::More tests => 3;

BEGIN {
	use_ok( 'Firepear::Catechesis::Util' );
}

eval { error({}) };
is ($@ =~ /^No error type provided/, 1);
eval { error({}, 'FOO') };
is ($@ =~ /^Unknown error type 'FOO'/, 1);
