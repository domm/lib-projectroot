package lib::projectroot;
use strict;
use warnings;
use 5.010;

# ABSTRACT: easier loading of a project's local libs
our $VERSION = "1.002";

use FindBin qw();
use Carp qw(carp);
use File::Spec::Functions qw(catdir splitdir);
use local::lib qw();
use lib qw();

my $ROOT;

sub import {
    my $class = shift;
    my @libdirs;
    my @locallibs;
    my @extra;
    foreach my $d (@_) {
        if ( $d =~ /^local::lib=([\S]+)/ ) {
            push( @libdirs,   $1 );
            push( @locallibs, $1 );
        }
        elsif ( $d =~ /^extra=([\S]+)/ ) {
            @extra=split(/[,;]/, $1);
        }
        else {
            push( @libdirs, $d );
        }
    }

    my @searchdirs = splitdir("$FindBin::Bin");

SEARCH: while (@searchdirs) {
        foreach my $dir (@libdirs) {
            unless ( -d catdir( @searchdirs, $dir ) ) {
                pop(@searchdirs);
                next SEARCH;
            }
        }
        $ROOT = catdir(@searchdirs);
        last SEARCH;
    }

    if ($ROOT) {
        local::lib->import( map { catdir( $ROOT, $_ ) } @locallibs ) if @locallibs;
        lib->import( map        { catdir( $ROOT, $_ ) } @libdirs ) if @libdirs;
        __PACKAGE__->load_extra( @extra ) if @extra;
    }
    else {
        carp "Could not find root dir containing " . join( ', ', @libdirs );
    }
}

sub load_extra {
    my $class  = shift;
    my @extras = @_;

    my @parts = splitdir($ROOT);
    pop(@parts);
    my $parent = catdir(@parts);

    foreach my $d (@extras) {
        my $extra = catdir( $parent, $d, 'lib' );
        if ( -d $extra ) {
            push( @INC, $extra );
        }
        else {
            carp "Cannot load_extra $d, directory $extra does not exist";
        }
    }
}

42;

__END__

=pod

=head1 SYNOPSIS

  # your_project/bin/somewhere/deep/down/script.pl
  use strict;
  use warnings;
  # look up from the file's location until we find a directory
  # containing a directory named 'lib'. Add this dir to @INC
  use lib::projectroot qw(lib);

  # look up until we find a dir that contains both 'lib' and 'foo',
  # add both to @INC
  use lib::projectroot qw(lib foo);

  # look up until we find 'lib' and 'local'. Add 'lib' to @INC,
  # load 'local' via local::lib
  use lib::projectroot qw(lib local::lib=local);

  # based on the dir we found earlier, go up one dir and try to add
  # 'Your-OtherModule/lib' and 'Dark-PAN/lib' to @INC
  lib::projectroot->load_extra(Your-OtherModule Dark-PAN);

  # the same as above
  use lib::projectroot qw(lib local::lib=local extra=Your-OtherModule,Dark-PAN);

=head1 DESCRIPTION

I'm usually using a setup like this:

  .
  ├── AProject
  │   ├── bin
  │   │   ├── db
  │   │   │   └── init.pl
  │   │   ├── onetime
  │   │   │   ├── fixup
  │   │   │   │   └── RT666_fix_up_fubared_data.pl
  │   │   │   └── import_data.pl
  │   │   └── web.psgi
  │   ├── lib
  │   └── local
  ├── MyHelperStuff
  │   └── lib
  └── CoolLib-NotYetOnCPAN
      └── lib

There is C<AProject>, which is the actual code I'm working on. There
is also probably C<BProject>, e.g. another microservice for the same
customer. C<AProject> has its own code in C<lib> and its CPAN
dependencies in C<local> (managed via C<Carton> and used via
C<local::lib>). There are a bunch of scripts / "binaries" in C<bin>,
in a lot of different directories of varying depth.

I have some generic helper code I use in several projects in
C<MyHelperStuff/lib>. It will never go to CPAN. I have some other code
in C<CoolLib-NotYetOnCPAN/lib> (but it might end up on CPAN if I ever
get to clean it up...)

C<lib::projectroot> makes it easy to add all these paths to C<@INC> so
I can use the code.

In each script, I just have to say:

  use lib::projectroot qw(lib local::lib=local);

C<lib> is added to the beginning of <@INC>, and C<local> is loaded via
C<local::lib>, without me having to know how deep in C<bin> the
current script is located.

I can also add

  lib::projectroot->load_extra(qw(MyHelperStuff CoolLib-NotYetOnCPAN));

to get my other code pushed to C<@INC>. (Though currently I put this
line, and some other setup code like initialising C<Log::Any> into
C<AProject::Run>, and just C<use AProject::Run;>)

You can also define extra dists directly while loading C<lib::projectroot>:

  use lib::projectroot qw(
      lib
      local::lib=local
      extra=MyHelperStuff,CoolLib-NotYetOnCPAN
  );

=head1 TODOs

Some ideas for future releases:

=over

=item * what happens if C<$PERL5LIB> is already set?

=item * add C<local::lib> dirs of extras (i.e. if DarkPAN also uses C<local::lib> to install its deps)

=item * think about the security issues raised by Abraxxa (http://prepan.org/module/nY4oajhgzJN 2014-12-02 18:42:07)

=back

=head1 SEE ALSO

=over

=item * L<FindBin> - find out where the current binary/script is located, but no C<@INC> manipulation. In the Perl core since forever. Also used by C<lib::projectroot>.

=item * L<Find::Lib> - combines C<FindBin> and C<lib>, but does not search for the actual location of F<lib>, so you'll need to know where your scripts is located relative to F<lib>.

=item * L<FindBin::libs> - finds the next F<lib> directory and uses it, but no L<local::lib> support. But lots of other features

=item * L<File::FindLib> - find and use a file or dir based on the script location. Again no L<local::lib> support.

=item * and probably more...

=head1 THANKS

Thanks to C<eserte>, C<Smylers> & Ca<abraxxa> for providing feedback
at L<http://prepan.org/module/nY4oajhgzJN|prepan.org>. Meta-thanks to
L<http://twitter.com/kentaro|kentaro> for running prepan, a very handy
service!

Thanks to C<koki>, C<farhad> and C<Jozef> for providing face-to-face
feedback.


