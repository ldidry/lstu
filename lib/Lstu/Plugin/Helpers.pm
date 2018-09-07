package Lstu::Plugin::Helpers;
use Mojo::Base 'Mojolicious::Plugin';
use Mojo::URL;
use Net::Abuse::Utils::Spamhaus qw(check_fqdn);
use Lstu::DB::URL;
use Lstu::DB::Ban;
use Lstu::DB::Session;
use FindBin qw($Bin);

sub register {
    my ($self, $app) = @_;

    # PgURL helper
    if ($app->config('dbtype') eq 'postgresql' || $app->config('dbtype') eq 'mysql') {
        $app->plugin('PgURLHelper');
    }

    # DB migrations
    if ($app->config('dbtype') eq 'sqlite') {
        require Mojo::SQLite;
        $app->helper(sqlite => \&_sqlite);

        # Database migration
        # Have to create $sql before using its migrations attribute, otherwise, it won't work
        my $sql        = Mojo::SQLite->new('sqlite:'.$app->config('db_path'));
        my $migrations = $sql->migrations;
        if ($app->mode eq 'development' && $ENV{LSTU_DEBUG}) {
            $migrations->from_file('utilities/migrations/sqlite.sql')->migrate(0)->migrate(2);
        } else {
            $migrations->from_file('utilities/migrations/sqlite.sql')->migrate(2);
        }
    } elsif ($app->config('dbtype') eq 'postgresql') {
        require Mojo::Pg;
        $app->helper(pg => \&_pg);

        # Database migration
        my $migrations = Mojo::Pg::Migrations->new(pg => $app->pg);
        if ($app->mode eq 'development' && $ENV{LSTU_DEBUG}) {
            $migrations->from_file('utilities/migrations/postgresql.sql')->migrate(0)->migrate(3);
        } else {
            $migrations->from_file('utilities/migrations/postgresql.sql')->migrate(3);
        }
    } elsif ($app->config('dbtype') eq 'mysql') {
        require Mojo::mysql;
        $app->helper(mysql => \&_mysql);

        # Database migration
        my $migrations = Mojo::mysql::Migrations->new(mysql => $app->mysql);
        if ($app->mode eq 'development' && $ENV{LSTU_DEBUG}) {
            $migrations->from_file('utilities/migrations/mysql.sql')->migrate(0)->migrate(2);
        } else {
            $migrations->from_file('utilities/migrations/mysql.sql')->migrate(2);
        }
    }

    # Helpers
    $app->helper(ip           => \&_ip);
    $app->helper(provisioning => \&_provisioning);
    $app->helper(prefix       => \&_prefix);
    $app->helper(shortener    => \&_shortener);
    $app->helper(is_spam      => \&_is_spam);
    $app->helper(cleaning     => \&_cleaning);
    $app->helper(gsb          => \&_gsb);
    $app->helper(gsb_update   => \&_gsb_update);
}

sub _sqlite {
    my $c = shift;

    state $sqlite = Mojo::SQLite->new('sqlite:'.$c->app->config('db_path'));
    return $sqlite;
}

sub _pg {
    my $c     = shift;

    my $pgdb  = $c->config('pgdb');
    my $port  = (defined $pgdb->{port}) ? $pgdb->{port}: 5432;
    my $addr  = $c->pg_url({
        host => $pgdb->{host}, port => $port, database => $pgdb->{database}, user => $pgdb->{user}, pwd => $pgdb->{pwd}
    });
    state $pg = Mojo::Pg->new($addr);
    $pg->max_connections($pgdb->{max_connections}) if defined $pgdb->{max_connections};
    return $pg;
}

sub _mysql {
    my $c     = shift;

    my $mysqldb  = $c->config('mysqldb');
    my $port  = (defined $mysqldb->{port}) ? $mysqldb->{port}: 3306;
    my $addr  = $c->pg_url({
        host => $mysqldb->{host}, port => $port, database => $mysqldb->{database}, user => $mysqldb->{user}, pwd => $mysqldb->{pwd}
    });
    $addr =~ s/postgresql/mysql/;
    state $mysql = Mojo::mysql->new($addr);
    $mysql->max_connections($mysqldb->{max_connections}) if defined $mysqldb->{max_connections};
    return $mysql;
}

sub _ip {
    my $c     = shift;

    my $proxy = $c->req->headers->header('X-Forwarded-For');
    my $ip    = ($proxy) ? $proxy : $c->tx->remote_address;

    return $ip;
}

