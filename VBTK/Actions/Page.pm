#############################################################################
#
#                 NOTE: This file under revision control using RCS
#                       Any changes made without RCS will be lost
#
#              $Source: /usr/local/cvsroot/vbtk/VBTK/Actions/Page.pm,v $
#            $Revision: 1.2 $
#                $Date: 2002/01/21 17:07:44 $
#              $Author: bhenry $
#              $Locker:  $
#               $State: Exp $
#
#              Purpose: An extension of the VBTK::Actions library which defaults
#                       to common settings used in creating a page action.
#
#           Depends on: VBTK::Common, VBTK::Actions
#
#       Copyright (C) 1996-2002  Brent Henry
#
#       This program is free software; you can redistribute it and/or
#       modify it under the terms of version 2 of the GNU General Public
#       License as published by the Free Software Foundation available at:
#       http://http://www.gnu.org/copyleft/gpl.html
#
#       This program is distributed in the hope that it will be useful,
#       but WITHOUT ANY WARRANTY; without even the implied warranty of
#       MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#       GNU General Public License for more details.
#
#############################################################################
#
#
#       REVISION HISTORY:
#
#       $Log: Page.pm,v $
#       Revision 1.2  2002/01/21 17:07:44  bhenry
#       Disabled 'uninitialized' warnings
#
#       Revision 1.1.1.1  2002/01/17 18:05:57  bhenry
#       VBTK Project

package VBTK::Actions::Page;

use 5.6.1;
use strict;
use warnings;
# I like using undef as a value so I'm turning off the uninitialized warnings
no warnings qw(uninitialized);

use VBTK::Common;
use VBTK::Actions;

our $VERBOSE = $ENV{VERBOSE};

#-------------------------------------------------------------------------------
# Function:     new
# Description:  Object constructor.  Allocates memory for all class members
# Input Parms:
# Output Parms: Pointer to class
#-------------------------------------------------------------------------------
sub new
{
    my $type = shift;
    my $self = {};
    bless $self, $type;

    # Store all passed input name pairs in the object
    $self->set(@_);

    # Set common defaults
    $self->{Execute}  = "mailx $self->{Email}"
        if (($self->{Execute} eq undef)&&($self->{Email} ne undef));

    # Setup a hash of default parameters
    my $defaultParms = {
        Name          => $::REQUIRED,
        Email         => undef,
        Execute       => $::REQUIRED,
        SendUrl       => 0,
        LimitToEvery  => '10 min'
    };

    # Run a validation on the passed parms, using the default parms        
    $self->validateParms($defaultParms);

    # Initialize a wrapper object.
    $self->{actionObj} = new VBTK::Actions(%{$self}) || return undef;

    # Store the defaults for later
    $self->{defaultParms} = $defaultParms;

    ($self);
}

1;
__END__

=head1 NAME

VBTK::Actions::Page - A sub-class of VBTK::Actions for sending pager notifications

=head1 SUPPORTED PLATFORMS

=over 4

=item * 

Solaris

=back

=head1 SYNOPSIS

  $t = new VBTK::Actions::Page (
    Name         => 'pageMe',
    Email        => 'page.me@nowhere.com' );

=head1 DESCRIPTION

The VBTK::Actions::Page is a simple sub-class off the VBTK::Actions class.
It is used to define an pager notification action.  It accepts many of the
same paramters as VBTK::Actions, but will appropriately default most if 
not specified.

=head1 METHODS

The following methods are supported

=over 4

=item $s = new VBTK::Actions (<parm1> => <val1>, <parm2> => <val2>, ...)

The allows parameters are:

=over 4

=item Name

See L<VBTK::Actions> (required)

=item Email

The pager email address to be notified when this action is triggered. (required)

=item LimitToEvery

See L<VBTK::Actions> (defaults to '10 min')

=item SendUrl

See L<VBTK::Actions> (defaults to 0)

=back

=head1 SEE ALSO

VBTK::Server
VBTK::ClientObject

=head1 AUTHOR

Brent Henry, vbtoolkit@yahoo.com

=head1 COPYRIGHT

Copyright (C) 1996-2002 Brent Henry

This program is free software; you can redistribute it and/or
modify it under the terms of version 2 of the GNU General Public
License as published by the Free Software Foundation available at:
http://http://www.gnu.org/copyleft/gpl.html

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

=cut
