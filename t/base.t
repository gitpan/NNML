#                              -*- Mode: Perl -*- 
# base.t -- 
# ITIID           : $ITI$ $Header $__Header$
# Author          : Ulrich Pfeifer
# Created On      : Sat Sep 28 13:54:46 1996
# Last Modified By: Ulrich Pfeifer
# Last Modified On: Mon Sep 30 08:48:31 1996
# Language        : CPerl
# Update Count    : 24
# Status          : Unknown, Use with caution!
# 
# (C) Copyright 1996, Universität Dortmund, all rights reserved.
# 
# $Locker$
# $Log$
# 

BEGIN { $| = 1; print "1..2\n"; }
END {print "not ok 1\n" unless $loaded;}
use NNML::Server;
use NNML::Config qw($CONF);
use NNML::Active qw($ACTIVE);

$loaded = 1;

print "ok 1\n";
my $test = 2;

print ((defined $CONF)? "ok $test\n" : "not ok $test\n"); $test++;


#map print (join(' ', @{$_})."\n"), $ACTIVE->list_match('tools*,!*wais.*');
