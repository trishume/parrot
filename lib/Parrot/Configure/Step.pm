# Copyright: 2001-2005 The Perl Foundation.  All Rights Reserved.
# $Id$

=head1 NAME

Parrot::Configure::Step - Configuration Step Utilities

=head1 DESCRIPTION

The C<Parrot::Configure::Step> module contains utility functions for steps to
use.

Note that the actual configuration step itself is NOT an instance of this
class, rather it is defined to be in the C<package> C<Configure::Step>. See
F<docs/configuration.pod> for more information on how to create new
configuration steps.

=head2 Functions

=over 4

=cut

package Parrot::Configure::Step;

use strict;

use Exporter;
use Carp;
use File::Basename qw( basename );
use File::Copy ();
use File::Spec;
use File::Which;

# XXX $conf is a temporary hack
use vars qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS $conf);

@ISA = qw(Exporter);

@EXPORT = ();

@EXPORT_OK = qw(prompt genfile copy_if_diff move_if_diff integrate
    cc_gen cc_build cc_run cc_clean cc_run_capture capture_output
    check_progs);

%EXPORT_TAGS = (
    inter => [qw(prompt integrate)],
    auto  => [
        qw(cc_gen cc_build cc_run cc_clean cc_run_capture
            capture_output check_progs)
    ],
    gen => [qw(genfile copy_if_diff move_if_diff)]
);

=item C<integrate($orig, $new)>

Integrates C<$new> into C<$orig>.  Returns C<$orig> if C<$new> is undefined.

=cut

sub integrate
{
    my ($orig, $new) = @_;

    # Rather than sprinkling "if defined(...)", everywhere,
    # config/inter/progs.pl just passes in potentially undefined
    # strings.  Just pass back the original in that case.  Don't
    # bother warning.  --AD, 12 Sep 2005
    # warn "String to be integrated in to '$orig' undefined";
    return $orig unless defined $new;

    if ($new =~ /\S/) {
        $orig = $new;
    }

    return $orig;
}

=item C<prompt($message, $value)>

Prints out "message [default] " and waits for the user's response. Returns the
response, or the default if the user just hit C<ENTER>.

=cut

sub prompt
{
    my ($message, $value) = @_;

    print("$message [$value] ");

    chomp(my $input = <STDIN>);

    if ($input) {
        $value = $input;
    }

    return integrate($value, $input);
}

=item C<file_checksum($filename, $ignorePattern)>

Creates a checksum for the specified file. This is used to compare files.

Any lines matching the regular expression specified by C<$ignorePattern> are
not included in the checksum.

=cut

sub file_checksum
{
    my ($filename, $ignorePattern) = @_;
    open(my $file, "< $filename") or die "Can't open $filename: $!";
    my $sum = 0;
    while (<$file>) {
        next if defined($ignorePattern) && /$ignorePattern/;
        $sum += unpack("%32C*", $_);
    }
    close($file) or die "Can't close $filename: $!";
    return $sum;
}

=item C<copy_if_diff($from, $to, $ignorePattern)>

Copies the file specified by C<$from> to the location specified by C<$to> if
it's contents have changed.

The regular expression specified by C<$ignorePattern> is passed to
C<file_checksum()> when comparing the files.

=cut

sub copy_if_diff
{
    my ($from, $to, $ignorePattern) = @_;

    # Don't touch the file if it didn't change (avoid unnecessary rebuilds)
    if (-r $to) {
        my $from_sum = file_checksum($from, $ignorePattern);
        my $to_sum   = file_checksum($to,   $ignorePattern);
        return if $from_sum == $to_sum;
    }

    File::Copy::copy($from, $to);

    # Make sure the timestamp is updated
    my $now = time;
    utime $now, $now, $to;

    return 1;
}

=item C<move_if_diff($from, $to, $ignorePattern)>

Moves the file specified by C<$from> to the location specified by C<$to> if
it's contents have changed.

=cut

sub move_if_diff
{
    my ($from, $to, $ignorePattern) = @_;
    copy_if_diff($from, $to, $ignorePattern);
    unlink $from;
}

=item C<genfile($source, $target, %options)>

Takes the specified source file, substitutes any sequences matching
C</\$\{\w+\}/> for the given key's value in the configuration system's data,
and writes the results to specified target file.

=cut

