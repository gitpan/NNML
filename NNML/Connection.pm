#                              -*- Mode: Perl -*- 
# Connection.pm -- 
# ITIID           : $ITI$ $Header $__Header$
# Author          : Ulrich Pfeifer
# Created On      : Sat Sep 28 15:24:53 1996
# Last Modified By: Ulrich Pfeifer
# Last Modified On: Mon Sep 30 11:56:25 1996
# Language        : CPerl
# Update Count    : 142
# Status          : Unknown, Use with caution!
# 
# (C) Copyright 1996, Universität Dortmund, all rights reserved.
# 
# $Locker$
# $Log$
# 
package NNML::Connection;
use NNML::Active qw($ACTIVE);
use Text::Abbrev;
use Time::Local;
use Socket;
use strict;
use Sys::Hostname;
require NNML::Auth;

use vars qw(%ACMD %CMD %MSG %HELP);

my $HOST = hostname;
{
  no strict;
  local *stab = *NNML::Connection::;
  my ($key,$val);
  while (($key,$val) = each(%stab)) {
    next unless $key =~ /^cmd_(.*)/;
    local(*ENTRY) = $val;
    if (defined &ENTRY) {
      $CMD{$1} = \&ENTRY;
    }
  }
}

abbrev(*ACMD, keys %CMD);

sub new {
  my $type = shift;
  my $fh   = shift;
  my $msg  = shift;
  my $self = {_fh => $fh};
  
  my $hersockaddr = $fh->peername();
  my ($port, $iaddr) = unpack_sockaddr_in($hersockaddr);
  my $peer = gethostbyaddr($iaddr, AF_INET);
  $self->{_peer} = $peer;

  print "Connection from $peer\n";
  bless $self, $type;
  $self->msg(200, $msg);
  $self;
}

sub close {
  my $self = shift;

  $self->{_fh}->close;
}

sub dispatch {
  my $self = shift;
  my $cmd  = shift;

  print "$cmd @_\n";
  unless (exists $ACMD{$cmd}) {
    $self->msg(500);
  } else {
    if (NNML::Auth::perm($self, $ACMD{$cmd})) {
      &{$CMD{$ACMD{$cmd}}}($self, @_);
    } else {
      $self->msg(480);
    }
  }
  return $ACMD{$cmd};
}

sub msg {
  my $self = shift;
  my $code = shift;
  my $msg  = $MSG{$code} || '';
  printf("%03d $msg\r\n", $code, @_);
  $self->{_fh}->printf("%03d $msg\r\n", $code, @_);
}

sub end {
  my $self = shift;
  $self->{_fh}->autoflush(1);
  $self->{_fh}->print(".\r\n");
}

sub output {
  my $self = shift;

  for (@_) {
    s/^\./../mg;
    $self->{_fh}->print($_);
  }
}


sub cmd_help {
  my $self = shift;

  $self->msg(100);
  for (sort keys %CMD) {
    $self->output(sprintf("%-15s %s\r\n", $_, $HELP{$_}||''));
  }
  $self->end;
}

sub cmd_authinfo {
  my ($self, $cmd, $arg) = @_;

  if (uc($cmd) eq  'USER') {
    $self->{_user}   = $arg;
    unless (exists $self->{_passwd}) {
      $self->msg(381);
      return;
    }
  } elsif (uc($cmd) eq 'PASS') {
    $self->{_passwd} = $arg;
    unless (exists $self->{_user}) {
      $self->msg(382);
      return;
    }
  } else {
    $self->msg(501);
    return;
  }
  
  if (NNML::Auth::check($self->{_user}, $self->{_passwd})) {
    $self->msg(281)
  } else {
    $self->msg(482);
    delete $self->{_passwd};
  }
}

sub cmd_group {
  my ($self, $groupname) = @_;
  my $group = $ACTIVE->group($groupname);

  unless ($group) {
    $self->msg(411);
    return;
  }
  my $max = $group->max;
  my $min = $group->min;

  $self->{_group}   = $group;
  $self->{_article} = $min;
  $self->msg(211, $max-$min+1, $min, $max, $groupname);
}

sub cmd_mode {
  my $self = shift;
  my $mode = shift;

  $self->msg(280, $mode);
}

sub cmd_quit {
  my $self = shift;
  $self->msg(205);
}

sub cmd_list {
  my $self = shift;

  $self->msg(215);
  for ($ACTIVE->groups) {
    $self->{_fh}->printf("%s %d %d %s\r\n", $_->name, $_->max, $_->min, $_->post)
  }
  $self->end;
}

sub cmd_newgroups {
  my $self = shift;
  my $ltime = to_time(@_);
  
  unless (defined $ltime) {
    $self->msg(501);
    return;
  }
  # print "[$date] ($year,$mon,$mday,$hours,$min,$sec)\n $ltime\n";
  $self->msg(235);
  for ($ACTIVE->newgroups($ltime)) {
     $self->{_fh}->print($_, "\r\n");
  }
  $self->end;
}

