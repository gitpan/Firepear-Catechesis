#!perl -T

use Test::More tests => 50;

use JSON;

BEGIN {
	use_ok( 'Firepear::Catechesis::Verifier' );
}

# setup
my $g1 = {y => 'z'};
my $x1 = { animals => { cats => [ { name => 'talulah',
                                    size => 'fat',
                                    type => 'retard' },
                                  { name => 'alice',
                                    size => 'porky',
                                    type => 'aloof' } ],
                        dogs => 'none'
                      },
           numbers => [ 17, 42, 111 ]
         };
my $x2 = { animals => { cats => [ { name => 'talulah',
                                    size => 'fat',
                                    type => 'retard' },
                                  { name => 'alice',
                                    size => 'porky',
                                    type => 'aloof' } ],
                      },
           numbers => [ 17, 42 ]
         };
my $x3 = { animals => { cats => [ { name => 'talulah',
                                    type => 'retard' },
                                  { name => 'alice',
                                    size => 'big-boned',
                                    type => 'aloof' } ],
                        dogs => 'none'
                      },
           numbers => [ 42, 111 ]
         };

# JSON fails
my $v = Firepear::Catechesis::Verifier->new;
my $r = $v->verify;
is ($r->{type}, 'error', 'error');
is ($r->{code}, 'NOEXPECT', 'no expect');
is ($r->{msg},  "No 'expect' string was provided", "no expect str");
$r = $v->verify('foo');
is ($r->{type}, 'error', 'error');
is ($r->{code}, 'NOGOT', 'no got');
is ($r->{msg},  "No 'got' string was provided", "no got str");
$r = $v->verify('foo','bar');
is ($r->{type}, 'error', 'error');
is ($r->{code}, 'EXPECTNOTJSON', 'expect not json');
is ($r->{msg},  "Passed 'expected' string is not valid JSON/did not vivify", "no expect vivify");
$r = $v->verify('{"foo":"bar"}','bar');
is ($r->{type}, 'error', 'error');
is ($r->{code}, 'GOTNOTJSON', 'got not json');
is ($r->{msg},  "Passed 'got' string is not valid JSON/did not vivify", "no got vivify");
$r = $v->verify('["foo","bar"]','{"foo":"bar"}');
is ($r->{type}, 'error', 'error');
is ($r->{code}, 'EXPECTNOTHASH', 'expect not hash');
is ($r->{msg},  "Vivified 'expect' struct is not a key/value store", "expect is not hashref");
$r = $v->verify('{"foo":"bar"}','["foo","bar"]');
is ($r->{type}, 'error', 'error');
is ($r->{code}, 'GOTNOTHASH', 'got not hash');
is ($r->{msg},  "Vivified 'got' struct is not a key/value store", "got is not hashref");

# hash testing
$v = Firepear::Catechesis::Verifier->new;
$v->_init_verify;
$v->{_expected} = {a => 'b'};
$v->{_got} = {y => 'z'};
$v->_hash;
is ($v->{_hash}{expected}{a}, "b", "it worked");
is ($v->{_hash}{expected}{c}, undef, "this shouldn't exist");
is (keys %{$v->{_hash}{expected}}, 1, "single element in hash");
is ($v->{_hash}{got}{y}, "z", "it worked here too");
is ($v->{_hash}{got}{c}, undef, "this shouldn't exist either");
is (keys %{$v->{_hash}{got}}, 1, "single element in hash as well");

$v->_init_verify;
$v->{_expected} = $x1;
$v->{_got}      = $g1;
$v->_hash;
is (keys %{$v->{_hash}{expected}}, 10, "flattens to 10 (leaf) elements");
is ($v->{_hash}{expected}{'numbers:0'}, 17);
is ($v->{_hash}{expected}{'numbers:1'}, 42);
is ($v->{_hash}{expected}{'numbers:2'}, 111);
is ($v->{_hash}{expected}{'animals:dogs'}, "none");
is ($v->{_hash}{expected}{'animals:cats:0:name'}, "talulah");
is ($v->{_hash}{expected}{'animals:cats:0:size'}, "fat");
is ($v->{_hash}{expected}{'animals:cats:0:type'}, "retard");
is ($v->{_hash}{expected}{'animals:cats:1:name'}, "alice");
is ($v->{_hash}{expected}{'animals:cats:1:size'}, "porky");
is ($v->{_hash}{expected}{'animals:cats:1:type'}, "aloof");

# comparison testing
$v = Firepear::Catechesis::Verifier->new;
$v->_init_verify;
$v->{_expected} = $x1;
$v->{_got}      = $x1;
$v->_hash;
$r = $v->_compare;
is ($r->{type}, 'match', 'same struct; type should be match');
is ($r->{mismatch}, undef, 'mismatch shouldnt be there either');

$v->_init_verify;
$v->{_expected} = $x1;
$v->{_got}      = $x2;
$v->_hash;
$r = $v->_compare;
is ($r->{type}, 'error', "we should have mismatches: in x1 not in x2");
is_deeply ([sort @{$r->{mismatch}{expected}}], ['animals:dogs', 'numbers:2'] ,
           "we deleted dogs and a number from x2" );
is ($r->{noteq}, undef, "nothing should be unequal");

$v->_init_verify;
$v->{_expected} = $x3;
$v->{_got}      = $x1;
$v->_hash;
$r = $v->_compare;
is ($r->{type}, 'error', "we should have mismatches: not in x3 in x1");
is_deeply ([sort @{$r->{mismatch}{got}}], ['animals:cats:0:size', 'numbers:2'] ,
           "x3: removed talulah size, numbers2");
is_deeply ($r->{mismatch}{noteq},
           {'animals:cats:1:size' => {expected => 'big-boned', got => 'porky'},
            'numbers:0' => {expected => 42, got => 17},
            'numbers:1' => {expected => 111, got => 42} },
           "changed alice's size, numbers don't match anymore");

$v->_init_verify;
$v->{_expected} = $x3;
$v->{_got}      = $x2;
$v->_hash;
$r = $v->_compare;
is ($r->{type}, 'error', "we should have mismatches in both directions");
is_deeply ($r->{mismatch}{expected}, ['animals:dogs'],
           "dogs is in x3 but not x2");
is_deeply ($r->{mismatch}{got}, ['animals:cats:0:size'], "talulah size in x2 but not x3");
is_deeply ($r->{mismatch}{noteq},
           {'animals:cats:1:size' => {expected => 'big-boned', got => 'porky'},
            'numbers:0' => {expected => 42, got => 17},
            'numbers:1' => {expected => 111, got => 42} },
           "changed alice's size, numbers don't match anymore");

# redo first comparison test but with full stack (and struct as JSON)
$v = Firepear::Catechesis::Verifier->new;
$r = $v->verify(encode_json($x1), encode_json($x1));
is ($r->{type}, 'match', 'same struct; type should be mathch');
is ($r->{mismatch}, undef, 'mismatch shouldnt be there either');
