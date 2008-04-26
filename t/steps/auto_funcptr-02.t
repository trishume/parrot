#! perl
# Copyright (C) 2007, The Perl Foundation.
# $Id$
# auto_funcptr-02.t

use strict;
use warnings;
use Test::More tests =>  12;
use Carp;
use lib qw( lib t/configure/testlib );
use_ok('config::init::defaults');
use_ok('config::auto::funcptr');

use Parrot::BuildUtil;
use Parrot::Configure;
use Parrot::Configure::Options qw( process_options );
use Parrot::Configure::Test qw( test_step_thru_runstep);
use IO::CaptureOutput qw| capture |;

my $args = process_options( {
    argv            => [ ],
    mode            => q{configure},
} );

my $conf = Parrot::Configure->new();

test_step_thru_runstep($conf, q{init::defaults}, $args);

my ($task, $step_name, $step, $ret);
my $pkg = q{auto::funcptr};

$conf->add_steps($pkg);
$conf->options->set(%{$args});

$task = $conf->steps->[-1];
$step_name   = $task->step;

$step = $step_name->new();
ok(defined $step, "$step_name constructor returned defined value");
isa_ok($step, $step_name);


{
    my $stdout;
    my $ret = capture(
        sub { auto::funcptr::_cast_void_pointers_msg(); },
        \$stdout,
    );
    like($stdout, qr/Although it is not required/s,
        "Got expected advisory message");
}

{
    my $stdout;
    my $ret = capture(
        sub { auto::funcptr::_set_positive_result($step, $conf); },
        \$stdout,
    );
    is($step->result, q{yes}, "Got expected result");
    ok(! $stdout, "Nothing printed to STDOUT, as expected");
}

pass("Completed all tests in $0");

################### DOCUMENTATION ###################

=head1 NAME

auto_funcptr-02.t - test config::auto::funcptr

=head1 SYNOPSIS

    % prove t/steps/auto_funcptr-02.t

=head1 DESCRIPTION

The files in this directory test functionality used by F<Configure.pl>.

The tests in this file test aspects of config::auto::funcptr in the case where
the C<--verbose> option has not been set.

=head1 AUTHOR

James E Keenan

=head1 SEE ALSO

config::auto::funcptr, F<Configure.pl>.

=cut

# Local Variables:
#   mode: cperl
#   cperl-indent-level: 4
#   fill-column: 100
# End:
# vim: expandtab shiftwidth=4:
