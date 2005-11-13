# Copyright: 2001-2003 The Perl Foundation.  All Rights Reserved.
# $Id$

=head1 NAME

config/gen/platform.pl - Platform Files

=head1 DESCRIPTION

Moves the various platform-specific files into place.

=cut

package Configure::Step;

use strict;
use vars qw($description @args);
use Parrot::Configure::Step qw(copy_if_diff);

$description="Moving platform files into place...";

@args=qw(miniparrot verbose);

sub runstep {
  my ($miniparrot, $verbose) = @_;
  my $platform=lc $^O;

  $platform="ansi" if defined($miniparrot);
  $platform="win32" if $platform =~ /^msys/;
  $platform="win32" if $platform =~ /^mingw/;
  $platform =~ s/^ms//;
  $platform="generic" unless -d "config/gen/platform/$platform";

  print " platform='$platform' " if $verbose;

  my $generated = Parrot::Configure::Data->get('TEMP_generated');
  $generated = '' unless defined $generated;
  print " ($generated) " if $verbose;
  print("\n") if defined $verbose && $verbose == 2;

  # headers are merged into platform.h
  my @headers = qw/
    io.h
    math.h
    misc.h
    dl.h
    signal.h
    stat.h
    threads.h
  /;

  open PLATFORM_H, "> include/parrot/platform.h"
      or die "Can't open include/parrot/platform.h: $!";

  print PLATFORM_H <<HERE;
#if !defined(PARROT_PLATFORM_H_GUARD)
#define PARROT_PLATFORM_H_GUARD

/*
** platform.h [$platform version]
**
** DO NOT EDIT THIS FILE
**
** Generated by config/gen/platform.pl
*/

HERE

  for ( @headers ) {
      my $header_file = "config/gen/platform/generic/$_";
      if ( -e "config/gen/platform/$platform/$_" ) {
          $header_file = "config/gen/platform/$platform/$_";
      }

      if ( -e $header_file ) {
          local $/ = undef;
	  print("\t$header_file\n") if defined $verbose && $verbose == 2;
          open IN_H, "< $header_file" or die "Can't open $header_file: $!";
          print PLATFORM_H <<HERE;
/*
** $header_file:
*/
#line 1 "$header_file"
HERE
          print PLATFORM_H <IN_H>, "\n\n";
          close IN_H;
      }

      # just fall through if file is missing; means neither this platform nor
      # generic has anything to contribute for this feature.  this might not
      # be desirable if porters don't see the appropriate file in generic/ and
      # shoehorn their function into the wrong file rather than creating the
      # correct one from the above list in their $platform/ dir (e.g. misc.c).
  }

  # finally append generated
  @headers = grep { /\.h$/ } split(',', $generated);
  for ( @headers ) {
      if ( -e $_ ) {
          local $/ = undef;
	  print("\t$_\n") if defined $verbose && $verbose == 2;
          open IN_H, "< $_" or die "Can't open $_: $!";
          print PLATFORM_H <<HERE;
/*
** $_
*/
#line 1 "$_"
HERE
          print PLATFORM_H <IN_H>, "\n\n";
          close IN_H;
      }
      else {
	  warn("Header file '$_' listed in TEMP_generated but not found\n");
      }
  }

  print PLATFORM_H <<HERE;
#endif
HERE

  close PLATFORM_H;

  # implementation files are merged into platform.c
  my @impls = qw/
    time.c
    env.c
    dl.c
    stat.c
    math.c
    memalign.c
    signal.c
    itimer.c
    memexec.c
    exec.c
    misc.c
  /;


  open PLATFORM_C, "> src/platform.c" or die "Can't open src/platform.c: $!";

  print PLATFORM_C <<HERE;
/*
** platform.c [$platform version]
**
** DO NOT EDIT THIS FILE
**
** Generated by config/gen/platform.pl
*/
HERE

  # We need to put things from begin.c before the parrot.h include.
  if ( -e "config/gen/platform/$platform/begin.c" ) {
      local $/ = undef;
      open IN_C, "< config/gen/platform/$platform/begin.c" or die "Can't open begin.c: $!";
      print PLATFORM_C <<HERE;
/*
** begin.c
*/
#line 1 "config/gen/platform/$platform/begin.c"
HERE
      print PLATFORM_C <IN_C>, "\n\n";
      close IN_C;
  }

  # Copy the rest.
print PLATFORM_C <<HERE;
#include "parrot/parrot.h"

HERE

  for ( @impls ) {
      my $impl_file = "config/gen/platform/generic/$_";
      if ( -e "config/gen/platform/$platform/$_" ) {
          $impl_file = "config/gen/platform/$platform/$_";
      }

      if ( -e $impl_file ) {
          local $/ = undef;
	  print("\t$impl_file\n") if defined $verbose && $verbose == 2;
          open IN_C, "< $impl_file" or die "Can't open $impl_file: $!";
          print PLATFORM_C <<HERE;
/*
** $impl_file:
*/
#line 1 "$impl_file"
HERE
          print PLATFORM_C <IN_C>, "\n\n";
          close IN_C;
      }
  }

  # append generated c files
  @impls = grep { /\.c$/ } split(',', $generated);
  for ( @impls ) {
      if ( -e $_ ) {
          local $/ = undef;
	  print("\t$_\n") if defined $verbose && $verbose == 2;
          open IN_C, "< $_" or die "Can't open $_: $!";
          print PLATFORM_C <<HERE;
/*
** $_:
*/
#line 1 "$_"
HERE
          print PLATFORM_C <IN_C>, "\n\n";
          close IN_C;
      }
  }

  close PLATFORM_C;

  if ( Parrot::Configure::Data->get( 'platform_asm' ) ) {
      my $asm_file = "config/gen/platform/$platform/asm.s";
      if ( -e $asm_file ) {
          copy_if_diff( $asm_file, "src/platform_asm.s" );
      }
  }

  # interface is the same for all platforms
  copy_if_diff( "config/gen/platform/platform_interface.h",
		  "include/parrot/platform_interface.h" );
}

1;
