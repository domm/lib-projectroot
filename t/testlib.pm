package testlib;
use Exporter 'import';
use File::Spec::Functions qw(splitdir);

@EXPORT_OK = qw(cleanup);

sub cleanup {
    my $dir = shift;
    $dir=~s{.*lib-projectroot}{};
    my $clean = join('/',grep { $_ } splitdir($dir));
    return $clean;
}