sub cmd_newnews {
  my $self  = shift;
  my $match = shift;
  my $ltime = to_time(@_);
  my %msgid;
  
  $self->msg(230);
  for ($ACTIVE->list_match($match)) {
    #$self->{_fh}->printf("** %s\r\n", $_->name);
    for ($_->newnews($ltime)) {
      $msgid{$_}++;
    }
  }
  for (keys %msgid) {
    $self->{_fh}->print($_, "\r\n");
  }
  $self->end;
}

sub cmd_xover {
  my $self = shift;
  my $parm = shift;
  my @range = ($parm =~ m/(\d+)-(\d+)/);
  unless ($self->{_group}) {
    $self->msg(412);
    return;
  }
  my $xover = $self->{_group}->xover(@range);
  $self->msg(224);
  $self->output("$xover");
  $self->end;
}

sub cmd_next {
  my $self = shift;
  unless ($self->{_group}) {
    $self->msg(412);
    return;
  }
  unless ($self->{_article}) {
    $self->msg(420);
    return;
  }
  if ($self->{_article} < $self->{_group}->max) {
    $self->{_article}++;
  } else {
    $self->msg(421);
    return;
  }
  $self->msg(223, $self->{_article},
             $self->{_group}->article_by_no($self->{_article}))
}

sub cmd_last {
  my $self = shift;
  unless ($self->{_group}) {
    $self->msg(412);
    return;
  }
  unless ($self->{_article}) {
    $self->msg(420);
    return;
  }
  if ($self->{_article} > $self->{_group}->min) {
    $self->{_article}--;
  } else {
    $self->msg(422);
    return;
  }
  $self->msg(223, $self->{_article},
             $self->{_group}->article_by_no($self->{_article}))
}

sub cmd_slave {
  my $self = shift;
  $self->msg(202);
}

# only article number for is supported
sub cmd_stat {
  my $self = shift;
  my $ano  = shift;

  unless (defined $ano) {
    $self->msg(501);
    return;
  }
  unless ($self->{_group}) {
    $self->msg(412);
    return;
  }
  if ($ano >= $self->{_group}->min and $ano <= $self->{_group}->max) {
    $self->{_article} = $ano;
  } else {
    $self->msg(423);
    return;
  }
  $self->msg(223, $self->{_article},
             $self->{_group}->article_by_no($self->{_article}))
}

sub cmd_article { my $self = shift; $self->article('article', join ' ', @_)};
sub cmd_head    { my $self = shift; $self->article('head',    join ' ', @_)};
sub cmd_body    { my $self = shift; $self->article('body',    join ' ', @_)};

sub article {
  my ($self, $cmd, $parm) = @_;
  if (defined $parm and $parm =~ /^<.*>$/) {
    my ($head, $body) = $self->article_msgid($parm);
    if ($head) {
      if ($cmd eq 'article') {
        $self->msg(220,0,$parm);
        $self->output($head, "\n", $body);
      } elsif ($cmd eq 'head') {
        $self->msg(221,0,$parm);
        $self->output($head);
      } else {
        $self->msg(222,0,$parm);
        $self->output($body);
      }
      $self->end;
    } else {
      $self->msg(430);
    }
  } else {
    unless ($self->{_group}) {
      $self->msg(412);
      return;
    }
    my $ano = $parm || $self->{_article};
    unless ($ano) {
      $self->msg(420);
      return;
    }

    my ($head, $body) = $self->{_group}->get($ano);
    my ($msgid) = ($head =~ /^Message-Id:\s*(<\S+>)/m);
    if ($head) {
      $self->{_article} = $ano;
      if ($cmd eq 'article') {
        $self->msg(220,$ano, $msgid);
        $self->output($head, "\n", $body);
      } elsif ($cmd eq 'head') {
        $self->msg(221,$ano, $msgid);
        $self->output($head);
      } else {
        $self->msg(222,$ano, $msgid);
        $self->output($body);
      }
      $self->end;
    } else {
      $self->msg(423);
    }
  }
}

sub post {1;}                   # tbs
sub cmd_ihave {
  my ($self, $msgid) = @_;

  unless ($self->post) {
    $self->msg(437);
    return;
  }
  if ($self->article_msgid($msgid)) {
    $self->msg(435);
    return;
  }
  $self->msg(335);
  $self->accept_article($msgid);
}

sub cmd_post {
  my $self = shift;

  unless ($self->post) {
    $self->msg(440);
    return;
  }
  $self->msg(340);
  $self->accept_article();
}