sub genfile
{
    my ($source, $target, %options) = @_;

    open(my $in, "< $source") or die "Can't open $source: $!";

    # don't change the name of the outfile handle
    # feature.pl / feature_h.in need OUT
    open(my $out, "> $target.tmp") or die "Can't open $target.tmp: $!";

    if ($options{commentType}) {
        my @comment = (
            "DO NOT EDIT THIS FILE",
            "Generated by " . __PACKAGE__ . " from $source"
        );

        if ($options{commentType} eq '#') {
            foreach my $line (@comment) {
                $line = "# $line\n";
            }
        } elsif ($options{commentType} eq '/*') {
            foreach my $line (@comment) {
                $line = " * $line\n";
            }
            $comment[0]  =~ s{^}{/*\n};     # '/*'
            $comment[-1] =~ s{$}{\n */};    # ' */'
        } else {
            die "Unknown comment type '$options{commentType}'";
        }
        foreach my $line (@comment) { print $out $line; }
        print $out "\n"; # extra newline after header
    }

    # this loop can not be implemented as a foreach loop as the body
    # is dependant on <IN> being evaluated lazily
    while (my $line = <$in>) {
        # everything after the line starting with #perl is eval'ed
        if ($line =~ /^#perl/ && $options{feature_file}) {
            # OUT was/is used at the output filehandle in eval'ed scripts
            local *OUT = $out;
            my $text = do {local $/; <$in>};
            $text =~ s{ \$\{(\w+)\} }{\$conf->data->get("$1")}gx;
            eval $text;
            die $@ if $@;
            last;
        }
        if ($options{conditioned_lines}) {

            # Lines with "#CONDITIONED_LINE(var):..." are skipped if
            # the "var" condition is false.
            # Lines with "#INVERSE_CONDITIONED_LINE(var):..." are skipped if
            # the "var" condition is true.
            if ($line =~ m/^#CONDITIONED_LINE\(([^)]+)\):(.*)/s) {
                next unless $conf->data->get($1);
                $line = $2;
            } elsif ($line =~ m/^#INVERSE_CONDITIONED_LINE\(([^)]+)\):(.*)/s) {
                next if $conf->data->get($1);
                $line = $2;
            }
        }
        $line =~ s{ \$\{(\w+)\} }{
            if(defined(my $val=$conf->data->get($1))) {
                #use Data::Dumper;warn Dumper("val for $1 is ",$val);
                $val;
            } else {
                warn "value for '$1' in $source is undef";
                '';
            }
        }egx;
        if ($options{replace_slashes}) {
            $line =~ s{(/+)}{
                my $len = length $1;
                my $slash = $conf->data->get('slash');
                '/' x ($len/2) . ($len%2 ? $slash : '');
            }eg;
            # replace \* with \\*, so make will not eat the \
            $line =~ s{(\\\*)}{\\$1}g;
        }
        # Unquote text quoted using ${{word}} notation
        $line =~ s/\${{(\w+)}}/\${$1}/g;
        print $out $line;
    }

    close($in)  or die "Can't close $source: $!";
    close($out) or die "Can't close $target: $!";

    move_if_diff("$target.tmp", $target, $options{ignorePattern});
}

=item C<_run_command($command, $out, $err)>

Runs the specified command. Output is directed to the file specified by
C<$out>, warnings and errors are directed to the file specified by C<$err>.

=cut

sub _run_command
{
    my ($command, $out, $err, $verbose) = @_;

    if ($verbose) {
        print "$command\n";
    }

    # Mostly copied from Parrot::Test.pm
    foreach ($out, $err) {
        $_ = 'NUL:' if $_ and $^O eq 'MSWin32' and $_ eq '/dev/null';
    }

    if ($out and $err and $out eq $err) {
        $err = "&STDOUT";
    }

    local *OLDOUT if $out;
    local *OLDERR if $err;

    # Save the old filehandles; we must not let them get closed.
    open OLDOUT, ">&STDOUT" or die "Can't save     stdout" if $out;
    open OLDERR, ">&STDERR" or die "Can't save     stderr" if $err;

    open STDOUT, ">$out" or die "Can't redirect stdout" if $out;
    open STDERR, ">$err" or die "Can't redirect stderr" if $err;

    system $command;
    my $exit_code = $? >> 8;

    close STDOUT or die "Can't close    stdout" if $out;
    close STDERR or die "Can't close    stderr" if $err;

    open STDOUT, ">&OLDOUT" or die "Can't restore  stdout" if $out;
    open STDERR, ">&OLDERR" or die "Can't restore  stderr" if $err;

    if ($verbose) {
        foreach ($out, $err) {
            if (   (defined($_))
                && ($_ ne '/dev/null')
                && ($_ ne 'NUL:')
                && (!m/^&/)) {
                open(my $out, $_);
                print <$out>;
                close $out;
            }
        }
    }

    return $exit_code;
}

=item C<cc_gen($source)>

Generates F<test.c> from the specified source file.

=cut

sub cc_gen
{
    my ($source) = @_;

    genfile($source, "test.c");
}

=item C<cc_build($cc_args, $link_args)>

