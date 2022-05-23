# vim:set sw=4 ts=4 sts=4 ft=perl expandtab:
package Lstu;
use Mojo::Base 'Mojolicious';
use Mojo::JSON;
use Lstu::DB::URL;
use Lstu::DefaultConfig qw($default_config);

$ENV{MOJO_REVERSE_PROXY} = 1;

# This method will run once at server start
sub startup {
    my $self = shift;

    my $config = $self->plugin('Config' => {
        default => $default_config
    });

    $config->{provisioning} = $config->{provisionning} if (defined($config->{provisionning}));

    die "You need to provide a contact information in lstu.conf!" unless (defined($config->{contact}));

    # qrcode_size correction if needed;
    $self->config('qrcode_size', 100) if $self->config('qrcode_size') > 100;
    $self->config('qrcode_size', 1  ) if $self->config('qrcode_size') < 1;
    $self->config('qrcode_size', sprintf('%d', $self->config('qrcode_size')));

    # Themes handling
    shift @{$self->renderer->paths};
    shift @{$self->static->paths};
    if ($config->{theme} ne 'default') {
        my $theme = $self->home->rel_file('themes/'.$config->{theme});
        push @{$self->renderer->paths}, $theme.'/templates' if -d $theme.'/templates';
        push @{$self->static->paths}, $theme.'/public' if -d $theme.'/public';
    }
    push @{$self->renderer->paths}, $self->home->rel_file('themes/default/templates');
    push @{$self->static->paths}, $self->home->rel_file('themes/default/public');

    # Internationalization
    my $lib = $self->home->rel_file('themes/'.$config->{theme}.'/lib');
    eval qq(use lib "$lib");
    $self->plugin('I18N');

    # Debug
    $self->plugin('DebugDumperHelper');

    # Piwik
    $self->plugin('Piwik');

    # Static assets gzipping
    $self->plugin('GzipStatic');

    # URL cache
    if (scalar(@{$config->{memcached_servers}})) {
        $self->plugin(CHI => {
            lstu_urls_cache => {
                driver             => 'Memcached',
                servers            => $config->{memcached_servers},
                expires_in         => '1 day',
                expires_on_backend => 1,
            }
        });
    }

    # Headers
    $self->plugin('Lstu::Plugin::Headers');

    # Lstu Helpers
    $self->plugin('Lstu::Plugin::Helpers');

    # Authentication (if configured)
    if (defined($self->config('ldap')) || defined($self->config('htpasswd'))) {
        if (defined($self->config('ldap'))) {
            require Net::LDAP;
        }
        if (defined($self->config('htpasswd'))) {
            require Apache::Htpasswd;
        }
        die 'Unable to read '.$self->config('htpasswd') if (defined($self->config('htpasswd')) && !-r $self->config('htpasswd'));
        $self->plugin('Authentication' =>
            {
                autoload_user => 1,
                session_key   => 'Lstu',
                load_user     => sub {
                    my ($c, $username) = @_;

                    return $username;
                },
                validate_user => sub {
                    my ($c, $username, $password, $extradata) = @_;

                    if (defined($c->config('ldap'))) {
                        my $ldap = Net::LDAP->new($c->config->{ldap}->{uri});

                        my $mesg;
                        if (defined($c->config->{ldap}->{bind_dn}) && defined($c->config->{ldap}->{bind_pwd})) {
                            # connect to the ldap server using the bind credentials
                            $mesg = $ldap->bind(
                                $c->config->{ldap}->{bind_dn},
                                password => $c->config->{ldap}->{bind_pwd}
                            );
                        } else {
                            # anonymous bind
                            $mesg = $ldap->bind
                        }

                        if ($mesg->code) {
                            $c->app->log->info('[LDAP INFO] Authenticated bind failed - Login: '.$c->config->{ldap}->{bind_dn}) if defined($c->config->{ldap}->{bind_dn});
                            $c->app->log->error('[LDAP ERROR] Error on bind: '.$mesg->error);
                            return undef;
                        }

                        my $ldap_user_attr   = $c->config->{ldap}->{user_attr};
                        my $ldap_user_filter = $c->config->{ldap}->{user_filter};

                        # search the ldap database for the user who is trying to login
                        $mesg = $ldap->search(
                            base   => $c->config->{ldap}->{user_tree},
                            filter => "(&($ldap_user_attr=$username)$ldap_user_filter)"
                        );

                        if ($mesg->code) {
                            $c->app->log->error('[LDAP ERROR] Error on search: '.$mesg->error);
                            return undef;
                        }

                        # check to make sure that the ldap search returned at least one entry
                        my @entries = $mesg->entries;
                        my $entry   = $entries[0];

                        unless (defined $entry) {
                            $c->app->log->info("[LDAP INFO] Authentication failed - User $username filtered out, IP: ".$c->ip);
                            return undef;
                        }

                        # retrieve the first user returned by the search
                        $c->app->log->debug("[LDAP DEBUG] Found user dn: ".$entry->dn);

                        # Now we know that the user exists
                        $mesg = $ldap->bind($entry->dn,
                            password => $password
                        );

                        if ($mesg->code) {
                            $c->app->log->info("[LDAP INFO] Authentication failed - Login: $username, IP: ".$c->ip);
                            $c->app->log->error('[LDAP ERROR] Authentication failed '.$mesg->error);
                            return undef;
                        }

                        $c->app->log->info("[LDAP INFO] Authentication successful - Login: $username, IP: ".$c->ip);
                    } elsif (defined($c->config('htpasswd'))) {
                        my $htpasswd = new Apache::Htpasswd(
                            {
                                passwdFile => $c->config('htpasswd'),
                                ReadOnly   => 1
                            }
                        );
                        if (!$htpasswd->htCheckPassword($username, $password)) {
                            return undef;
                        }
                        $c->app->log->info("[Simple authentication successful] login: $username, IP: ".$c->ip);
                    }

                    return $username;
                }
            }
        );
        $self->app->sessions->default_expiration($self->config('session_duration'));
    }

    # Minion
    if ($config->{minion}->{enabled}) {
        if ($config->{dbtype} eq 'sqlite') {
            $self->plugin('Minion' => { SQLite => 'sqlite:'.$config->{minion}->{db_path} }) if $config->{minion}->{db_path};
        } elsif ($config->{dbtype} eq 'postgresql') {
            my $pgdb  = $config->{minion}->{pgdb};
            my $port  = (defined $pgdb->{port}) ? $pgdb->{port}: 5432;
            my $addr  = $self->pg_url({
                host => $pgdb->{host}, port => $port, database => $pgdb->{database}, user => $pgdb->{user}, pwd => $pgdb->{pwd}
            });

            $self->plugin('Minion' => { Pg => $addr });
        } elsif ($config->{dbtype} eq 'mysql') {
            my $mysqldb = $config->{minion}->{mysqldb};
            my $port    = (defined $mysqldb->{port}) ? $mysqldb->{port}: 3306;
            my $addr    = $self->pg_url({
                host => $mysqldb->{host}, port => $port, database => $mysqldb->{database}, user => $mysqldb->{user}, pwd => $mysqldb->{pwd}
            });

            $addr =~ s/postgresql/mysql/;

            $self->plugin('Minion' => { mysql => $addr });
        }
    }

    # Secrets
    $self->secrets($config->{secret});

    # Hooks
    $self->hook(
        before_dispatch => sub {
            my $c = shift;

            # API allowed domains
            if (defined($c->config('allowed_domains')) && scalar @{$c->config('allowed_domains')}) {
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

    # Recurrent tasks
    Mojo::IOLoop->recurring(2 => sub {
        my $loop = shift;

        $self->provisioning();
    });
    if ($self->config('safebrowsing_api_key')) {
        $self->gsb(1);
        Mojo::IOLoop->recurring(86400 => sub {
            my $loop = shift;

            $self->gsb(1);
        });
    }

    # Minion
    if ($config->{minion}->{enabled}) {
        $self->app->minion->add_task(
            increase_counter => sub {
                my $job   = shift;
                my $short = shift;
                my $url   = shift;

                my $db_url = Lstu::DB::URL->new(
                    app    => $job->app,
                    short  => $short
                )->increment_counter;

                my $piwik = $job->app->config('piwik');
                if (defined($piwik) && $piwik->{idsite} && $piwik->{url}) {
                    $job->app->piwik_api(
                        'Track' => {
                            idSite     => $piwik->{idsite},
                            action_url => $url,
                            url        => $piwik->{url}
                        }
                    );
                }
            }
        );
    }

    # For the first launch (after, this isn't really useful)
    $self->provisioning();

    # Default layout
    $self->defaults(layout => 'default');

    # Router
    my $r = $self->routes;

    # Normal route to controller
    $r->get('/' => sub {
        my $c = shift;
        if ((!defined($c->config('ldap')) && !defined($c->config('htpasswd'))) || $c->is_user_authenticated) {
            $c->render(template => 'index');
        } else {
            $c->redirect_to('login');
        }
    })->name('index');

    if (defined $self->config('ldap') || defined $self->config('htpasswd')) {
        # Login page
        $r->get('/login')
            ->to('Authent#index')
            ->name('login');

        # Authentication
        $r->post('/login')
            ->to('Authent#login');

        # Logout page
        $r->get('/logout')
            ->to('Authent#log_out')
            ->name('logout');
    }

    $r->get('/api' => sub {
        shift->render(template => 'api');
    })->name('api');

    $r->get('/partial/lstu.js' => sub {
        my $c = shift;
        $c->render(
            template => 'partial/lstu',
            format   => 'js'
        );
    })->name('lstu.js');

    $r->get('/extensions' => sub {
        shift->render(template => 'extensions');
    })->name('extensions');

    $r->post('/stats')
        ->to('Admin#login');

    $r->get('/d/:short')
        ->to('Admin#delete')
        ->name('delete');

    $r->post('/a')
        ->to('URL#add')
        ->name('add');

    $r->get('/cookie')
        ->to('Stats#export_cookie')
        ->name('export_cookie');

    $r->post('/cookie')
        ->to('Stats#import_cookie')
        ->name('import_cookie');

    $r->get('/stats')
        ->to('Stats#stats')
        ->name('stats');

    $r->get('/stats/:short')
        ->to('Stats#stat_for_one_short')
        ->name('stat_for_one_short');

    $r->get('/fullstats')
        ->to('Stats#fullstats')
        ->name('fullstats');

    $r->get('/:short')
        ->to('URL#get')
        ->name('short');
}

1;
