#! /bin/perl
#############################################################################
#
#                 NOTE: This file under revision control using RCS
#                       Any changes made without RCS will be lost
#
#              $Source: /usr/local/cvsroot/vbtk/VBTK/Actions.pm,v $
#            $Revision: 1.2 $
#                $Date: 2002/01/21 17:07:40 $
#              $Author: bhenry $
#              $Locker:  $
#               $State: Exp $
#
#              Purpose: A common perl library used to define and trigger actions
#                       based on pmserver object statuses
#
#          Description: This perl library is used by the pmserver process to
#                       define and trigger actions based on the status of objects
#           defined on the pmserver process.
#
#           Directions:
#
#           Invoked by: pmserver
#
#           Depends on: VBTK::Common.pm, Date::Manip
#
#       Copyright (C) 1996 - 2002  Brent Henry
#
#       This program is free software; you can redistribute it and/or
#       modify it under the terms of version 2 of the GNU General Public
#       License as published by the Free Software Foundation available at:
#       http://www.gnu.org/copyleft/gpl.html
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
#       $Log: Actions.pm,v $
#       Revision 1.2  2002/01/21 17:07:40  bhenry
#       Disabled 'uninitialized' warnings
#
#       Revision 1.1.1.1  2002/01/17 18:05:56  bhenry
#       VBTK Project
#
#       Revision 1.9  2002/01/04 10:52:40  bhenry
#       Revision 1.8  2002/01/04 10:40:35  bhenry
#       Improvements during vacation.

package VBTK::Actions;

use 5.6.1;
use strict;
use warnings;
# I like using undef as a value so I'm turning off the uninitialized warnings
no warnings qw(uninitialized);

use VBTK::Common;
use Date::Manip;

our $VERSION = '0.01';

our %PENDING_QUEUE;
our @LOG_ACTION_LIST;
our %ACTION_LIST;
our $VERBOSE=$ENV{VERBOSE};

#-------------------------------------------------------------------------------
# Function:     new
# Description:  Object constructor.  Allocates memory for all class members
# Input Parms:  Configuration filename
# Output Parms: Pointer to class
#-------------------------------------------------------------------------------
sub new
{
    my $type = shift;
    my $self = {};
    bless $self, $type;

    # Store all passed input name pairs in the object
    $self->set(@_);
    $self->{messages} = [];

    &log("Creating new action '$self->{Name}'") if ($VERBOSE);

    $ACTION_LIST{$self->{Name}} = $self;

    return $self;
}

#-------------------------------------------------------------------------------
# Function:     getAction
# Description:  Retrieve the action object associated with the specified name
# Input Parms:  Action name
# Output Parms: Object
#-------------------------------------------------------------------------------
sub getAction
{
    my $name = shift;

    $ACTION_LIST{$name};
}

#-------------------------------------------------------------------------------
# Function:     add_message
# Description:  Add a message to an action to be executed at a later time
# Input Parms:  Object name, status, object text
# Output Parms: None
#-------------------------------------------------------------------------------
sub add_message
{
    my $obj = shift;

    my ($fullName,$status,$url) = @_;
    my $SendUrl       = $obj->{SendUrl};
    my $Execute       = $obj->{Execute};
    my $SubActionList = $obj->{SubActionList};
    my $Name          = $obj->{Name};
    my $LogActionFlag = $obj->{LogActionFlag};
    my ($message,$subAction);

    # Forming message to be sent
    $message = "$fullName - $status";

    # Only include the URL in the message if the SendURL option was specified
    $message .= ($SendUrl) ? "\n$url\n" : ", ";
    &log("Adding message '$message' to action '$Name'") if ($VERBOSE > 1);

    # Add the message to the queue of messages to be sent out the next time the
    # action is triggered.  Only add the message if this action has a command
    # to execute.
    push(@{$obj->{messages}},$message) if ($Execute ne '');

    # Step through each sub-action, passing along the parameters.
    foreach $subAction (@{$SubActionList})
    {
        $subAction->add_message($fullName,$status,$url);
    }

    # If the LogAction parm was specified, then add it to the action log.
    if ($LogActionFlag)
    {
        VBTK::LogActionList::add($fullName,$status,$url,$obj);
    }

    # Mark this action as pending execution
    $PENDING_QUEUE{$obj} = $obj;
    (0);
}

#-------------------------------------------------------------------------------
# Function:     triggerAll
# Description:  Attempt to trigger all pending actions.
# Input Parms:  None
# Output Parms: None
#-------------------------------------------------------------------------------
sub triggerAll
{
    my($action,$actionKey);

    foreach $actionKey (keys %PENDING_QUEUE)
    {
        $action = $PENDING_QUEUE{$actionKey};
        $action->trigger();
    }
    (0);
}

