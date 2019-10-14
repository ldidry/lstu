requires 'inc::Module::Install::DSL';
requires 'Mojolicious', '>= 8.09';
requires 'Data::Validate::URI';
requires 'Net::Domain::TLD', '>= 1.74';
requires 'Mojolicious::Plugin::I18N';
requires 'Mojolicious::Plugin::DebugDumperHelper';
requires 'Mojolicious::Plugin::Piwik';
requires 'Mojolicious::Plugin::StaticCache';
requires 'Mojolicious::Plugin::GzipStatic';
requires 'Mojolicious::Plugin::CSPHeader', '>= 0.03';
#requires 'Mojolicious::Plugin::FiatTux::Helpers', '== 0.10', url => 'https://framagit.org/fiat-tux/mojolicious/fiat-tux/mojolicious-plugin-fiattux-helpers/-/archive/0.10/mojolicious-plugin-fiattux-helpers-0.10.tar.gz';
#requires 'Mojolicious::Plugin::FiatTux::GrantAccess', '== 0.07', url => 'https://framagit.org/fiat-tux/mojolicious/fiat-tux/mojolicious-plugin-fiattux-grantaccess/-/archive/0.07/mojolicious-plugin-fiattux-grantaccess-0.07.tar.gz';
#requires 'Mojolicious::Plugin::FiatTux::Themes', '== 0.02', url => 'https://framagit.org/fiat-tux/mojolicious/fiat-tux/mojolicious-plugin-fiattux-themes/-/archive/0.02/mojolicious-plugin-fiattux-themes-0.02.tar.gz';
requires 'Minion';
requires 'Locale::Maketext';
requires 'Locale::Maketext::Extract';
requires 'Net::Abuse::Utils::Spamhaus';
requires 'Net::DNS', '>= 1.12';
requires 'Net::SSLeay', '>= 1.81';
requires 'IO::Socket::SSL';
requires 'Image::PNG::QRCode';
requires 'Cpanel::JSON::XS';

feature 'ldap', 'LDAP authentication support' => sub {
    requires 'Net::LDAP';
    requires 'Mojolicious::Plugin::Authentication';
};
feature 'htpasswd', 'Htpasswd authentication support' => sub {
    requires 'Apache::Htpasswd';
    requires 'Mojolicious::Plugin::Authentication';
};
feature 'cache', 'URL cache system' => sub {
    requires 'Mojolicious::Plugin::CHI';
    requires 'CHI::Driver::Memcached';
    requires 'Cache::Memcached';
};
feature 'test' => sub {
    requires 'Devel::Cover';
};
feature 'sqlite', 'SQLite support' => sub {
    requires 'Mojo::SQLite', '>= 3.000';
    requires 'Minion::Backend::SQLite', '>= 4.001';
};
feature 'postgresql', 'PostgreSQL support' => sub {
    requires 'Mojo::Pg';
    requires 'Mojolicious::Plugin::PgURLHelper';
};
feature 'mysql', 'MySQL support' => sub {
    requires 'Mojo::mysql';
    requires 'Minion::Backend::mysql';
    requires 'Mojolicious::Plugin::PgURLHelper';
};

feature 'safebrowsing', 'Check URLs against Google safebrowsing database' => sub {
    requires 'Net::Google::SafeBrowsing4', '>= 0.8';
    requires 'Term::ProgressBar::Quiet';
};
