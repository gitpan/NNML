#                              -*- Mode: Perl -*- 
# Group.pm -- 
# ITIID           : $ITI$ $Header $__Header$
# Author          : Ulrich Pfeifer
# Created On      : Sat Sep 28 16:33:51 1996
# Last Modified By: Ulrich Pfeifer
# Last Modified On: Sun Sep 29 12:51:19 1996
# Language        : CPerl
# Update Count    : 30
# Status          : Unknown, Use with caution!
# 
# (C) Copyright 1996, Universität Dortmund, all rights reserved.
# 
# $Locker$
# $Log$
# 

package NNML::Group;
use IO::File;
use strict;

sub new {
  my $type = shift;
  my %parm = @_;
  my $self = {};

  for (qw(name dir min max post ctime)) {
    $self->{'_'.$_} = $parm{$_} if exists $parm{$_};
  }
  $self->{_time} = 0;
  bless $self, $type;
}

sub max   { $_[0]->_update; $_[0]->{_max}};
sub min   { $_[0]->_update; $_[0]->{_min}};
sub name  { $_[0]->_update; $_[0]->{_name}};
sub post  { $_[0]->_update; $_[0]->{_post}};
sub ctime { $_[0]->_update; $_[0]->{_ctime}};
sub add   { $_[0]->_update; $_[0]->{_max}++; $_[0]->{_max}}
sub dir   { $_[0]->_update; $_[0]->{_dir}};


sub article_by_id {
  my ($self, $msgid) = @_;

  $self->_update;
  $self->{_byid}->{$msgid};
}

sub article_by_no {
  my ($self, $ano) = @_;

  $self->_update;
  $self->{_byno}->{$ano};
}

sub overview {$_[0]->{_dir}. '/.overview'}

sub _update {
  my $self = shift;
  my $mtime = (stat($self->overview))[9];

  $self->_read_overview if $mtime > $self->{_time};
}

sub _read_overview {
  my $self = shift;
  $self->{_time}  = time;
  $self->{_byid}  = {};
  $self->{_byno}  = {};
  $self->{_ctime} = (stat($self->overview))[9];
  my $fh = new IO::File "<" . $self->overview;
  die "Could not read overview file" unless defined $fh;
  my $line;
  while (defined ($line = <$fh>)) {
    chomp($line);
    my($ano, $subject, $from, $date, $id, $references, $chars, $lines, $xref)
      = split /\t/, $line;
    $id =~ s/^\s+//; $id =~ s/\s+$//;
    $self->{_byid}->{$id}  = $ano;
    $self->{_byno}->{$ano} = $id;
  }
  $fh->close;
}

# This assumes that articles are stored in increasing order.
# It deserves tuning (binary search).
sub newnews {
  my ($self, $time) = @_;
  my @result;
  
  $self->_update;
  return () if $self->{_ctime} < $time;
  my $ano;
  my $dir = $self->{_dir}.'/';
  for ($ano=$self->max;$ano>=$self->min;$ano--) {
    my $file = $dir.$ano;
    if (-e $file) {
      my $ctime = (stat($file))[9];
      if ($ctime >= $time) {
        push @result, $self->{_byno}->{$ano};
      } else {
        last;
      }
    }
  }
  @result;
}

sub xover {
  my ($self,$min,$max) = @_;
  my $result;

  $min ||= $self->min;
  $max ||= $self->max;
  my $fh = new IO::File "<" . $self->overview;
  die "Could not read overview file" unless defined $fh;
  my $line;
  while (defined ($line = <$fh>)) {
    if ($line =~ /^(\d+)/) {
      if ($1 >= $min and $1 <= $max) {
        $result .= $line;
      }
    }
  }
  $fh->close;
  $result;
}

sub get {
  my ($self, $ano) = @_;
  my $file = $self->{_dir} . "/$ano";
  if (-e $file) {
    my $fh = new IO::File "<" . $file;
    return unless $fh;
    my $head = '';
    my $body = '';
    my $line;
    
    while (defined ($line = <$fh>)) {
      last if $line =~ /^$/;
      $head .= $line;
    }
    while (defined ($line = <$fh>)) {
      $body .= $line;
    }
    return $head, $body;
  }
}

1;
