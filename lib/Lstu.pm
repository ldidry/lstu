# vim:set sw=4 ts=4 sts=4 ft=perl expandtab:
package Lstu;
use Mojo::Base 'Mojolicious';
use LstuModel;
use Data::Validate::URI qw(is_http_uri is_https_uri);
use Mojo::JSON qw(to_json decode_json);
use Mojo::URL;
use Net::Abuse::Utils::Spamhaus qw(check_fqdn);

$ENV{MOJO_REVERSE_PROXY} = 1;

# This method will run once at server start
sub startup {
    my $self = shift;

    my $config = $self->plugin('Config' => {
        default =>  {
            provisioning    => 100,
            provis_step     => 5,
            length          => 8,
            secret          => ['hfudsifdsih'],
            page_offset     => 10,
            theme           => 'default',
            ban_min_strike  => 3
        }
    });

    $config->{provisioning} = $config->{provisionning} if (defined($config->{provisionning}));

    die "You need to provide a contact information in lstu.conf!" unless (defined($config->{contact}));

    # Themes handling
    shift @{$self->renderer->paths};
    shift @{$self->static->paths};
    if ($config->{theme} ne 'default') {
        my $theme = $self->home->rel_dir('themes/'.$config->{theme});
        push @{$self->renderer->paths}, $theme.'/templates' if -d $theme.'/templates';
        push @{$self->static->paths}, $theme.'/public' if -d $theme.'/public';
    }
    push @{$self->renderer->paths}, $self->home->rel_dir('themes/default/templates');
    push @{$self->static->paths}, $self->home->rel_dir('themes/default/public');

    # Internationalization
    my $lib = $self->home->rel_dir('themes/'.$config->{theme}.'/lib');
    eval qq(use lib "$lib");
    $self->plugin('I18N');

    # Debug
    $self->plugin('DebugDumperHelper');

    # Schema updates
    LstuModel->do('CREATE TABLE IF NOT EXISTS sessions (token TEXT PRIMARY KEY, until INTEGER)');
    LstuModel->do('CREATE TABLE IF NOT EXISTS ban (ip TEXT PRIMARY KEY, until INTEGER, strike INTEGER)');

    $self->secrets($config->{secret});

    # Helpers
    $self->helper(
        cache => sub {
            my $c        = shift;
            state $cache = {};
        }
    );

    $self->helper(
        clear_cache => sub {
            my $c     = shift;
            my $cache = $c->cache;
            my @keys  = keys %{$cache};

            my $limit = ($c->app->mode eq 'production') ? 500 : 1;
            map {delete $cache->{$_};} @keys if (scalar(@keys) > $limit);
        }
    );

    $self->helper(
        ip => sub {
            my $c     = shift;
            my $proxy = $c->req->headers->header('X-Forwarded-For');
            my $ip    = ($proxy) ? $proxy : $c->tx->remote_address;

            return $ip;
        }
    );

    $self->helper(
        provisioning => sub {
            my $c = shift;

            # Create some short patterns for provisioning
            if (LstuModel::Lstu->count('WHERE url IS NULL') < $c->config('provisioning')) {
                for (my $i = 0; $i < $c->config('provis_step'); $i++) {
                    if (LstuModel->begin) {
                        my $short;
                        do {
                            $short= $c->shortener($c->config('length'));
                        } while (LstuModel::Lstu->count('WHERE short = ?', $short));

                        LstuModel::Lstu->create(
                            short => $short
                        );
                        LstuModel->commit;
                    }
                }
            }
        }
    );

    $self->helper(
        prefix => sub {
            my $c = shift;

            my $prefix = $c->url_for('index')->to_abs;
            # Forced domain
            $prefix->host($c->config('fixed_domain')) if (defined($c->config('fixed_domain')));
            # Hack for prefix (subdir) handling
            $prefix .= '/' unless ($prefix =~ m#/$#);
            return $prefix;
        }
    );

    $self->helper(
        shortener => sub {
            my $c      = shift;
            my $length = shift;

            my @chars  = ('a'..'z','A'..'Z','0'..'9', '-', '_');
            my $result = '';
            foreach (1..$length) {
                $result .= $chars[rand scalar(@chars)];
            }
            return $result;
        }
    );

    $self->helper(
        is_spam => sub {
            my $c        = shift;
            my $url      = shift;
            my $nb_redir = shift;

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
    );

    $self->helper(
        cleaning => sub {
            my $c = shift;

            # Delete old sessions
            LstuModel::Sessions->delete_where('until < ?', time);
            # Delete old bans
            LstuModel::Ban->delete_where('until < ?', time);
        }
    );

    # Hooks
    $self->hook(
        after_dispatch => sub {
            shift->provisioning();
        }
    );

    $self->hook(
        before_dispatch => sub {
            my $c = shift;

            # API allowed domains
            if (defined($c->config('allowed_domains'))) {
                if ($c->config('allowed_domains')->[0] eq '*') {
                    $c->res->headers->header('Access-Control-Allow-Origin' => '*');
                } elsif (my $origin = $c->req->headers->origin) {
                    for my $domain (@{$c->config('allowed_domains')}) {
                        if ($domain eq $origin) {
                            $c->res->headers->header('Access-Control-Allow-Origin' => $origin);
                            last;
                        }
                    }
                }
            }
        }
    );
    $self->hook(after_static => sub {
        my $c = shift;
        $c->res->headers->cache_control('max-age=2592000, must-revalidate');
    });

    # For the first launch (after, this isn't really useful)
    $self->provisioning();

    # Default layout
    $self->defaults(layout => 'default');

    # Router
    my $r = $self->routes;

    # Normal route to controller
    $r->get('/' => sub {
        shift->render(template => 'index');
    })->name('index');

    $r->get('/api' => sub {
        shift->render(template => 'api');
    })->name('api');

    $r->post('/stats')
        ->to('Admin#login');

    $r->get('/d/:short')
        ->to('Admin#delete')
        ->name('delete');

    $r->post('/a')
        ->to('Lstu#add')
        ->name('add');

    $r->get('/stats')
        ->to('Lstu#stats')
        ->name('stats');

    $r->get('/:short')
        ->to('Lstu#get')
        ->name('short');
}

1;
