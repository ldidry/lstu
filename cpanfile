requires 'inc::Module::Install::DSL';
requires 'Mojolicious', '>= 7.33';
requires 'Data::Validate::URI';
requires 'Net::Domain::TLD', '>= 1.74';
requires 'Mojolicious::Plugin::I18N';
requires 'Mojolicious::Plugin::DebugDumperHelper';
requires 'Mojolicious::Plugin::Piwik';
requires 'Mojolicious::Plugin::Authentication';
requires 'Mojolicious::Plugin::StaticCache';
requires 'Mojolicious::Plugin::CHI';
requires 'Minion';
requires 'Minion::Backend::SQLite';
requires 'Locale::Maketext';
requires 'Locale::Maketext::Extract';
requires 'Net::Abuse::Utils::Spamhaus';
requires 'Net::DNS', '>= 1.12';
requires 'Net::SSLeay', '>= 1.81';
requires 'IO::Socket::SSL';
requires 'Net::LDAP';
requires 'Apache::Htpasswd';
requires 'Image::PNG::QRCode';
requires 'Cpanel::JSON::XS';
requires 'CHI::Driver::SharedMem';
feature 'test' => sub {
    requires 'Devel::Cover';
};
feature 'sqlite', 'SQLite support' => sub {
    requires 'Mojo::SQLite';
};
feature 'postgresql', 'PostgreSQL support' => sub {
    requires 'Mojo::Pg';
};
feature 'mysql', 'MySQL support' => sub {
    requires 'Mojo::mysql';
};
