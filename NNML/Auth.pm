#!/app/unido-i06/magic/perl
#                              -*- Mode: Perl -*- 
# Auth.pm -- 
# ITIID           : $ITI$ $Header $__Header$
# Author          : Ulrich Pfeifer
# Created On      : Mon Sep 30 08:49:41 1996
# Last Modified By: Ulrich Pfeifer
# Last Modified On: Tue Oct  1 08:20:38 1996
# Language        : CPerl
# Update Count    : 20
# Status          : Unknown, Use with caution!
# 
# (C) Copyright 1996, Universität Dortmund, all rights reserved.
# 
# $Locker$
# $Log$
# 

package NNML::Auth;
use NNML::Config qw($CONF);
use IO::File;
use strict;

my $NORESTRICTION = 0;
my (%PASSWD, %PERM);

if (-e $CONF->passwd) {
  my $fh = new IO::File '< ' . $CONF->passwd;
  if (defined $fh) {
    local ($_);
    while (<$fh>) {
      chomp;
      my($user, $passwd, @perm) = split;
      $PASSWD{$user} = $passwd;
      my %perm;
      @perm{@perm} = @perm;
      $PERM{$user} = \%perm;
    }
  } else {
    $NORESTRICTION = 1;
  }
} else {
  $NORESTRICTION = 1;
}

sub perm {
  my ($con, $command) = @_;

  return 1 if $NORESTRICTION;
  return 1 if $command =~ /HELP|QUIT|AUTHINFO|MODE|SLAVE/i;
  return 0 unless $con->{_user};
  return 0 unless $con->{_passwd};

  unless (check($con->{_user}, $con->{_passwd})) {
    # just paranoid
    return 0;
  }
  if ($command =~ /SHUT|CREATE/i) {
    return $PERM{$con->{_user}}->{'admin'};
  }
  if ($command =~ /POST|IHAVE/i) {
    return $PERM{$con->{_user}}->{'write'};
  }
  return $PERM{$con->{_user}}->{'read'};
}

sub check {
  my ($user, $passwd) = @_;

  return 0 unless exists $PASSWD{$user};
  my $salt = substr($PASSWD{$user},0,2);
  return (crypt($passwd, $salt) eq $PASSWD{$user});
}

sub add_user {
  my ($user, $passwd, @perm) = @_;
  my @cs = ('a'..'z', 'A'..'Z', '0'..'9','.','/');
  srand(time);

  my $salt = $cs[rand(64)] . $cs[rand(64)];
  my $cpasswd = crypt($passwd, $salt);
  my $fh = new IO::File '>>' . $CONF->passwd;
  if (defined $fh) {
    $fh->print("$user $cpasswd @perm\n");
    $fh->close;
  } else {
    print "Could not write '%s': $!\n", $CONF->passwd;
    return 0;
  }
  return 1;
}

if ($NORESTRICTION) {
  print "Authorization disabled\n";
}

1;
