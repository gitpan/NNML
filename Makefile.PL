#                              -*- Mode: Perl -*- 
# Makefile.PL -- 
# ITIID           : $ITI$ $Header $__Header$
# Author          : Ulrich Pfeifer
# Created On      : Sat Sep 28 13:51:19 1996
# Last Modified By: Ulrich Pfeifer
# Last Modified On: Thu Oct 17 11:49:36 1996
# Language        : CPerl
# Update Count    : 41
# Status          : Unknown, Use with caution!
# 
# (C) Copyright 1996, Universität Dortmund, all rights reserved.
# 
# $Locker$
# $Log$
# 

use ExtUtils::MakeMaker qw(:DEFAULT neatvalue);
use File::Path;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

WriteMakefile(
              'CONFIGURE'    => \&init,
              'PREREQ_PM'    => {
                                 'IO::File'   => 0,
                                 'IO::Select' => 0,
                                 'IO::Socket' => 1.13
                                },
              'NAME'	     => 'NNML',
              'VERSION_FROM' => 'NNML/Server.pm',
              'dist'         => { SUFFIX => "gz", COMPRESS => "gzip -f"},
              'EXE_FILES'    => [qw(nnmirror overview)],
              'clean'        => {FILES => "nnmirror overview"},
             );

# Code shamelessly stolen from the CPAN Makefile.PL by Andreas Koenig
sub init {
    use Config;
    eval {require NNML::Config;};
    $Config = $NNML::Config::Config || {};
    
    print qq{

The NNML module needs a directory of its own to store the databases.
This directory may be relative to the executing users home
directory. Use '~/' to indicate this.

};

    my $base = $Config->{base} || '~/Mail';
    $Config->{base} = prompt("NNML base directory?", $base);

    print qq{

NNML uses an active file to store summary information about the
newsgroups. This is usually '$base/active'. You may abbreviate '$base'
by '~' in which case the current base setting is used.

};
    my $active = $Config->{active} || MM->catfile ('~', 'active');
    $Config->{active} = prompt("NNML active file?", $active);


    print qq{

NNML implements a basic authorisation using passwords. Where should
the password file be stored?  This is usually '$base/passwd'.  You may
abbreviate '$base' by '~'.

};
    my $passwd = $Config->{passwd} || MM->catfile ('~', 'passwd');
    $Config->{passwd} = prompt("NNML passwd file?", $passwd);

    print qq{

Which port should the server listen perl default? This is usually 119.

};
    my $port = $Config->{port} || 119;
    $Config->{port} = prompt("NNML default port?", $port);

    print qq{

Since the server will run as a single thread it needs some timeout value to
decide when an POST or IHAVE request should be interrupted. Otherwise
all connections would be blocked.

};

    my $timeout = $Config->{timeout} || 30;
    $Config->{timeout} = prompt("Timeout in seconds?", $timeout);

    print qq{

Nnmirror fetches articles completely befor sending it to the receiving
server. You may want to specify a larger value for the timeout for it
when you mirror over a modem line.

};
    my $mtimeout = $Config->{mirror_timeout} || 3 * $Config->{timeout};
    $Config->{mirror_timeout} = prompt("Mirror timeout in seconds?", $mtimeout);

    print qq{

If you intend to use nnmirror, what is the default host you want to
mirror from/to.

};
    
    my $mirrorhost = $Config->{mirror_host} || $ENV{NNTPSERVER};
    $Config->{mirror_host} = prompt("Default mirror host?", $mirrorhost);

    my $mirrorport  = $Config->{mirror_port} || 119;
    $Config->{mirror_port} = prompt("Default mirror port?", $mirrorport);

    print qq{

If you intend to use nnmirror and either your server or the mirror
server use authentication, it may be convenient to specify default
users for them. Use '~' if the executing users login name should be
used. Note that no authorisation is used unless you provide the
passwords, so specifying user names allone will not trigger
authorisation in nnmirror. Enter 'none' if you do not want to define a
default user.

};

    my $ruser = $Config->{remote_user} || '~';
    $Config->{remote_user} = prompt("Default user on remote server?",
                                          $ruser);
    
    $Config->{remote_user} = '' if $Config->{remote_user} eq 'none';
    my $luser = $Config->{local_user} || '~';
    $Config->{local_user} = prompt("Default user on local server?",
                                          $luser);
    $Config->{local_user} = '' if $Config->{local_user} eq 'none';
    print qq{

We will ask you also for the corresponding passwords. You should
provide them ONLY IF NOBODY ELSE has access to your box.

You should better enter them on the command line when running
nnmirror.

};

    my $rpasswd = $Config->{remote_passwd} || '';
    $Config->{remote_passwd} = prompt("Default passwd on remote server?",
                                          $rpasswd);
    
    my $lpasswd = $Config->{local_passwd} || '';
    $Config->{local_passwd} = prompt("Default passwd on local server?",
                                          $lpasswd);
    
    my $configpmdir = MM->catdir(qw/NNML/);
    mkpath $configpmdir;
    my $configpm = MM->catfile( qw/NNML Config.pm/ ); 

    open FH, ">$configpm" or die "Couldn't open >$configpm: $!";
    while (<DATA>) {
      last if /^\$Config/;
      print FH;
    }
    print FH qq[\$Config = bless \{\n];
    foreach (sort keys %$Config) {
	printf FH "  %-15s => %s,\n", "'$_'", neatvalue($Config->{$_});
    }

    print FH "}, 'NNML::Config';\n";
    while (<DATA>) {
      print FH;
    }
    close(FH);
}
__END__
#                              -*- Mode: Perl -*- 
# Config.pm -- 
# ITIID           : $ITI$ $Header $__Header$
# Author          : Ulrich Pfeifer
# Created On      : Sat Sep 28 13:53:36 1996
# Last Modified By: Ulrich Pfeifer
# Last Modified On: Mon Sep 30 08:55:23 1996
# Language        : CPerl
# Update Count    : 11
# Status          : Unknown, Use with caution!
# 
# (C) Copyright 1996, Universität Dortmund, all rights reserved.
# 
# $Locker$
# $Log$
# 

package NNML::Config;

use strict;
use vars qw($VERSION @ISA @EXPORT_OK $Config);

require Exporter;

@ISA = qw(Exporter);

@EXPORT_OK = qw(
                $Config
               );

$VERSION = '0.01';


$Config = bless {}, 'NNML::Config';

sub local_user {
  my $self = shift;
  my $user;

  if (defined $user) {
    $self->{local_user} = $user;
    delete $self->{_local_user};
  }
  return $self->{_local_user} if exists $self->{_local_user};
  if ($self->{local_user} eq '~') {
    my $user = $ENV{'USER'} || $ENV{'LOGNAME'} || getpwuid($<);
    $self->{_local_user} = $user;
  } else {
    $self->{_local_user} = $self->{local_user};
  }
  $self->{_local_user};
}

sub remote_user {
  my $self = shift;
  my $user;

  if (defined $user) {
    $self->{remote_user} = $user;
    delete $self->{_remote_user};
  }
  return $self->{_remote_user} if exists $self->{_remote_user};
  if ($self->{remote_user} eq '~') {
    my $user = $ENV{'USER'} || $ENV{'LOGNAME'} || getpwuid($<);
    $self->{_remote_user} = $user;
  } else {
    $self->{_remote_user} = $self->{remote_user};
  }
  $self->{_remote_user};
}

sub home {
  my $self = shift;

  return $self->{_home} if exists $self->{_home};
  my $user = $ENV{'USER'} || $ENV{'LOGNAME'} || getpwuid($<);
  my $home = (getpwnam($user))[7];
  $self->{_home} = $home;
}

sub base {
  my $self = shift;
  my $base = shift;

  if (defined $base) {
    $self->{base} = $base;
    delete $self->{_base};
    delete $self->{_active};
    delete $self->{_passwd};
  }
  return $self->{_base} if exists $self->{_base};
  $self->{_base} = $self->{base};
  $self->{_base} =~ s/^~/$self->home/e;
  $self->{_base};
}

sub active {
  my $self   = shift;
  my $active = shift; 
  if (defined $active) {
    $self->{active} = $active;
    delete $self->{_active};
  }
  return $self->{_active} if exists $self->{_active};
  $self->{_active} = $self->{active};
  $self->{_active} =~ s/^~/$self->base/e;
  $self->{_active};
}

sub passwd {
  my $self = shift;
  my $passwd = shift;
  if (defined $passwd) {
    $self->{passwd} = $passwd;
    delete $self->{_passwd};
  }
  return $self->{_passwd} if exists $self->{_passwd};
  $self->{_passwd} = $self->{passwd};
  $self->{_passwd} =~ s/^~/$self->base/e;
  $self->{_passwd};
}

sub AUTOLOAD {
  my $func = $NNML::Config::AUTOLOAD; $func =~ s/.*:://;
  my $self = shift;
  my $val  = shift;
  if (defined $val) {
    $self->{$func} = $val;
    return $val;
  } else {
    if (exists $self->{$func}) {
      return $self->{$func};
    } else {
      return undef;
    }
  }
}

1;

