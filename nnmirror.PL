#!/usr/local/bin/perl

use Config;
use File::Basename qw(&basename &dirname);

# List explicitly here the variables you want Configure to
# generate.  Metaconfig only looks for shell variables, so you
# have to mention them as if they were shell variables, not
# %Config entries.  Thus you write
#  $startperl
# to ensure Configure will look for $Config{startperl}.

# This forces PL files to create target in same directory as PL file.
# This is so that make depend always knows where to find PL derivatives.
chdir(dirname($0));
($file = basename($0)) =~ s/\.PL$//;
$file =~ s/\.pl$//
	if ($^O eq 'VMS' or $^O eq 'os2');  # "case-forgiving"

open OUT,">$file" or die "Can't create $file: $!";

print "Extracting $file (with variable substitutions)\n";

# In this section, perl variables will be expanded during extraction.
# You can use $Config{...} to use Configure variables.

print OUT <<"!GROK!THIS!";
$Config{'startperl'}
!GROK!THIS!

# In the following, perl variables are not expanded during extraction.

print OUT <<'!NO!SUBS!';
eval 'exec perl -S $0 "$@"'
    if 0;

#                              -*- Mode: Perl -*- 
# nnmirror -- 
# ITIID           : $ITI$ $Header $__Header$
# Author          : Ulrich Pfeifer
# Created On      : Sun Sep 29 11:50:11 1996
# Last Modified By: Ulrich Pfeifer
# Last Modified On: Tue Oct  1 08:20:03 1996
# Language        : CPerl
# Update Count    : 30
# Status          : Unknown, Use with caution!
# 
# (C) Copyright 1996, Universität Dortmund, all rights reserved.
# 
# $Locker$
# $Log$
# 

use Getopt::Long;
use Time::Local;
require News::NNTPClient;
use strict;
use vars qw(%OPT);

%OPT = (
        fhost => 'localhost',
        fport => 3000,
        thost => 'localhost',
        tport => 3002,
        tuser => $ENV{LOGNAME},
        fuser => $ENV{LOGNAME},
        tpass => '',
        fpass => '',
       );

GetOptions(\%OPT,
           'fhost=s',
           'thost=s',
           'fport=i',
           'tport=i',
           'date=i',
           'time=i',
           'tuser=s',
           'fuser=s',
           'tpass=s',
           'fpass=s',
           'group=s@',
          ) or die;

my $time;
if (exists $OPT{date}) {
  $time = to_time($OPT{date}, $OPT{time})
} else {
  $time = time - 3600 * 24;
}

my $group;
if (exists $OPT{group}) {
  $group = join ',', @{$OPT{group}}
} else {
  $group = '*',
}

my $from = new News::NNTPClient $OPT{fhost}, $OPT{fport};
my $to   = new News::NNTPClient $OPT{thost}, $OPT{tport};

if ($OPT{tpass}) {
  $to->authinfo($OPT{tuser}, $OPT{tpass});
}
if ($OPT{fpass}) {
  $from->authinfo($OPT{fuser}, $OPT{fpass});
}
die unless defined $from and defined $to;

my $msgid;
foreach $msgid ($from->newnews($group, $time)) {
  chomp($msgid);
  next unless $msgid;
  if ($to->command("IHAVE $msgid")) {
    print STDERR "FETCH $msgid";
    my @art = $from->article($msgid);
    printf STDERR " %d lines ", scalar(@art);
    @art = ('head', '', 'body') unless @art;
    #$to->{DBUG} = 2;
    $to->squirt(@art);
    print STDERR "done\n";
  }
}

sub to_time {
  my ($date, $time, $gmt) = @_;

  return unless defined $date;
  if (length($date)<8) {
    $date =~ m/^(\d\d)/;
    if ($1 > 80) {
      $date = "19$date";          # not strictly RCS 977
    } else {
      $date = "20$date";          # not strictly RCS 977
    }
  }
  unless (defined $time) {
    $time = "000000";
  }

  $date .= $time;
  my ($year,$mon,$mday,$hours,$min,$sec) =
    ($date =~ m/^(\d\d\d\d)(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)$/);
  return unless defined $sec;

  my $ltime;
  $mon--;
  if (defined $gmt) {
    eval { $ltime = timegm($sec,$min,$hours,$mday,$mon,$year) };
  } else {
    eval { $ltime = timelocal($sec,$min,$hours,$mday,$mon,$year)};
  }
  return if $@ ne '';
  return $ltime;
}

__END__


=head1 NAME

nnmirror - update an nntp server with respect to another server

=head1 SYNOPSIS

B<nnmirror>
[B<-fhost> I<hostname]
[B<-thost> I<hostname]
[B<-fport> I<port>]
[B<-tport> I<port>]
[B<-fuser> I<user>]
[B<-fpass> I<passwd>]
[B<-tuser> I<user>]
[B<-tpass> I<passwd>]
[B<-date>  I<yymmdd>]
[B<-time>  I<hhmmss>]
[B<-group> I<group expression>] ...

=head1 DESCRIPTION

B<Nnmirror> connects a B<FROM> and a B<TO> server using
B<News::NNTPClient>. It asks the B<FROM> server for new articles using
the C<NEWNEWS> command. For each returned message-id, the B<TO> server
is asked using C<IHAVE>. If B<TO> wants the article, it is fetched
from B<FROM> and forwarded to B<TO>.

The date/time for the B<NEWNEWS> command defaults to the current time
minus one day.

After connecting the servers, an B<AUTHHINFO> request is send if the
options B<-fpasswd> or B<-tpasswd> are given. The B<-tuser> and
B<-fuser> options default to C<$ENV{LOGNAME}>.

=head1 EXAMPLES

 nnmirror -fhost $NNTPSERVER -fport 119 -thost localhost -tport 9000 \
   -group comp.lang.perl.\* -group \!\*misc

=head1 AUTHOR

Ulrich Pfeifer E<lt>F<pfeifer@ls6.informatik.uni-dortmund.de>E<gt>
!NO!SUBS!

close OUT or die "Can't close $file: $!";
chmod 0755, $file or die "Can't reset permissions for $file: $!\n";
exec("$Config{'eunicefix'} $file") if $Config{'eunicefix'} ne ':';