#-------------------------------------------------------------------------------
# Function:     trigger
# Description:  Check the time window and frequency limits and if okay, fork off
#               a process to execute the specified action.
# Input Parms:  None
# Output Parms: None
#-------------------------------------------------------------------------------
sub trigger
{
    my $obj = shift;
    my $Name = $obj->{Name};

    &log("Checking action '$Name' for messages") if ($VERBOSE > 2);

    # Check for messages.  If none, then just return
    my $message = join('',@{$obj->{messages}});
    return 0 if ($message eq '');

    my $limit = $obj->{LimitToEvery};
    my $nextAllowedOccurrence = $obj->{nextAllowedOccurrence};
    my $Execute = $obj->{Execute};

    my ($pid,$ret_code,$now);

    &log("Checking occurence limit") if ($VERBOSE > 1);
    $now = &ParseDate('today');

    if(($nextAllowedOccurrence ne '')&&($now lt $nextAllowedOccurrence))
    {
        &log("Ignoring trigger of action '$Name'") if ($VERBOSE > 1);
        &log("Next occurrence allowed at '$nextAllowedOccurrence'")
            if ($VERBOSE > 1);
        return 0;
    }

    $obj->{nextAllowedOccurrence} = &DateCalc($now,$limit);

    &log("Triggering action '$Name'") if ($VERBOSE > 1);

    &log("Executing '$Execute'");
    open(EXEC, "| $Execute") || &error("Cannot exec '$Execute'");
    print EXEC $message;
    close(EXEC);

    # An error code can appear in either the lower or the higher byte of $?.
    # By or-ing the lower byte with the upper byte, we get an accurate error code.
    $ret_code = ($? & 0xFF) | ($? >> 8);

    &log("Command exited with return code '$ret_code'.") if ($ret_code);

    &log("Clearing all messages out of action '$Name'") if ($VERBOSE > 1);
    @{$obj->{messages}} = ();

    # Remove object from the pending queue
    delete $PENDING_QUEUE{$obj};

    (0);
}

1;
__END__

=head1 NAME

VBTK::Actions - Action definitions used by the VBTK::Server daemon

=head1 SUPPORTED PLATFORMS

=over 4

=item * 

Solaris

=back

=head1 SYNOPSIS

  $t = new VBTK::Actions (
    Name         => 'emailMe',
    Execute      => 'mailx -s Warning me@nowhere.com',
    LimitToEvery => '10 min',
    SendUrl      => 1
 );

=head1 DESCRIPTION

The VBTK::Actions class is used to define actions to be taken by the 
L<VBTK::Server|VBTK::Server> daemon.  At the moment, it just executes a 
command line command, but eventually there will be additional abilities, such
as sending email directly to an SMTP server, etc.

=head1 METHODS

The following methods are supported

=over 4

=item $s = new VBTK::Actions (<parm1> => <val1>, <parm2> => <val2>, ...)

The allows parameters are:

=over 4

=item Name

A unique string identifying this action.  This still will be used in lists
of 'StatusChangeActions' passed to a L<VBTK::Server|VBTK::Server> daemon

=item Execute

A string to be executed on the command line when the action is triggered. 
For example:

    Execute => 'mailx -s Warning me@nowhere.com'

=item LimitToEvery

A time expression used to limit the number of times the action can be
triggered within a window of time.  The expression will be evaluated by the
L<Date::Manip|Date::Manip> class, so it can be just about any recognizable
time or date expression.  For example: '10 min' or '1 day'.

=item SendUrl

A boolean setting to indicate whether a URL should be passed to STDIN of
the command line which will provide a way for the user to jump right to
the offending object.  You would usually enable this (1) for email 
notifications, but disable it (0) for pager notifications.

=back

=head1 SUB-CLASSES

The following sub-classes were created to provide common defaults in the use
of VBTK::Actions objects.

=over 4

=item L<VBTK::Actions::Email|VBTK::Actions::Email>

Defaults for sending an email as an action.

=item L<VBTK::Actions::Page|VBTK::Actions::Page>

Defaults for sending an email to a pager as an action

=back

Others are sure to follow.  If you're interested in adding your own sub-class,
just copy and modify some of the existing ones.  Eventually, I'll get around
to documenting this better.

=head1 SEE ALSO

=over 4

=item L<VBTK::Server|VBTK::Server>

=item L<VBTK::Parser|VBTK::Parser>

=item L<VBTK::Templates|VBTK::Templates>

=back

=head1 AUTHOR

Brent Henry, vbtoolkit@yahoo.com

=head1 COPYRIGHT

Copyright (C) 1996-2002 Brent Henry

This program is free software; you can redistribute it and/or
modify it under the terms of version 2 of the GNU General Public
License as published by the Free Software Foundation available at:
http://www.gnu.org/copyleft/gpl.html

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

=cut
