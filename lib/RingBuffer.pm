package RingBuffer;
#
# Written by Travis Kent Beste
# Tue Oct 28 10:38:33 CDT 2008
#
# $Id: RingBuffer.pm 5 2008-11-04 00:55:08Z travis $

use 5.008008;
use strict;
use warnings;

require Exporter;

use Carp;
our $AUTOLOAD;  # it's a package global

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use RingBuffer ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(
	
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
	
);

our $VERSION = ( qw$Revision: 5 $ )[1];

=head1 NAME

RingBuffer - Perl extension for creating a ring buffer of any size with any object as the ring data.

=head1 SYNOPSIS

  use RingBuffer;
  my $r = new RingBuffer();

  # initialize the ring, in this case with an array
  my $buffer = [];
  my $ringsize = 256;
  $r->ring_init(
    Buffer => $buffer,
    RingSize => $ringsize
  ); # will create 256 ring buffer of array objects

  # remove an object from the ring
  my $obj = $r->ring_remove();

  # add an object to the front of the ring
  # this is usually used for putting items back on the ring
  $r->ring_add_to_front($obj);

  # peek at the next item on the ring
  my $obj = $r->ring_peek();

  # clear out the ring, also zeros out the data
  $r->ring_clear();

=cut

=head1 DESCRIPTION

This software create a ring buffer of E<lt>nE<gt> length.  You can store any type of 
object inside the buffer that you create.  Description of the functions are listed below:

=over 4

=cut


sub new {
	my $class = shift;
	my %args  = @_; 

	my %fields = (
		buffer         => undef,
		size           => 0,
		head           => 0,
		tail           => 0,
	);

	my $self = {
		%fields,
		_permitted => \%fields,
	};
	bless $self, $class;
      
	return $self;
} 

sub AUTOLOAD {
	my $self = shift;
	my $type = ref($self) or croak "$self is not an object";

	my $name = $AUTOLOAD;
	$name =~ s/.*://;   # strip fully-qualified portion

	unless (exists $self->{_permitted}->{$name} ) {
		croak "Can't access `$name' field in class $type";
	}

	if (@_) {
		return $self->{$name} = shift;
	} else {
		return $self->{$name};
	}
}

sub DESTROY {
	my $self = shift;

	$self->SUPER::DESTROY if $self->can("SUPER::DESTROY");
}

#----------------------------------------#
# private functions
#----------------------------------------#

#--------------------#
# Calculate the next value for the ring head index.
#--------------------#
sub _ring_next_head {
	my $self = shift;
  my $next_head = 0;

	# Get next value for head, and wrap if necessary.
	$next_head = $self->head + 1;

	if ($next_head >= $self->size) {
		$next_head = 0;
	}

	return($next_head);
}

#--------------------#
# Calculate the next value for the ring tail index.
#--------------------#
sub _ring_next_tail {
	my $self = shift;
  my $next_tail = 0;

	# Get next value for tail, and wrap if necessary.
	$next_tail = $self->tail + 1;

	if ($next_tail >= $self->size) {
		$next_tail = 0;
	}

	return($next_tail);
}

#----------------------------------------#
# public functions
#----------------------------------------#

=item $r->ring_init();

	Initialize the ring with your object passed to the
the 'Buffer=><obj>' argument.

=cut
#--------------------#
# Initialize a ring buffer.
#--------------------#
sub ring_init {
	my $self = shift;
	my %args = @_;

	# Set the buffer size.
	$self->size($args{'RingSize'});

	# Set the buffer type
	if ($args{'Buffer'} =~ /array/i) {
		for(my $i = 0; $i < $self->size(); $i++) {
			$self->{buffer}[$i] = 0;
		}
	} else {
		# the object type
		$args{'Buffer'} =~ /(.*)=/;
		my $type = $1;

		# first import (like 'use <module_name>') but doesn't need to be bareword
		import $type;

		# now call new for the array of objects
		for(my $i = 0; $i < $self->size(); $i++) {
			$self->{buffer}[$i] = $type->new();
		}
	}

	# Clear the ring buffer.
	$self->ring_clear();

	return 1;
}

=item $r->ring_clear();

	Clear the ring of all objects.

=cut
#--------------------#
# Clear the ring buffer and indices.
#--------------------#
sub ring_clear {
	my $self = shift;

	for(my $i = 0; $i < $self->size; $i++) {
		if (${$self->buffer}[$i] == 0) {
			${$self->buffer}[$i] = 0;
		} else {
			${$self->buffer}[$i]->clear();
		}
	}

	$self->head(0);
	$self->tail(0);
}

