# vim:set sw=4 ts=4 sts=4 ft=perl expandtab:
package Lstu;
use Mojo::Base 'Mojolicious';
use Mojo::JSON;
use Net::LDAP;
use Apache::Htpasswd;
use Lstu::DB::URL;

$ENV{MOJO_REVERSE_PROXY} = 1;

# This method will run once at server start
sub startup {
    my $self = shift;

    my $config = $self->plugin('Config' => {
        default =>  {
            provisioning     => 100,
            provis_step      => 5,
            length           => 8,
            secret           => ['hfudsifdsih'],
            page_offset      => 10,
            theme            => 'default',
            ban_min_strike   => 3,
            ban_whitelist    => [],
            minion           => {
                enabled => 0,
                db_path => 'minion.db'
            },
            session_duration => 3600,
            dbtype           => 'sqlite',
            max_redir        => 2,
            skip_spamhaus    => 0,
        }
    });

    $config->{provisioning} = $config->{provisionning} if (defined($config->{provisionning}));

    die "You need to provide a contact information in lstu.conf!" unless (defined($config->{contact}));

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

    # Lstu Helpers
    $self->plugin('Lstu::Plugin::Helpers');

    # Authentication (if configured)
    if (defined($self->config('ldap')) || defined($self->config('htpasswd'))) {
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
                        my $mesg = $ldap->bind($c->config->{ldap}->{bind_user}.$c->config->{ldap}->{bind_dn},
                            password => $c->config->{ldap}->{bind_pwd}
                        );

                        $mesg->code && die $mesg->error;

                        $mesg = $ldap->search(
                            base   => $c->config->{ldap}->{user_tree},
                            filter => "(&(uid=$username)".$c->config->{ldap}->{user_filter}.")"
                        );

                        if ($mesg->code) {
                            $c->app->log->error($mesg->error);
                            return undef;
                        }

                        # Now we know that the user exists
                        $mesg = $ldap->bind('uid='.$username.$c->config->{ldap}->{bind_dn},
                            password => $password
                        );

                        if ($mesg->code) {
                            $c->app->log->info("[LDAP authentication failed] login: $username, IP: ".$c->ip);
                            $c->app->log->error("[LDAP authentication failed] ".$mesg->error);
                            return undef;
                        }

                        $c->app->log->info("[LDAP authentication successful] login: $username, IP: ".$c->ip);
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
    if ($config->{minion}->{enabled} && $config->{minion}->{db_path}) {
        $self->plugin('Minion' => { SQLite => 'sqlite:'.$config->{minion}->{db_path} });
    }

    # Secrets
    $self->secrets($config->{secret});

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

    $self->hook(after_static => sub {
        my $c = shift;
        $c->res->headers->cache_control('max-age=2592000, must-revalidate');
    });

    # Minion
    if ($config->{minion}->{enabled} && $config->{minion}->{db_path}) {
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
        $r->get('/login' => sub {
            my $c = shift;
            if ($c->is_user_authenticated) {
                $c->redirect_to('index');
            } else {
                $c->render(template => 'login');
            }
        });
        # Authentication
        $r->post('/login' => sub {
            my $c = shift;
            my $login = $c->param('login');
            my $pwd   = $c->param('password');

            if($c->authenticate($login, $pwd)) {
                $c->respond_to(
                    json => sub {
                        my $c = shift;
                        $c->render(
                            json => {
                                success => Mojo::JSON->true,
                                msg     => $c->l('You have been successfully logged in.')
                            }
                        );
                    },
                    any => sub {
                        $c->redirect_to('index');
                    }
                );
            } else {
                my $msg = $c->l('Please, check your credentials: unable to authenticate.');
                $c->respond_to(
                    json => sub {
                        my $c = shift;
                        $c->render(
                            json => {
                                success => Mojo::JSON->false,
                                msg     => $msg
                            }
                        );
                    },
                    any => sub {
                        $c->stash(msg => $msg);
                        $c->render(template => 'login')
                    }
                );
            }
        });
        # Logout page
        $r->get('/logout' => sub {
            my $c = shift;
            if ($c->is_user_authenticated) {
                $c->logout;
            }
            $c->respond_to(
                json => sub {
                    my $c = shift;
                    $c->render(
                        json => {
                            success => Mojo::JSON->true,
                            msg     => $c->l('You have been successfully logged out.')
                        }
                    );
                },
                any => sub {
                    $c->render(template => 'logout');
                }
            );
        })->name('logout');
    }

    $r->get('/api' => sub {
        shift->render(template => 'api');
    })->name('api');

    $r->get('/extensions' => sub {
        shift->render(template => 'extensions');
    })->name('extensions');

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