These items are used from current config settings:

  $cc, $ccflags, $ldout, $o, $link, $linkflags, $cc_exe_out, $exe, $libs

Calls the compiler and linker on F<test.c>.

=cut

sub cc_build
{
    my ($cc_args, $link_args) = @_;

    $cc_args   = '' unless defined $cc_args;
    $link_args = '' unless defined $link_args;

    my $verbose = $conf->options->get('verbose');

    my ($cc, $ccflags, $ldout, $o, $link, $linkflags, $cc_exe_out, $exe, $libs) = $conf->data->get(
        qw(cc ccflags ld_out o link linkflags
            cc_exe_out exe libs)
    );

    _run_command("$cc $ccflags $cc_args -I./include -c test.c", 'test.cco', 'test.cco', $verbose)
        and confess "C compiler failed (see test.cco)";

    _run_command("$link $linkflags test$o $link_args ${cc_exe_out}test$exe $libs", 'test.ldo', 'test.ldo', $verbose)
        and confess "Linker failed (see test.ldo)";
}

=item C<cc_run()>

Calls the F<test> (or F<test.exe>) executable. Any output is directed to
F<test.out>.

=cut

sub cc_run
{
    my $exe   = $conf->data->get('exe');
    my $slash = $conf->data->get('slash');
    my $verbose = $conf->options->get('verbose');

    if (defined($_[0]) && length($_[0])) {
        local $" = ' ';
        _run_command(".${slash}test${exe} @_", './test.out', undef, $verbose);
    } else {
        _run_command(".${slash}test${exe}", './test.out', undef, $verbose);
    }

    my $output = _slurp('./test.out');

    return $output;
}

=item C<cc_run_capture()>

Same as C<cc_run()> except that warnings and errors are also directed to
F<test.out>.

=cut

sub cc_run_capture
{
    my $exe   = $conf->data->get('exe');
    my $slash = $conf->data->get('slash');
    my $verbose = $conf->options->get('verbose');

    if (defined($_[0]) && length($_[0])) {
        local $" = ' ';
        _run_command(".${slash}test${exe} @_", './test.out', './test.out',
            $verbose);
    } else {
        _run_command(".${slash}test${exe}", './test.out', './test.out',
            $verbose);
    }

    my $output = _slurp('./test.out');

    return $output;
}

=item C<cc_clean()>

Cleans up all files in the root folder that match the glob F<test.*>.

=cut

sub cc_clean
{
    unlink map "test$_", qw( .c .cco .ldo .out), $conf->data->get(qw( o exe ));
}

=item C<capture_output($command)>

Executes the given command. The command's output (both stdout and stderr), and
its return status is returned as a 3-tuple. B<STDERR> is redirected to
F<test.err> during the execution, and deleted after the command's run.

=cut

sub capture_output
{
    my $command = join " ", @_;

    # disable STDERR
    open OLDERR, ">&STDERR";
    open STDERR, ">test.err";

    my $output = `$command`;
    my $retval = ($? == -1) ? -1 : ($? >> 8);

    # reenable STDERR
    close STDERR;
    open STDERR, ">&OLDERR";

    # slurp stderr
    my $out_err = _slurp('./test.err');

    # cleanup
    unlink "test.err";

    return ($output, $out_err, $retval) if wantarray;
    return $output;
}

=item C<check_progs([$programs])>

Where C<$programs> may be either a scalar with the name of a single program or
an array ref of programs to search the current C<PATH> for.  The first matching
program name is returned or C<undef> on failure.  Note: this function only
returns the name of the program and not its complete path.

This function is similar to C<autoconf>'s C<AC_CHECK_PROGS> macro.

=cut

sub check_progs
{
    my ($progs, $verbose) = @_;

    $progs = [$progs] unless ref $progs eq 'ARRAY';

    print "checking for program: ", join(" or ", @$progs), "\n" if $verbose;
    foreach my $prog (@$progs) {
        my $util = $prog;

        # use the first word in the string to ignore any options
        ($util) = $util =~ /(\S+)/;
        my $path = which($util);

        if ($verbose) {
            print "$path is executable\n" if $path;
        }

        return $prog if $path;
    }

    return;
}

=item C<_slurp($filename)>

Slurps C<$filename> into memory and returns it as a string.

=cut

sub _slurp
{
    my $filename = shift;

    open(my $fh, $filename) or die "Can't open $filename: $!";
    my $text = do {local $/; <$fh>};
    close($fh) or die "Can't close $filename: $!";

    return $text;
}

=back

=head1 SEE ALSO

=over 4

=item C<Parrot::Configure::RunSteps>

=item F<docs/configuration.pod>

=back

=cut

1;
