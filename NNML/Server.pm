#                              -*- Mode: Perl -*-
# Base.pm --
# ITIID           : $ITI$ $Header $__Header$
# Author          : Ulrich Pfeifer
# Created On      : Sat Sep 28 13:53:36 1996
# Last Modified By: Ulrich Pfeifer
# Last Modified On: Tue Nov  5 11:02:54 1996
# Language        : CPerl
# Update Count    : 93
# Status          : Unknown, Use with caution!
#
# (C) Copyright 1996, Universit�t Dortmund, all rights reserved.
#
# $Locker$
# $Log$
#

package NNML::Server;
use vars qw($VERSION @ISA @EXPORT);
use NNML::Connection;
use NNML::Config qw($Config);
use IO::Socket;
use IO::Select;
use strict;
require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(server);

$VERSION = do{my @r=(q$Revision: 1.09 $=~/(\d+)/g);sprintf "%d."."%02d"x$#r,@r};

sub server {
  my %opt  = @_;
  my $port = $opt{port} || $Config->port;

  if (exists $opt{base}) {
    $Config->base($opt{base});
  }
  NNML::Auth::_update;          # just for the message
  my $lsn  = new IO::Socket::INET(Listen    => 5,
                                  LocalPort => $port,
                                  Proto     => 'tcp');
  die "Could not connect to port $port" unless defined $lsn;
  my $SEL  = new IO::Select( $lsn );
  my %CON;
  my $fh;
  my @ready;

  print "listening on port $port\n";
  
  while(@ready = $SEL->can_read) {
    foreach $fh (@ready) {
      if($fh == $lsn) {
        # Create a new socket
        my $new = $lsn->accept;
        $new->autoflush(1);
        $CON{$new} = new NNML::Connection $new, $VERSION;
        $SEL->add($new);
      } else {
        #my $cmd = $fh->getline();
        my $cmd;
        sysread($fh, $cmd, 512);
        for (split /\r?\n/, $cmd) {
          my ($func, @args) = split ' ', $_;

          $func = lc $func;
          if ($func eq 'shut') {
            if (NNML::Auth::perm($CON{$fh}, $func)) {
              my $fx;
              print "Going down\n";
              for $fx (keys %CON) {
                $CON{$fx}->msg(400);
                #$SEL->remove($fx);
                $CON{$fx}->close;
                delete $CON{$fx};
              }
              #$SEL->remove($lsn);
              shutdown($lsn,2);
              return;
            } else {
              $CON{$fh}->msg(480);
              next;
            }
          }
          $func = $CON{$fh}->dispatch($func, @args);
          if ($func eq 'quit') {
            print "closed\n";
            $SEL->remove($fh);
            $CON{$fh}->close;
            delete $CON{$fh};
          }
        }
      }
    }
  }
}

1;

__END__

=head1 NAME

NNML::Server - a minimal NNTP server

=head1 SYNOPSIS

  perl -MNNML::Server -e 'server()'

=head1 DESCRIPTION

B<NNML::Server> server implements a minimal NNTP server. It is (hope-)
fully conformant to rfc977. In addition the commands C<XOVER> and
C<AUTHINFO> are implemented.

Supported commands:

  ARTICLE, AUTHINFO, BODY, GROUP, HEAD, HELP, IHAVE, LAST, LIST,
  MODE, NEWGROUPS, NEWNEWS, NEXT, POST, QUIT, SLAVE, STAT, XOVER

The main reason for writing this was to synchronize my mail directories
across different hosts. The Mail directories are MH-Style with a F<.overview>
file in each folder and an F<active> file in the base
directory. These are maintained by the B<Emacs> B<Gnus> backend
B<NNML>. To get started, you can generate/update this files using the
B<overview> program. Upon C<POST> and C<IHAVE> commands this files
will also be updated.

To start from scratch use:

  touch /tmp/active;
  perl -MNNML::Server -e 'server(base => "/tmp", port => 3000)'

To export your mh-Mail use:

  perl overview -base ~/Mail
  perl -MNNML::Server -e 'server(base => "$ENV{HOME}/Mail", port => 3000)'


The command B<POST> and B<IHAVE> honour the C<Newsgroups> header B<if>
not overwritten by the C<X-Nnml-Groups> header. Articles will contain
an appropriate C<X-Nnml-Groups> header when retrieved by message-id.

=head1 AUTHORIZATION

To enable access restrictions use:

  perl -MNNML::Auth -e "NNML::Auth::add_user($ENV{LOGANME}, 'passwd', \
    'read', 'write', 'admin')"

If I<base>F</passwd> exists, three levels of authorization are recognized:

=over 10

=item B<admin>

Users with permission B<admin> may shut down the server using C<SHUT>.
Also these users may create new groups simply by posting to them.

=item B<write>

Users with permission B<write> may use the B<POST> and B<IHAVE> commands.

=item B<read>

All other commands require the B<read> permission.

=head1 FEATURES

Version 1.06 implements the C<MODE GZIP> command. After submiting this
commands, all articles, heads and bodies will be piped through C<gzip
-cf | mimencode>. The server will recognize post requeste using the
same pipe automatically. This will speed up B<nnmirror> if the line is
sufficiant slow.

=head1 BUGS

The server handles multiple connections in a single thread. So a hung
C<POST> or C<IHAVE> would block all connections. Therfore a post
request is interrupted if the server could not read any bytes for 30
seconds. The Client is notified by message 441. If the client
continues to send the article, it is interpreted by the command loop.

=head1 SEE ALSO

The B<overview>(1) and B<nnmirror>(1) manpages.

=head1 AUTHOR

Ulrich Pfeifer E<lt>F<pfeifer@ls6.informatik.uni-dortmund.de>E<gt>