sub accept_article {
  my ($self, $msgid) = @_;
  my %head = (
              subject         => '',
              from            => '',
              date            => '',
              'message-id'    => $msgid || '',
              references      => '',
              lines           => 0,
              xref            => '',
              'x-nnml-groups' => '',
              newsgroups      => '',
             );
  my $header;
  my $fh = $self->{_fh};
  my $art   = '';
  my $block = '';
  my $retries = 9;
  while ($art !~ /\r?\n\.\r?\n$/) {
    #print STDERR "[$block]";
    if ($fh->sysread($block, 512)) {
      $art .= $block;
    } else {
      last if $retries -- < 0;
      print STDERR "Waiting \n";
      sleep(1);
    }
  }
  $art =~ s/\r//g;
  $art =~ s/.\n$//;
  my ($head, $body) = split /^$/m, $art, 2;

  for (split /\n/, $head) {
    if (/^(\S+):\s*(.*)/) {
      my $h = lc $1;
      if (exists $head{$h}) {
        $header = $h;
        $head{$h} = $2;
      } else {
        $header = undef;
      }
    } elsif ($header and /^\s+(.*)/) {
      $head{$header} .= ' ' . $2;
    }
  }
  unless ($head{lines}) {
    $head{lines} = ($body =~ m/(\n)/g);
  }
  unless ($head{'message-id'}) {
    $head{'message-id'} = sprintf "<%d\@unknown%s>", time, $HOST;
    $head .= "Message-Id: $head{'message-id'}\n";
  }
  for (keys %head) {
    printf "%-15s %s\n", $_, $head{$_} if $head{$_};
  }
  my @newsgroups = split /,\s*/, $head{'x-nnml-groups'};
  unless (@newsgroups) {
    @newsgroups = split /,\s*/, $head{newsgroups};
  }
  unless (@newsgroups) {
    $self->msg(441);
    return;
  }
  if ($self->article_msgid($head{'message-id'})) {
    print "POSTER lied about 'message-id'}\n";
    $self->msg(441);
    return;
  }
  unless ($ACTIVE->accept_article(\%head, $head, $body, @newsgroups)) {
    $self->msg(441);
    return;
  }
  $self->msg(240);
}

sub article_msgid {
  my ($self, $msgid) = @_;
  my $group;
  my %ano;
  my ($head, $body);
  my @newsgroups;
  
  for $group ($ACTIVE->groups) {
    my $ano = $group->article_by_id($msgid);
    if (defined $ano) {
      #printf "%s %d\n", $group->name, $ano;
      push @newsgroups, $group->name;
      $ano{$group} = $ano;
      unless (defined $head) {
        ($head, $body) = $group->get($ano);
      }
    }
  }
  return unless $head;
  $head =~ s/^X-nnml-groups:.*\n//mig;
  my $newsgroups = sprintf("X-nnml-groups: %s\n", join(', ', @newsgroups));
  return $head . $newsgroups, $body;
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


# read status message
my $line;
while (defined ($line = <DATA>)) {
  chomp($line);
  my ($cmd, $msg) = split ' ', $line, 2;
  last unless $cmd;
  $HELP{$cmd} = $msg;
}
while (defined ($line = <DATA>)) {
  chomp($line);
  next unless $line =~ /^\d/;
  my ($code, $msg) = split ' ', $line, 2;
  $MSG{$code} = $msg;
}


1;

__DATA__
authinfo user Name|pass Password
article [MessageID|Number]
body [MessageID|Number]
date
group newsgroup
head [MessageID|Number]
help
ihave MessageID
last
list [active|newsgroups|distributions|schema]
listgroup newsgroup
mode reader
newgroups yymmdd hhmmss ["GMT"] [<distributions>]
newnews newsgroups yymmdd hhmmss ["GMT"] [<distributions>]
next
post
slave
stat [MessageID|Number]
xgtitle [group_pattern]
xhdr header [range|MessageID]
xover [range]
xpat header range|MessageID pat [morepat...]
xpath xpath MessageID

200 NNML server %s ready - posting allowed
201 NNML server %s ready - no posting allowed
202 slave status noted
280 mode %s noted (x)
205 closing connection - goodbye!
211 %d %d %d %s group selected
215 list of newsgroups follows
220 %d %s article retrieved - head and body follow
221 %d %s article retrieved - head follows
222 %d %s article retrieved - body follows
223 %d %s article retrieved - request text separately 230 list of new articles by message-id follows
230 list of new articles by message-id follows
231 list of new newsgroups follows
224 overview follows
235 article transferred ok
240 article posted ok
281 Authentication accepted

335 send article to be transferred.  End with <CR-LF>.<CR-LF>
340 send article to be posted. End with <CR-LF>.<CR-LF>
381 PASS required
482 USER required

400 service discontinued
411 no such news group
412 no newsgroup has been selected
420 no current article has been selected
421 no next article in this group
422 no previous article in this group
423 no such article number in this group
430 no such article found
435 article not wanted - do not send it
436 transfer failed - try again later
437 article rejected - do not try again.
440 posting not allowed
441 posting failed
480 Authentication required: %s
482 Authentication rejected

500 command not recognized
501 command syntax error
502 access restriction or permission denied
503 program fault - command not performed
