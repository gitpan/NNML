#                              -*- Mode: Perl -*- 
# Makefile.PL -- 
# ITIID           : $ITI$ $Header $__Header$
# Author          : Ulrich Pfeifer
# Created On      : Sat Sep 28 13:51:19 1996
# Last Modified By: Ulrich Pfeifer
# Last Modified On: Mon Sep 30 13:06:37 1996
# Language        : CPerl
# Update Count    : 12
# Status          : Unknown, Use with caution!
# 
# (C) Copyright 1996, Universität Dortmund, all rights reserved.
# 
# $Locker$
# $Log$
# 

use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

WriteMakefile(
              'PREREQ_PM' => {
                              'IO::File' => 0,
                              'IO::Select' => 0, 'IO::Socket' => 1.13
                             },
              'NAME'	  => 'NNML',
              'VERSION_FROM' => 'NNML/Server.pm',
              'dist'      => { SUFFIX => "gz", COMPRESS => "gzip -f"},
              'EXE_FILES' => [qw(nnmirror overview)],
             );
