#!/usr/bin/env perl

# Basic math service for Catechesis, in Perl 5

# Since this is implementing the example API, which is so simple, this
# program is actually a shim as well as the implementation. I will
# rewrite it soon to be a standalone shim interfacing with an
# implementation.

# See ../docs/math_api.html for more information

use warnings;
use strict;
use JSON;

$| = 1; # ensure autoflush/unbuffered mode on STDOUT!
        # if you don't do this, you'll deadlock


# Initialize the dispatch table and answer hashref
my $cmds = { add      => \&add,
             subtract => \&subtract,
             multiply => \&multiply,
             divide   => \&divide,
             quit     => 1 };
my $answer = { command => '', result => '' };


while (<STDIN>) {
  # reset answer bits
  $answer->{command} = '';
  $answer->{result}  = '';
  delete $answer->{err_msg};

  # vivify input
  my $msg = decode_json($_);

  # "no command" error handler
  unless ($msg->{command}) {
    $answer->{result}  = "ERROR";
    $answer->{err_msg} = "No command found. Invalid message";
    print encode_json($answer),"\n";
    next;
  }

  $answer->{command} = $msg->{command};

  # "bad command" error handler
  unless ( $cmds->{$msg->{command}} ) {
    $answer->{result}  = "ERROR";
    $answer->{err_msg} = "Unknown command: $msg->{command}";
    print encode_json($answer),"\n";
    next;
  }

  # shutdown handler
  exit if $msg->{command} eq 'quit';

  # bad ops err handling
  unless ($msg->{operands}) {
    $answer->{result}  = "ERROR";
    $answer->{err_msg} = "Missing operand: $msg->{command} requires 2; I found 0";
    print encode_json($answer),"\n";
    next;
  }
  unless (ref $msg->{operands} eq "ARRAY") {
    $answer->{result}  = "ERROR";
    $answer->{err_msg} = "The value of operands must be usable as a list";
    print encode_json($answer),"\n";
    next;
  }
  unless (@{$msg->{operands}} == 2) {
    my $numops = @{$msg->{operands}};
    $answer->{result}  = "ERROR";
    $answer->{err_msg} = "Missing operand: $msg->{command} requires 2; I found $numops";
    print encode_json($answer),"\n";
    next;
  }
  for my $operand ( @{$msg->{operands}} ) {
    if ($operand =~ /\D/) {
      $answer->{result}  = "ERROR";
      $answer->{err_msg} = "Non-integer operand found: $operand";
      print encode_json($answer),"\n";
    }
  }
  next if $answer->{result} eq "ERROR";
  if ($msg->{command} eq 'divide' and $msg->{operands}[1] == 0) {
    $answer->{result}  = "ERROR";
    $answer->{err_msg} = "Division by zero is undefined";
    print encode_json($answer),"\n";
    next;
  }

  # okay, then, let's do it.
  $cmds->{$msg->{command}}->($msg, $answer);
  print encode_json($answer),"\n";
}

sub add {
  my ($msg, $answer) = @_;
  $answer->{result} = $msg->{operands}[0] + $msg->{operands}[1];
}

sub subtract {
  my ($msg, $answer) = @_;
  $answer->{result} = $msg->{operands}[0] - $msg->{operands}[1];
}

sub multiply {
  my ($msg, $answer) = @_;
  $answer->{result} = $msg->{operands}[0] * $msg->{operands}[1];
}

sub divide {
  my ($msg, $answer) = @_;
  $answer->{result} = $msg->{operands}[0] / $msg->{operands}[1];
}