=item $r->ring_add();

	Add an object to the buffer of the ring.

=cut
#--------------------#
# Add a byte to the ring buffer.
#--------------------#
sub ring_add {
	my $self      = shift;
	my $data      = shift;
	my $next_head = 0;
	my $next_tail = 0;

	# Check for room in the ring buffer.
	$next_head = $self->_ring_next_head();

	# this is the case where we've wrapped around and
	# the tail needs to stay ahead of the head as we
	# drop bytes from the buffer
	if ( ($self->ring_size == ($self->size - 1) ) ) {
		$next_tail = $self->_ring_next_tail();
		$self->tail($next_tail);
	}

	# Add data to buffer and increase the head index.
	${$self->buffer}[$self->head] = $data;
	$self->head($next_head);

	return 1;
}

=item $r->ring_remove();

	Remove an object from the ring and return it.

=cut
#--------------------#
# Remove a data byte from the ring buffer. If no data, returns 0.
#--------------------#
sub ring_remove {
	my $self = shift;
	my $data = 0;

	# Check for any data in the ring buffer.
	if($self->head != $self->tail) {
		# Remove data byte.
		$data = ${$self->buffer}[$self->tail];

		# zero out the byte when it gets removed, only for development, not for production
		${$self->buffer}[$self->tail] = 0;

		# Get next value for ring tail index, wrap if necessary.
		$self->tail($self->tail + 1);
		if($self->tail >= $self->size) {
			$self->tail(0);
		}
	}

	return($data);
}

=item $r->ring_size();

	Return the size of the ring, takes into account the wrapping
around of the ring.

=cut
#--------------------#
# get the ring size
#--------------------#

sub ring_size {
	my $self = shift;

	if ( ($self->head) < ($self->tail) ) {
		# wrap around
		return ( ($self->head) + ($self->size) - ($self->tail) );
	} else {
		return ( ($self->head) - ($self->tail) );
	}
}


=item $r->ring_add_to_front();

	Add a piece of data to the front of the ring

=cut
#--------------------#
# add a byte to the front of the ring
#--------------------#
sub ring_add_to_front {
	my $self      = shift;
	my $data      = shift;
	my $next_tail = 0;

	# Check for room in the ring buffer.
	$next_tail = $self->tail;
	if ($next_tail > 0) {
		$next_tail--;
	} else {
		$next_tail = $self->size - 1;
	}

	if($next_tail != $self->head) {
		# Add data to buffer and increase the head index.
		${$self->buffer}[$next_tail] = $data;
		$self->tail($next_tail);
	}

	return 1;
}

=item $r->ring_change();

	Change a piece of data in the ring at the current head location.

=cut
#--------------------#
# change a piece of data in the ring
#--------------------#
sub ring_change {
	my $self          = shift;
	my $data          = shift;
	my $previous_head = 0;

	# Check for any data in the ring buffer.
	if($self->head == $self->tail) {
		return;
	}

	if ($self->head > 0) {
		$previous_head = $self->head - 1;
	} else {
		$previous_head = $self->size - 1;
	}

	${$self->buffer}[$previous_head] = $data;
}

=item $r->ring_peek();

	Take a look at the item on the ring to be returned,
but do not remove it from the ring.

=cut
#--------------------#
# peek at a byte in the ring buffer
#--------------------#
sub ring_peek {
	my $self = shift;
  my $data = 0;

	# Check for any data in the ring buffer.
	if($self->head != $self->tail) {
		# Remove data byte.
		$data = ${$self->buffer}[$self->tail];
	}

	return($data);
}

=item $r->ring_print();

	Print the contents of the ring.  Could be a huge printout
if you make the ring size large.

=cut
#--------------------#
# print contents of the buffer
#--------------------#
sub ring_print {
	my $self = shift;

	printf "size:%02d ", $self->ring_size();
	printf "head:%02d ", $self->head;
	printf "tail:%02d ", $self->tail;
	print "| ";
	for(my $r_cntr = 0; $r_cntr < $self->size; $r_cntr++) {
		printf "%02x ", ${$self->buffer}[$r_cntr];
	}
	print "\n";

	return 1;
}

1;

__END__

=back

=head2 EXPORT

None by default.

=head1 BUGS

None that I know of right now.

=head1 SEE ALSO

perl(1).

I also have a website where you can find the latest versions of this software:

=over 4

=item http://www.travisbeste.com/software/perl/RingBuffer

=back

=head1 AUTHOR

Please e-mail me with problems, bug fixes, comments and complaints.

Travis Kent Beste, E<lt>travis@tencorners.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2008 by Travis Kent Beste

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.


=cut

