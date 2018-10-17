# vim:set sw=4 ts=4 sts=4 ft=perl expandtab:
package Lstu::Command::theme;
use Mojo::Base 'Mojolicious::Commands';
use FindBin qw($Bin);
use File::Spec qw(catfile cat dir);
use File::Path qw(make_path);

has description => 'Create new theme skeleton.';
has usage => sub { shift->extract_usage };
has message    => sub { shift->extract_usage . "\nCreate new theme skeleton:\n" };
has namespaces => sub { ['Lstu::Command::theme'] };

sub run {
    my $c    = shift;
    my $name = shift;

    unless (defined $name) {
        say $c->extract_usage;
        exit 1;
    }

    my $home = File::Spec->catdir($Bin, '..', 'themes', $name);

    unless (-d $home) {

        # Create skeleton
        mkdir $home;
        mkdir File::Spec->catdir($home, 'public');
        make_path(File::Spec->catdir($home, 'templates', 'layouts'));
        make_path(File::Spec->catdir($home, 'lib', 'Lstu', 'I18N'));

        my $i18n = <<EOF;
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
EOF

        open my $f, '>', File::Spec->catfile($home, 'lib', 'Lstu', 'I18N.pm') or die "Unable to open $home/lib/Lstu/I18N.pm: $!";
        print $f $i18n;
        close $f;

        my $makefile = <<EOF;
POT=lib/Lstu/I18N/$home.pot
SEDOPTS=-e "s\@SOME DESCRIPTIVE TITLE\@Lstu language file\@" \\
		-e "s\@YEAR THE PACKAGE'S COPYRIGHT HOLDER\@2015 Luc Didry\@" \\
		-e "s\@CHARSET\@utf8\@" \\
		-e "s\@the PACKAGE package\@the Lstu package\@" \\
		-e '/^\\#\\. (/{N;/\\n\\#\\. (/{N;/\\n.*\\.\\.\\/default\\//{s/\\#\\..*\\n.*\\#\\./\\#. (/g}}}' \\
		-e '/^\\#\\. (/{N;/\\n.*\\.\\.\\/default\\//{s/\\n/ /}}'
SEDOPTS2=-e '/^\\#.*\\.\\.\\/default\\//,+3d'
XGETTEXT=carton exec ../../local/bin/xgettext.pl
CARTON=carton exec

locales:
		$(XGETTEXT) -D templates -D ../default/templates -o $(POT) 2>/dev/null
		sed $(SEDOPTS) -i $(POT)
		sed $(SEDOPTS2) -i $(POT)
EOF

        open $f, '>', File::Spec->catfile($home, 'Makefile') or die "Unable to open $home/Makefile: $!";
        print $f $makefile;
        close $f;
    } else {
        say "$name theme already exists. Aborting.";
        exit 1;
    }
}

=encoding utf8

=head1 NAME

Lstu::Command::theme - Create new theme skeleton.

=head1 SYNOPSIS

  Usage: script/lstu theme THEME_NAME

  Your new theme will be available in the themes directory.

=cut

1;
