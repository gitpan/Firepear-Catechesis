package MathAPI;

use warnings;
use strict;

# it's far easier to be OO than not
sub new {
  my ($class, %args) = @_;
  return bless {}, $class;
}


# simple methods which implement the API
sub add {
  my ($self, @operands) = @_;
  my $err = $self->_validate_operands('add', 2, @operands);
  return $err if $err;
  return $operands[0] + $operands[1];
}

sub subtract {
  my ($self, @operands) = @_;
  my $err = $self->_validate_operands('subtract', 2, @operands);
  return $err if $err;
  return $operands[0] - $operands[1];
}

sub multiply {
  my ($self, @operands) = @_;
  my $err = $self->_validate_operands('multiply', 2, @operands);
  return $err if $err;
  return $operands[0] * $operands[1];
}

sub divide {
  my ($self, @operands) = @_;
  my $err = $self->_validate_operands('divide', 2, @operands);
  return $err if $err;
  return "Division by zero is undefined" if ($operands[1] == 0);
  return $operands[0] / $operands[1];
}

# error handling, except for divide-by-zero
sub _validate_operands {
  my ($self, $command, $expected, @operands) = @_;
  my $i = 0;
  for my $operand (@operands) {
    return "Missing operand: $command requires $expected; I found $i"
      unless (defined $operand);
    $i++;

    return "Non-integer operand found: $operand"
      if ($operand =~ /\D/);
  }
  return "Missing operand: $command requires $expected; I found $i"
    unless ($i == $expected);

  return 0;
}

1;
