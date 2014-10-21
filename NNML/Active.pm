#                              -*- Mode: Perl -*- 
# Active.pm -- 
# ITIID           : $ITI$ $Header $__Header$
# Author          : Ulrich Pfeifer
# Created On      : Sat Sep 28 14:15:22 1996
# Last Modified By: Ulrich Pfeifer
# Last Modified On: Thu Oct 17 12:13:26 1996
# Language        : CPerl
# Update Count    : 72
# Status          : Unknown, Use with caution!
# 
# (C) Copyright 1996, Universit�t Dortmund, all rights reserved.
# 
# $Locker: pfeifer $
# $Log: Active.pm,v $
# Revision 1.1  1996/10/17 07:53:58  pfeifer
# Initial revision
#
# 

package NNML::Active;

use strict;
use vars qw($VERSION @ISA @EXPORT_OK $ACTIVE);
require Exporter;
@ISA = qw(Exporter);
@EXPORT_OK = qw($ACTIVE);

use NNML::Config qw($Config);
use NNML::Group;
use IO::File;
use File::Path;

$VERSION = '0.01';
$ACTIVE = bless {}, 'NNML::Active';

my %GROUP;
my $TIME = 0;

sub _read_active {
  %GROUP  = ();
  $TIME   = time;

  my $fh = new IO::File "<" . $Config->active;
  die "Could not read active file" unless defined $fh;
  my $line;
  while (defined ($line = <$fh>)) {
    chomp($line);
    my ($group, $max, $min, $post) = split ' ', $line;
    my $dir = $group;
    $dir =~ s:\.:/:g;
    $dir = $Config->base . '/' . $dir;
    if (-e $dir) {
      my $ctime = (stat($dir))[10];
      $GROUP{$group} = NNML::Group->new(name  => $group,
                                        dir   => $dir,
                                        min   => $min,
                                        max   => $max,
                                        post  => $post,
                                        ctime => $ctime,
                                       );
    }
  }
}

sub _write_active {
  my $active = $Config->active;

  unless (rename $active, "$active~") {
    print "Could not backup '$active': $!\n";
    return 0;
  }
  my $fh = new IO::File ">" . $active;
  unless (defined $fh) {
    print "Could not write active file\n";
    return 0;
  }
  for (sort keys %GROUP) {
    $fh->printf("%s %d %d %s\n", $_,
                $GROUP{$_}->max, $GROUP{$_}->min, $GROUP{$_}->post,
               )
  }
  $fh->close;
  $TIME   = time;
}

sub _update {
  my $mtime = (stat($Config->active))[9];
  _read_active if $mtime > $TIME;
}

sub group {
  my ($self, $group) = @_;

  _update;
  if (exists $GROUP{$group}) {
    return $GROUP{$group};
  } 
}

sub delete_group {
  my ($self, $group) = @_;
  my $dir;

  _update;
  unless (exists $GROUP{$group}) {
    return;
  } else {
    $dir = $GROUP{$group}->dir;
    delete $GROUP{$group};
  }
  _write_active;
  rmtree($dir,1,1);
}
sub groups {
  _update;
  values %GROUP;
}

sub newgroups {
  my ($self, $time) = @_;
  my @result;

  _update;
  for (keys %GROUP) {
    # printf "%s %d %d\n", $_, $GROUP{$_}->ctime, $time;
    if ($GROUP{$_}->ctime > $time) {
      unshift @result, $_;
    }
  }
  @result;
}

sub list_match {
  my ($self, $expr) = @_;

  $expr =~ s/\./\\./g;
  $expr =~ s/\*/.*/g;
  my (@expr) = split /,/, $expr;

  _update;

  my $neg = join '|', grep s/^!//, @expr;
  my $pos = join '|', grep /^[^!]/, @expr;

  #print "pos = $pos\n";
  #print "neg = $neg\n";

  my @result;
  for (sort keys %GROUP) {
    next unless /^$pos$/;
    next if /^$neg$/;
    push @result, $GROUP{$_};
  }

  @result;
}

sub accept_article {
  my ($self, $header, $head, $body, $create, @groups) = @_;
  my $group;
  my $afile;
  my $any_group = 0;
  
  $self->_update;
  for $group (@groups) {
    unless (exists $GROUP{$group}) {
      next unless $create;      # no permission to create group
      my $dir = $group;
      $dir =~ s:\.:/:g;
      $dir = $Config->base . '/' . $dir;
      unless (-d $dir) {
        unless (mkpath($dir,1,0700)) {
          print "Could not mkpath($dir).\n";
          return 0;
        }
      }
      $GROUP{$group} = NNML::Group->new(name  => $group,
                                        dir   => $dir,
                                        min   => 1,
                                        max   => 0,
                                        post  => 'y',
                                        ctime => time,
                                       );
    }
    my $ov   = $GROUP{$group}->overview;
    my $oano = $GROUP{$group}->article_by_id($header->{'message-id'});
    my $ano  = $oano || $GROUP{$group}->add;
    my $dir  = $GROUP{$group}->dir;
    my $file = "$dir/$ano";

    if (!$oano and -e $file) {
      print "File '$file' already exists\n";
      return 0;
    }

    unless ($oano) {            # do not overwrite .overwiev ...
      my $fh  = new IO::File ">> $ov";
      unless (defined $fh) {
        print "Could not write '$ov': $!\n";
        return 0;
      }
      $header->{subject} =~ s/\s/ /;
      $fh->printf("%d\t%s\t%s\t%s\t%s\t%s\t%d\t%s\t%s\t\n",
                  $ano,
                  $header->{subject}, 
                  $header->{from},
                  $header->{date},
                  $header->{'message-id'},
                  $header->{references},
                  length($body),
                  $header->{lines},
                  $header->{xref});
      $fh->close;
    }
    if (defined $afile) {
      unless ($oano or link($afile, $file)) {
        print "Could not link '$file' to '$afile': $!\n";
        return 0;
      }
    } else {
      $afile = $file;
      my $fh  = new IO::File "> $file";
      unless (defined $fh) {
        print "Could not write '$file': $!\n";
        return 0;
      }
      $fh->print($head, "\n", $body);
      $fh->close;
    }
    $any_group++;               # we posted to one group atleast
  }
  return $self->_write_active || $any_group;
}

1;
