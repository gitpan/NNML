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
use vars qw($VERSION @ISA @EXPORT_OK $CONF);

require Exporter;

@ISA = qw(Exporter);

@EXPORT_OK = qw(
                $CONF
               );

$VERSION = '0.01';


$CONF = bless {}, 'NNML::Config';

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
    $self->{_base} = $base;
  }
  return $self->{_base} if exists $self->{_base};
  $self->{_base} = $self->home . '/Mail';
}

sub active {
  my $self = shift;

  return $self->{_active} if exists $self->{_active};
  $self->{_active} = $self->base . '/active';
}

sub passwd {
  my $self = shift;
  my $passwd = shift;
  if (defined $passwd) {
    $self->{_passwd} = $passwd;
    return $passwd;
  }
  return $self->{_passwd} if exists $self->{_passwd};
  $self->{_passwd} = $self->base . '/passwd';
}

1;

