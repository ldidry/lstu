package Lstu::Plugin::Helpers;
use Mojo::Base 'Mojolicious::Plugin';
use Mojo::URL;
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
            $migrations->from_file('utilities/migrations.sql')->migrate(0)->migrate(1);
        } else {
            $migrations->from_file('utilities/migrations.sql')->migrate(1);
        }
    } elsif ($app->config('dbtype') eq 'mysql') {
        use Mojo::mysql;
        $app->helper(mysql => \&_mysql);

        # Database migration
        my $migrations = Mojo::mysql::Migrations->new(mysql => $app->mysql);
        if ($app->mode eq 'development') {
            $migrations->from_file('utilities/migrations_mysql.sql')->migrate(0)->migrate(1);
        } else {
            $migrations->from_file('utilities/migrations_mysql.sql')->migrate(1);
        }
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
    $pg->max_connections($c->config->{pgdb}->{max_connections}) if defined $c->config->{pgdb}->{max_connections};
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
    $mysql->max_connections($c->config->{mysqldb}->{max_connections}) if defined $c->config->{mysqldb}->{max_connections};
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
            my $res = $c->ua->get($url)->res;
            if ($res->code >= 300 && $res->code < 400) {
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

1;
