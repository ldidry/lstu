# vim:set sw=4 ts=4 sts=4 ft=perl expandtab:
package Lstu;
use Mojo::Base 'Mojolicious';
use LstuModel;
use SessionModel;
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
            provisioning => 100,
            provis_step   => 5,
            length        => 8,
            secret        => ['hfudsifdsih'],
            page_offset   => 10,
            theme         => 'default'
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

    $self->secrets($config->{secret});

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

    # Hooks
    $self->hook(
        after_dispatch => sub {
            shift->provisioning();
        }
    );

    $self->hook(
        before_dispatch => sub {
            my $c = shift;

            # Delete old sessions
            SessionModel::Sessions->delete_where('until < ?', time);
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

    $r->post('/a' => sub {
        my $c          = shift;
        my $url        = Mojo::URL->new($c->param('lsturl'));
        my $custom_url = $c->param('lsturl-custom');
        my $format     = $c->param('format');

        $custom_url = undef if (defined($custom_url) && $custom_url eq '');

        my ($msg, $short);
        if (defined($custom_url) && ($custom_url =~ m/^a(pi)?$|^stats$/ || $custom_url =~ m/^d$/ ||
            $custom_url =~ m/\.json$/ || $custom_url !~ m/^[-a-zA-Z0-9_]+$/))
        {
            $msg = $c->l('The shortened text can contain only numbers, letters and the - and _ character, can\'t be "a", "api", "d" or "stats" or end with ".json". Your URL to shorten: %1', $url);
        } elsif (defined($custom_url) && LstuModel::Lstu->count('WHERE short = ?', $custom_url) > 0) {
            $msg = $c->l('The shortened text (%1) is already used. Please choose another one.', $custom_url);
        } elsif (is_http_uri($url->to_string) || is_https_uri($url->to_string)) {
            my $res = $c->is_spam($url, 0);
            if ($res->{is_spam}) {
                $msg = $res->{msg};
            } else {
                my @records = LstuModel::Lstu->select('WHERE url = ?', $url);

                if (scalar(@records) && !defined($custom_url)) {
                    # Already got this URL
                    $short = $records[0]->short;
                } else {
                    if(LstuModel->begin) {
                        if (defined($custom_url)) {
                            LstuModel::Lstu->create(
                                short     => $custom_url,
                                url       => $url,
                                counter   => 0,
                                timestamp => time()
                            );

                            $short = $custom_url;
                        } else {
                            @records = LstuModel::Lstu->select('WHERE url IS NULL LIMIT 1');
                            if (scalar(@records)) {
                                $records[0]->update(
                                    url       => $url,
                                    counter   => 0,
                                    timestamp => time()
                                );

                                $short = $records[0]->short;
                            } else {
                                # Houston, we have a problem
                                $msg = $c->l('No shortened URL available. Please retry or contact the administrator at %1. Your URL to shorten: [_2]', $c->config('contact'), $url);
                            }
                        }
                        LstuModel->commit;
                    }
                }
            }
        } else {
            $msg = $c->l('%1 is not a valid URL.', $url);
        }
        if ($msg) {
            $c->respond_to(
                json => { json => { success => Mojo::JSON->false, msg => $msg } },
                any  => sub {
                    my $c = shift;

                    $c->flash('msg' => $msg);
                    $c->redirect_to('index');
                }
            );
        } else {
            # Get URLs from cookie
            my $u = (defined($c->cookie('url'))) ? decode_json $c->cookie('url') : [];
            # Add the new URL
            push @{$u}, $short;
            # Make the array contain only unique URLs
            my %k = map { $_, 1 } @{$u};
            @{$u} = keys %k;
            # And set the cookie
            my $cookie = to_json($u);
            $c->cookie('url' => $cookie, {expires => time + 142560000}); # expires in 10 years

            my $prefix = $c->prefix;

            $c->respond_to(
                json => { json => { success => Mojo::JSON->true, url => $url, short => $prefix.$short } },
                any  => sub {
                    my $c = shift;

                    $c->flash('url'   => $url);
                    $c->flash('short' => $prefix.$short);
                    $c->redirect_to('index');
                }
            );
        }
    })->name('add');

    $r->get('/api' => sub {
        shift->render(
            template => 'api'
        );
    })->name('api');

    $r->get('/stats' => sub {
        my $c = shift;

        if (defined($c->session('token')) && SessionModel::Sessions->count('WHERE token = ?', $c->session('token'))) {
            my $total = LstuModel::Lstu->count("WHERE url IS NOT NULL");
            my $page  = $c->param('page') || 0;
               $page  = 0 if ($page < 0);
               $page  = $page - 1 if ($page * $c->config('page_offset') > $total);

            my ($first, $last) = (!$page, ($page * $c->config('page_offset') <= $total && $total < ($page + 1) * $c->config('page_offset')));

            my @urls  = LstuModel::Lstu->select("WHERE url IS NOT NULL ORDER BY counter DESC LIMIT ? offset ?", $c->config('page_offset'), $page * $c->config('page_offset'));
            $c->render(
                template => 'stats',
                prefix   => $c->prefix,
                urls     => \@urls,
                first    => $first,
                last     => $last,
                page     => $page,
                admin    => 1,
                total    => $total
            )
        } else {
            my $u = (defined($c->cookie('url'))) ? decode_json $c->cookie('url') : [];

            my $p = join ",", (('?') x @{$u});
            my @urls = LstuModel::Lstu->select("WHERE short IN ($p) ORDER BY counter DESC", @{$u});

            my $prefix = $c->prefix;

            $c->respond_to(
                json => sub {
                    my @struct;
                    for my $url (@urls) {
                        push @struct, {
                            short      => $prefix.$url->{short},
                            url        => $url->{url},
                            counter    => $url->{counter},
                            created_at => $url->{timestamp}
                        };
                    }
                    $c->render( json => \@struct );
                },
                any  => sub {
                    shift->render(
                        template => 'stats',
                        prefix   => $prefix,
                        urls     => \@urls
                    )
                }
            )
        }
    })->name('stats');

    $r->post('/stats' => sub {
        my $c    = shift;
        my $pwd  = $c->param('adminpwd');
        my $act  = $c->param('action');

        if (defined($c->config('adminpwd')) && defined($pwd) && $pwd eq $c->config('adminpwd')) {
            my $token = $c->shortener(32);

            SessionModel::Sessions->create(token => $token, until => time + 3600);
            $c->session('token' => $token);
            $c->redirect_to('stats');
        } elsif (defined($act) && $act eq 'logout') {
            SessionModel::Sessions->delete_where('token = ?', $c->session->{token});
            delete $c->session->{token};
            $c->redirect_to('stats');
        } else {
            $c->flash('msg' => $c->l('Bad password'));
            $c->redirect_to('stats');
        }
    });

    $r->get('/d/:short' => sub {
        my $c = shift;
        my $short = $c->param('short');

        if (defined($c->session('token')) && SessionModel::Sessions->count('WHERE token = ?', $c->session('token'))) {
            my @urls = LstuModel::Lstu->select('WHERE short = ?', $short);
            if (scalar(@urls)) {
                my $deleted = LstuModel::Lstu->delete_where('short = ?', $short);
                $c->respond_to(
                    json => { json => { success => Mojo::JSON->true, deleted => $deleted } },
                    any  => sub {
                        my $c = shift;
                        $c->res->code(301);
                        $c->redirect_to('stats');
                    }
                );
            } else {
                my $msg = $c->l('The shortened URL %1 doesn\'t exist.', $c->url_for('/')->to_abs.$short);
                $c->respond_to(
                    json => { json => { success => Mojo::JSON->false, msg => $msg } },
                    any  => sub {
                        my $c = shift;
                        $c->flash('msg' => $msg);
                        $c->redirect_to('stats');
                    }
                );
            }
        } else {
            $c->flash('msg' => $c->l('Bad password'));
            $c->redirect_to('stats');
        }
    })->name('delete');

    $r->get('/:short' => sub {
        my $c = shift;
        my $short = $c->param('short');

        my @urls = LstuModel::Lstu->select('WHERE short = ?', $short);
        if (scalar(@urls)) {
            my $url = $urls[0]->url;
            $c->respond_to(
                json => { json => { success => Mojo::JSON->true, url => $url } },
                any  => sub {
                    my $c = shift;
                    $c->res->code(301);
                    $c->redirect_to($url);
                }
            );
            # Update counter
            $c->on(finish => sub {
                my $counter = $urls[0]->counter + 1;
                $urls[0]->update (counter => $counter);
            });
        } else {
            my $msg = $c->l('The shortened URL %1 doesn\'t exist.', $c->url_for('/')->to_abs.$short);
            $c->respond_to(
                json => { json => { success => Mojo::JSON->false, msg => $msg } },
                any  => sub {
                    my $c = shift;

                    $c->flash('msg' => $msg);
                    $c->redirect_to('index');
                }
            );
        }
    })->name('short');
}

1;
