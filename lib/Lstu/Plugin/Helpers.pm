package Lstu::Plugin::Helpers;
use Mojo::Base 'Mojolicious::Plugin';
use Mojo::URL;
use Mojo::Collection;
use Net::Abuse::Utils::Spamhaus qw(check_fqdn);
use Lstu::DB::URL;
use Lstu::DB::Ban;
use Lstu::DB::Session;

sub register {
    my ($self, $app) = @_;

    if ($app->config('dbtype') eq 'postgresql') {
        use Mojo::Pg;
        $app->helper(pg => \&_pg);

        # Database migration
        my $migrations = Mojo::Pg::Migrations->new(pg => $app->pg);
        if ($app->mode eq 'development') {
            $migrations->from_file('utilities/migrations.sql')->migrate(0)->migrate(2);
        } else {
            $migrations->from_file('utilities/migrations.sql')->migrate(2);
        }
    } elsif ($app->config('dbtype') eq 'mysql') {
        use Mojo::mysql;
        $app->helper(mysql => \&_mysql);

        # Database migration
        my $migrations = Mojo::mysql::Migrations->new(mysql => $app->mysql);
        if ($app->mode eq 'development') {
            $migrations->from_file('utilities/migrations_mysql.sql')->migrate(0)->migrate(2);
        } else {
            $migrations->from_file('utilities/migrations_mysql.sql')->migrate(2);
        }
    } elsif ($app->config('dbtype') eq 'sqlite') {
        # Database migration (equivalent to 2 in postgresql migrations)
        my $missing = Mojo::Collection->new('expires_at', 'expires_after');
        my $columns = Lstu::DB::SQLite::Lstu->table_info;
        for my $c (@$columns) {
            $missing = $missing->grep(sub { $_ ne $c->{name} });
        }
        $missing->each(
            sub {
                my ($e, $num) = @_;
                Lstu::DB::SQLite->do("ALTER TABLE lstu ADD $e INTEGER");
            }
        );
    }

    $app->helper(cache => \&_cache);
    $app->helper(clear_cache => \&_clear_cache);
    $app->helper(ip => \&_ip);
    $app->helper(provisioning => \&_provisioning);
    $app->helper(prefix => \&_prefix);
    $app->helper(shortener => \&_shortener);
    $app->helper(is_spam => \&_is_spam);
    $app->helper(cleaning => \&_cleaning);
}

sub _pg {
    my $c     = shift;

    my $addr  = 'postgresql://';
    $addr    .= $c->config->{pgdb}->{host};
    $addr    .= ':'.$c->config->{pgdb}->{port} if defined $c->config->{pgdb}->{port};
    $addr    .= '/'.$c->config->{pgdb}->{database};
    state $pg = Mojo::Pg->new($addr);
    $pg->password($c->config->{pgdb}->{pwd});
    $pg->username($c->config->{pgdb}->{user});
    return $pg;
}

sub _mysql {
    my $c     = shift;

    my $addr  = 'mysql://';
    $addr    .= $c->config->{mysqldb}->{host};
    $addr    .= ':'.$c->config->{mysqldb}->{port} if defined $c->config->{pgdb}->{port};
    $addr    .= '/'.$c->config->{mysqldb}->{database};
    state $mysql = Mojo::mysql->new($addr);
    $mysql->password($c->config->{mysqldb}->{pwd});
    $mysql->username($c->config->{mysqldb}->{user});
    return $mysql;
}

sub _cache {
    my $c        = shift;

    state $cache = {};
}

sub _clear_cache {
    my $c     = shift;

    my $cache = $c->cache;
    my @keys  = keys %{$cache};

    my $limit = ($c->app->mode eq 'production') ? 500 : 1;
    map {delete $cache->{$_};} @keys if (scalar(@keys) > $limit);
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
             } while ($db_url->exist($short));

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

    if ($nb_redir++ <= 2) {
        my $res = check_fqdn($url->host);
        if (defined $res) {
           return {
               is_spam => 1,
               msg     => $c->l('The URL host or one of its redirection(s) (%1) is blacklisted at Spamhaus. I refuse to shorten it.', $url->host)
           }
        } else {
            my $res = $c->ua->get($url)->res;
            if ($res->code >= 300 && $res->code < 400) {
                return $c->is_spam(Mojo::URL->new($res->headers->location), $nb_redir);
            } else {
                return { is_spam => 0 };
            }
        }
    } else {
       return {
           is_spam => 1,
           msg     => $c->l('The URL redirects 3 times or most. It\'s most likely a dangerous URL (spam, phishing, etc.). I refuse to shorten it.', $url->host)
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

1;
