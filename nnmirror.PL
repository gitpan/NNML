#!/app/unido-i06/magic/perl
#                              -*- Mode: Perl -*- 
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
print OUT <<'!NO!SUBS!';
#                              -*- Mode: Perl -*- 
# nnmirror -- 
# ITIID           : $ITI$ $Header $__Header$
# Author          : Ulrich Pfeifer
# Created On      : Sun Sep 29 11:50:11 1996
# Last Modified By: Ulrich Pfeifer
# Last Modified On: Thu Oct 17 09:34:57 1996
# Language        : CPerl
# Update Count    : 42
# Status          : Unknown, Use with caution!
# 
# (C) Copyright 1996, Universität Dortmund, all rights reserved.
# 
# $Locker$
# $Log$
# 
!NO!SUBS!

# In the following, perl variables are not expanded during extraction.

print OUT <<'!NO!SUBS!';
eval 'exec perl -S $0 "$@"'
    if 0;
        
eval 'exec perl -S $0 "$@"'
    if 0;
        
eval 'exec perl -S $0 "$@"'
    if 0;

BEGIN {$0 = 'nnmirror ....'; }
use Getopt::Long;
use Time::Local;
require News::NNTPClient;
use NNML::Config qw($Config);
use strict;
use vars qw(%OPT);
sleep 100;
%OPT = (
        fhost   => $Config->mirror_host,
        fpass   => $Config->remote_passwd,
        fport   => $Config->mirror_port,
        fuser   => $Config->remote_user,
        thost   => 'localhost',
        tpass   => $Config->local_passwd,
        tport   => $Config->port,
        tuser   => $Config->local_user,
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
           'only=s',
           'ignore=s',
           'reverse!',
           'verbose!',
          ) or die;

if ($OPT{'reverse'}) {
  @OPT{qw(fhost fpass fport fuser thost tpass tport tuser)} =
    @OPT{qw(thost tpass tport tuser fhost fpass fport fuser)};
}
if ($OPT{verbose}) {
  for (keys %OPT) {
    printf "%-15s = %s\n", $_, $OPT{$_};
  }
}
exit;
my $time;
if (exists $OPT{date}) {
  $time = to_time($OPT{date}, $OPT{'time'})
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

# Check if we can use gzip mode
if ($to->command("MODE GZIP")) {
  $from->command("MODE GZIP");
}
$to->command("SLAVE");
my @msgid = $from->newnews($group, $time);
my $togo = scalar(@msgid );
my $msgid;

foreach $msgid (@msgid) {
  $togo--;
  chomp($msgid);
  next unless $msgid;           # sanity check
  next if exists $OPT{ignore} and $msgid =~ /$OPT{ignore}/o;
  next if exists $OPT{only}   and $msgid !~ /$OPT{only}/o;
  if ($to->command("IHAVE $msgid")) {
    print STDERR "$togo: FETCH $msgid";
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
[B<-reverse>]
[B<-only> I<regexp>]
[B<-ignore> I<regexp>]
[B<-group> I<group expression>] ...

=head1 DESCRIPTION

B<Nnmirror> connects a B<FROM> and a B<TO> server using
B<News::NNTPClient>. It asks the B<FROM> server for new articles using
the C<NEWNEWS> command. For each returned message-id, the B<TO> server
is asked using C<IHAVE>. If B<TO> wants the article, it is fetched
from B<FROM> and forwarded to B<TO>.

With respect to the configuration, the I<"normal"> oeration is polling
from a remote server. It you specify B<-reverse> the roles of the are
reversed and an upload is perlformed. For uploading to a real NNTP
server you should use the B<-only> I<regexp> option with an rexexp,
which matches the message ids your system generates.


The date/time for the B<NEWNEWS> command defaults to the current time
minus one day.

After connecting the servers, an B<AUTHHINFO> request is send if the
options B<-fpasswd> or B<-tpasswd> are given.

=head1 EXAMPLES

Assuming you are at your linux box 'C<hobbit>' at home. Your box in
the office is called 'C<sun44>', your NNTP-Server 'B<news>'. On
'C<sun44>' you have a NNML server running on port 3000 with user
'C<lwall>' passwd 'C<foo>'. On your linux box, you run the NNML server
at port 2000 without authorisation.

=head2 Fetch mail from office

  nnmirror -fhost sun44 -fport 3000 -fuser lwall -fpasswd foo \
           -thost localhost -fpasswd '' -tport 2000

=head2 Write back the carbon copies you generated

  nnmirror -fhost sun44 -fport 3000 -fuser lwall -fpasswd foo \
           -thost localhost -fpasswd '' -tport 2000 \
           -reverse -only /hhobbit/

=head2 Get some news from the NNTP server

  nnmirror -fhost news -fport 119 -fpasswd '' \
           -thost localhost -fpasswd '' -tport 2000 \
           -group comp.lang.perl.* -group \!*.misc

=head2 Forward your postings

  nnmirror -fhost news -fport 119 -fpasswd '' \
           -thost localhost -fpasswd '' -tport 2000 \
           -reverse -only /hobbit/

For real use, you may better set the right defaults during
configuration and only give the passwords n the command line.

=head1 AUTHOR

Ulrich Pfeifer E<lt>F<pfeifer@ls6.informatik.uni-dortmund.de>E<gt>




!NO!SUBS!

close OUT or die "Can't close $file: $!";
chmod 0755, $file or die "Can't reset permissions for $file: $!\n";
exec("$Config{'eunicefix'} $file") if $Config{'eunicefix'} ne ':';
