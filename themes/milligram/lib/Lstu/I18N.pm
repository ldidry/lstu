# vim:set sw=4 ts=4 sts=4 ft=perl expandtab:
package Lstu::I18N;

use base 'Locale::Maketext';
use File::Basename qw/dirname/;
use Locale::Maketext::Lexicon {
    _auto => 1,
    _decode => 1,
    _style  => 'gettext',
    '*' => [
        Gettext => dirname(__FILE__) . '/I18N/*.po',
        Gettext => $app_dir . 'themes/default/lib/Lstu/I18N/*.po',
    ]
};

use vars qw($app_dir);
BEGIN {
    use Cwd;
    my $app_dir = getcwd;
}

1;