sub _provisioning {
     my $c = shift;

     # Create some short patterns for provisioning
     my $db_url = Lstu::DB::URL->new(app => $c);
     if ($db_url->count_empty < $c->config('provisioning')) {
         for (my $i = 0; $i < $c->config('provis_step'); $i++) {
             my $short;
             do {
                 $short = $c->shortener($c->config('length'));
             } while ($db_url->exist($short) || $short =~ m#^(a|d|cookie|stats|fullstats|login|logout|api)$#);

             $db_url->short($short)->write;
         }
     }
}

sub _prefix {
    my $c = shift;

    my $prefix = $c->url_for('index')->to_abs;
    # Forced domain
    $prefix->host($c->config('fixed_domain')) if (defined($c->config('fixed_domain')) && $c->config('fixed_domain') ne '');
    # Hack for prefix (subdir) handling
    $prefix .= '/' unless ($prefix =~ m#/$#);
    return $prefix;
}

sub _shortener {
    my $c      = shift;
    my $length = shift;

    my @chars  = ('a'..'h', 'j', 'k', 'm'..'z','A'..'H', 'J'..'N', 'P'..'Z','0'..'9', '-', '_');
    my $result = '';
    foreach (1..$length) {
        $result .= $chars[rand scalar(@chars)];
    }
    return $result;
}

sub _is_spam {
    my $c        = shift;
    my $url      = shift;
    my $nb_redir = shift;

    my $ip = $c->ip;
    return { is_spam => 0 } if scalar(grep {/$ip/} @{$c->config('ban_whitelist')});
    my $wl = $c->config('spam_whitelist_regex');
    return { is_spam => 0 } if (defined($wl) && $url->host =~ m/$wl/);

    my $bl      = $c->config('spam_blacklist_regex');
    my $path_bl = $c->config('spam_path_blacklist_regex');
    return {
       is_spam => 1,
       msg     => $c->l('The URL you want to shorten comes from a domain (%1) that is blacklisted on this server (usually because of spammers that use this domain).', $url->host)
    } if ((defined($bl) && $url->host =~ m/$bl/) || (defined($path_bl) && $url->path =~ m/$path_bl/));

    if ($nb_redir++ <= $c->config('max_redir')) {
        my $res = ($c->config('skip_spamhaus')) ? undef : check_fqdn($url->host);
        if (defined $res) {
           return {
               is_spam => 1,
               msg     => $c->l('The URL host or one of its redirection(s) (%1) is blacklisted at Spamhaus. I refuse to shorten it.', $url->host)
           }
        } else {
            if ($c->config('safebrowsing_api_key') && scalar($c->gsb->lookup(url => $url->to_string))) {
                return {
                    is_spam => 1,
                    msg     => $c->l('The URL or one of its redirection(s) (%1) is blacklisted in Google Safe Browsing database. I refuse to shorten it.', $url)
                }
            }
            my $res = $c->ua->get($url)->res;
            if (defined($res->code) && $res->code >= 300 && $res->code < 400) {
                my $new_url = Mojo::URL->new($res->headers->location);
                $new_url->host($url->host)     unless $new_url->host;
                $new_url->scheme($url->scheme) unless $new_url->scheme;
                return $c->is_spam($new_url, $nb_redir);
            } else {
                return { is_spam => 0 };
            }
        }
    } else {
       return {
           is_spam => 1,
           msg     => $c->l('The URL redirects %1 times or most. It\'s most likely a dangerous URL (spam, phishing, etc.). I refuse to shorten it.', $c->config('max_redir'))
       }
    }
}

sub _cleaning {
    my $c = shift;

    # Delete old sessions
    Lstu::DB::Session->new(app => $c)->clear();
    # Delete old bans
    Lstu::DB::Ban->new(app => $c)->clear();
}

sub _gsb {
    my $c = shift;

    # Google safebrowsing (if configured)
    if ($c->config('safebrowsing_api_key')) {
        use Net::Google::SafeBrowsing4;
        use Net::Google::SafeBrowsing4::Storage::File;

        my $force_update = (!-e Mojo::File->new($Bin, '..' , 'safebrowsing_db'));

        my $storage = Net::Google::SafeBrowsing4::Storage::File->new(path => Mojo::File->new($Bin, '..' , 'safebrowsing_db'));

        state $gsb = Net::Google::SafeBrowsing4->new(
            key     => $c->config('safebrowsing_api_key'),
            storage => $storage,
        );

        $c->gsb_update($force_update);

        return $gsb;
    } else {
        return undef;
    }
}

sub _gsb_update {
    my $c            = shift;
    my $force_update = shift;

    return $c->gsb->update() if $force_update;

    my $update = Mojo::File->new($Bin, '..' , 'safebrowsing_db')->to_string;
    my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat($update);
    $c->gsb->update() if ($mtime < time - 86400);
}

1;
