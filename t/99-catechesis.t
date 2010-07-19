#!perl -T

use Test::More tests => 46;
use Firepear::Catechesis;

# constructor fails
my $cat;
eval { $cat = Firepear::Catechesis-> new; };
is ($@, "No test scripts provided to Firepear::Catechesis::new! Cannot run without tests.\n");
eval { $cat = Firepear::Catechesis-> new(tests => {foo => 'bar'}); };
is ($@, "The 'tests' argument to Firepear::Catechesis::new must be a scalar or arrayref.\n");
eval { $cat = Firepear::Catechesis-> new(tests => 't/corpus/zzzzz.txt'); };
is ($@, "Error instantiating F::C::Parser: NOSCRIPTACCESS: Can't read script file t/corpus/zzzzz.txt\n");

# constructor success
$cat = Firepear::Catechesis-> new(tests => 't/corpus/parser04.txt', shh => 1);
is($cat->has_err, 0, "this should hit the undef test");
is (ref $cat, "Firepear::Catechesis", "we should be us");
is_deeply ($cat->{_scripts}, [],
           "should be empty arayref due to conversion then shifting");

# fetch
my $msg = $cat->fetch;
is ($cat->has_err, 0, "this should actually hit a stored message");
is ($msg->{type}, "environment", "should be an environment stanza");

# script file rolling
$cat = Firepear::Catechesis-> new(tests => ['t/corpus/parser04.txt', 't/corpus/cat02.txt'], shh => 1);
is($cat->has_err, 0, "this should hit the undef test");
is (ref $cat, "Firepear::Catechesis", "we should be us");
is_deeply ($cat->{_scripts}, ['t/corpus/cat02.txt'],
           "one file should be gone");
$msg = $cat->fetch;
$msg = $cat->fetch;
$msg = $cat->fetch;
$msg = $cat->fetch; # file should switch here
is_deeply ($cat->{_scripts}, [], "we're now on parser05.txt");
is ($cat->has_err, 0, "imtermediate EOF is not error");
$msg = $cat->fetch;
$msg = $cat->fetch; # and now we should have an actual EOF
is ($cat->has_err, 1, "last EOF returns error");
is ($msg->{code}, "EOF", "EOF"); 

# error on file rolling
$cat = Firepear::Catechesis-> new(tests => ['t/corpus/parser04.txt', 't/corpus/parserZZ.txt'], shh => 1);
is($cat->has_err, 0, "this should hit the undef test");
is (ref $cat, "Firepear::Catechesis", "we should be us");
is_deeply ($cat->{_scripts}, ['t/corpus/parserZZ.txt'],
           "one file should be gone");
$msg = $cat->fetch;
$msg = $cat->fetch;
$msg = $cat->fetch;
$msg = $cat->fetch; # file should switch here, but doesn't exist
is_deeply ($cat->{_scripts}, [], "all files off stack");
is ($cat->has_err, 1, "file didn't exist");
is ($msg->{code}, 'BAILOUT');
is ($msg->{msg}, "Bail out! NOSCRIPTACCESS: Can't read script file t/corpus/parserZZ.txt");

# check_answer
$cat = Firepear::Catechesis-> new(tests => 't/corpus/parser00.txt', shh => 1);
my $str1 = '{"foo":1,"bar":2}';
my $str2 = '{"foo":1,"bar":2}';
my $answer = $cat->compare($str1, $str2);
is ($cat->has_err, 0);
is($answer->{type}, 'match');

# non-EOF error on fetch
$cat = Firepear::Catechesis-> new(tests => 't/corpus/parser00.txt', shh => 1);
$msg = $cat->fetch;
is ($cat->has_err, 1);
is ($msg->{type}, 'error', '#3 should be an error');
is ($msg->{code}, 'BEGINWITHOUTLABEL',  '#3 no label on begin');
is ($msg->{msg},  "No label on 'begin' at t/corpus/parser00.txt line 6", "#3 no stanza label");

# test-before-plan fail
$cat = Firepear::Catechesis-> new(tests => 't/corpus/cat01.txt', shh => 1);
$msg = $cat->fetch;
is ($cat->has_err, 1);
is ($msg->{type}, 'error');
is ($msg->{code}, 'TESTBEFOREPLAN');
is ($msg->{msg},  "Test found in stanza ending at t/corpus/cat01.txt line 9 before a plan was defined");

# full stack tests
$cat = Firepear::Catechesis-> new(tests => 't/corpus/cat00.txt', shh => 1);
$msg = $cat->fetch; # env stanza
$msg = $cat->fetch;
is ($cat->has_err, 0, 'stanza is fine');
is_deeply ($cat->{_scripts}, [], "all files off stack");
is ($msg->{type}, 'test');
is ($msg->{directives}{send},   '{ 1, 2, 3, 4, 5, 6 }');
is ($msg->{directives}{expect}, '{ "value":["a", "b", "c", "d", "e", "f"] }');
is ($msg->{directives}{desc}, 'fake data test');
$answer = $cat->compare($msg->{directives}{expect},
                        '{"value":["a", "b", "c", "d", "e", "f"]}');
is ($cat->has_err, 0);
is($answer->{type}, 'match');
$answer = $cat->compare($msg->{directives}{expect},
                        '{"value":["a", "b", "q", "d", "e", "f"]}');
is ($cat->has_err, 1);
is ($answer->{type}, 'error');
is ($answer->{code}, 'EXPECTGOTMISMATCH');
is ($answer->{directives}{desc}, 'fake data test');
is ($answer->{mismatch}{expect}, undef);
is_deeply ($answer->{mismatch}{noteq}{'value:2'}, {expected => "c", got => "q"});
