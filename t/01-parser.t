#!perl -T

use Test::More tests => 61;

BEGIN {
	use_ok( 'Firepear::Catechesis::Parser' );
}

# instantiate fails
my $p = Firepear::Catechesis::Parser->new;
is ($p->{type}, 'error',     '#1 should be an error');
is ($p->{code}, 'NOSCRIPT', '#1 no script error');
is ($p->{msg},  "No test script was provided", "#1 no script");
$p = Firepear::Catechesis::Parser->new(tests => "foo");
is ($p->{type}, 'error', '#2 should be an error');
is ($p->{code}, 'NOSCRIPTACCESS', '#2 cant access script');
is ($p->{msg}, "Can't read script file foo", "#2 can't read");

# no stanza label fail
$p = Firepear::Catechesis::Parser->new(tests => 't/corpus/parser00.txt');
my $t = $p->yield;
is ($t->{type}, 'error', '#3 should be an error');
is ($t->{code}, 'BEGINWITHOUTLABEL',  '#3 no label on begin');
is ($t->{msg},  "No label on 'begin' at t/corpus/parser00.txt line 6", "#3 no stanza label");

# bad stanza label fail
$p = Firepear::Catechesis::Parser->new(tests => 't/corpus/parser01.txt');
$t = $p->yield;
is ($t->{type}, 'error', '#4 should be an error');
is ($t->{code}, 'BADLABEL', '#4 bad label');
is ($t->{msg},  "Unknown label 'foo' on 'begin' at t/corpus/parser01.txt line 7", "bad label");

# simple success
$p = Firepear::Catechesis::Parser->new(tests => 't/corpus/parser02.txt');
$t = $p->yield;
is ($t->{type}, 'environment', "first test is environment");
is ($t->{directives}, undef, "no directives");
$t = $p->yield;
is ($t->{type}, 'test', "second test is test");
is (defined $t->{directives}, 1, "has directives");
$t = $p->yield;
is ($t->{type}, 'error', '#6 should be an error');
is ($t->{code}, 'EOF',   '#6 error type 6');
is ($t->{msg},  "EOF",   "end of file");
# have another go (this could be another file, of course)
$p->file('t/corpus/parser02.txt');
$t = $p->yield;
is ($t->{type}, 'environment', "first test is environment");

# bad directives
$p = Firepear::Catechesis::Parser->new(tests => 't/corpus/parser03.txt');
$t = $p->yield;
is ($t->{type}, 'error', '#5 should be an error');
is ($t->{code}, 'BADDIRECTIVE', '#5 error type 5');
is ($t->{msg},
    "Unknown directive 'baddirective' in stanza ending at t/corpus/parser03.txt line 8",
    "bad directive");

# simple successful directive parsing
$p = Firepear::Catechesis::Parser->new(tests => 't/corpus/parser04.txt');
$t = $p->yield;
is ($t->{type}, 'environment', 'env');
is ($t->{directives}{plan}, 2, 'first directive');
is (keys %{$t->{directives}}, 1, 'only element');
$t = $p->yield;
is ($t->{type}, 'test', 'test');
is ($t->{directives}{send}, '123', 'first directive');
is ($t->{directives}{expect}, '456', 'second directive');
is ($t->{directives}{foo}, undef, 'nonexistant directive');
is (keys %{$t->{directives}}, 2, '2 elements');
$t = $p->yield;
is ($t->{type}, 'test', 'test');
is ($t->{code}, undef);
is ($t->{msg}, undef);
is ($t->{directives}{send}, 'a b c', 'first directive');
is ($t->{directives}{expect}, 'd e f', 'second directive');
is ($t->{directives}{desc}, 'letters', 'nonexistant directive');
is ($t->{directives}{foo}, undef, 'nonexistant directive');
is (keys %{$t->{directives}}, 3, '3 elements');

# multiline tests
$p = Firepear::Catechesis::Parser->new(tests => 't/corpus/parser05.txt');
$t = $p->yield;
is ($t->{type}, 'test', 'test');
is ($t->{code}, undef);
is ($t->{msg}, undef);
is ($t->{directives}{send}, '1 2 3 4 5 6', 'first multiline directive');
is ($t->{directives}{desc}, 'multiline test', 'intermission');
is ($t->{directives}{expect}, '7 8 9 10 11 12', 'second multiline directive');
is ($t->{directives}{foo}, undef, 'nonexistant directive');
is (keys %{$t->{directives}}, 3, '3 elements');

# begin-inside-stanza fail
$p = Firepear::Catechesis::Parser->new(tests => 't/corpus/parser06.txt');
$t = $p->yield;
is ($t->{type}, 'error', '#7 should be an error');
is ($t->{code}, 'BEGINWITHOUTEND', 'begin before end');
is ($t->{msg},  "Found 'begin' while inside stanza at t/corpus/parser06.txt line 11",
    "doublebegin");

# content-outside-stanza fail
$p = Firepear::Catechesis::Parser->new(tests => 't/corpus/parser07.txt');
$t = $p->yield;
is ($t->{type}, 'test', 'test');
$t = $p->yield;
is ($t->{type}, 'error', 'error');
is ($t->{code}, 'TEXTOUTSIDESTANZA', 'begin before end');
is ($t->{msg},  "Non-comment text found outside stanza at t/corpus/parser07.txt line 10",
    'outside stanza');

# tests-must-contain fails
$p = Firepear::Catechesis::Parser->new(tests => 't/corpus/parser08.txt');
$t = $p->yield;
is ($t->{type}, 'error', 'error');
is ($t->{code}, 'NOSENDINTEST', 'test without send');
is ($t->{msg},  "No 'send' directive was found in stanza ending at t/corpus/parser08.txt line 7", 'no send');
$p = Firepear::Catechesis::Parser->new(tests => 't/corpus/parser09.txt');
$t = $p->yield;
is ($t->{type}, 'error', 'error');
is ($t->{code}, 'NOEXPECTINTEST', 'test without expect');
is ($t->{msg},  "No 'expect' directive was found in stanza ending at t/corpus/parser09.txt line 8", 'no expect');
