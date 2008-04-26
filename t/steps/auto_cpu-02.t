#! perl
# Copyright (C) 2007, The Perl Foundation.
# $Id$
# auto_cpu-02.t

use strict;
use warnings;
use Test::More tests =>  13;
use Carp;
use lib qw( lib t/configure/testlib );
use_ok('config::init::defaults');
use_ok('config::auto::cpu');
use Parrot::Configure;
use Parrot::Configure::Options qw( process_options );
use Parrot::Configure::Test qw( test_step_thru_runstep);
use IO::CaptureOutput qw| capture |;

my $args = process_options(
    {
        argv => [ q{--verbose} ],
        mode => q{configure},
    }
);

my $conf = Parrot::Configure->new;

test_step_thru_runstep( $conf, q{init::defaults}, $args );

my $pkg = q{auto::cpu};

$conf->add_steps($pkg);
$conf->options->set( %{$args} );

my ( $task, $step_name, $step);
$task        = $conf->steps->[-1];
$step_name   = $task->step;

$step = $step_name->new();
ok( defined $step, "$step_name constructor returned defined value" );
isa_ok( $step, $step_name );


{
    $conf->data->set('cpuarch' => 'foobar');
    my ($ret, $stdout);
    capture(
        sub { $ret = $step->runstep($conf); },
        \$stdout,
    );
    ok($ret, "$step_name runstep() returned true value" );
    ok(! $step->result(), "Got (default) false result as expected");
    like($stdout, qr/cpu hints = 'auto::cpu::foobar::auto'/s,
        "Got expected verbose output");
    like($stdout, qr/no cpu specific hints/s,
        "Got expected verbose output");
}

pass("Completed all tests in $0");

################### DOCUMENTATION ###################

=head1 NAME

auto_cpu-02.t - test config::auto::cpu

=head1 SYNOPSIS

    % prove t/steps/auto_cpu-02.t

=head1 DESCRIPTION

The files in this directory test functionality used by F<Configure.pl>.

The tests in this file test config::auto::cpu in the case where no hints
file exists corresponding to the CPU architecture.

=head1 AUTHOR

James E Keenan

=head1 SEE ALSO

config::auto::cpu, F<Configure.pl>.

=cut

# Local Variables:
#   mode: cperl
#   cperl-indent-level: 4
#   fill-column: 100
# End:
# vim: expandtab shiftwidth=4:
