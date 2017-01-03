# vim:set sw=4 ts=4 sts=4 ft=perl expandtab:
package Lstu::Controller::Lstu;
use Mojo::Base 'Mojolicious::Controller';
use LstuModel;
use Data::Validate::URI qw(is_http_uri is_https_uri);
use Mojo::JSON qw(to_json decode_json);
use Mojo::URL;

sub add {
    my $c = shift;

    $c->cleaning;

    my $ip = $c->ip;

    my @banned = LstuModel::Ban->select('WHERE ip = ? AND until > ? AND strike >= ?', $ip, time, $c->config('ban_min_strike'));
    if (scalar @banned) {
        my $penalty = 3600;
        if ($banned[0]->strike >= 2 * $c->config('ban_min_strike')) {
            $penalty = 3600 * 24 * 30; # 30 days of banishing
        }
        $banned[0]->update(
            strike => $banned[0]->strike + 1,
            until  => time + $penalty
        );
        my $msg = $c->l('You asked to shorten too many URLs too quickly. You\'re banned for %1 hour(s).', $penalty/3600);
        $c->respond_to(
            json => { json => { success => Mojo::JSON->false, msg => $msg } },
            any  => sub {
                my $c = shift;

                $c->flash('msg' => $msg);
                $c->flash('banned' => 1);
                $c->redirect_to('index');
            }
        );
    } else {
        my $lsturl     = $c->param('lsturl');
        $lsturl        =~ s/^\s+|\s+$//g;
        my $url        = Mojo::URL->new($lsturl);
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

                my @bans = LstuModel::Ban->select('WHERE ip = ?', $ip);
                if (scalar @bans) {
                    $bans[0]->update(
                        strike => $bans[0]->strike + 1,
                        until  => time + 1
                    );
                } else {
                    LstuModel::Ban->create(
                        ip     => $ip,
                        strike => 1,
                        until  => time + 1
                    );
                }

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
    }
}

sub stats {
    my $c = shift;

    if (defined($c->session('token')) && LstuModel::Sessions->count('WHERE token = ?', $c->session('token'))) {
        my $total = LstuModel::Lstu->count("WHERE url IS NOT NULL");
        my $page  = $c->param('page') || 0;
           $page  = 0 if ($page < 0);
           $page  = $page - 1 if ($page * $c->config('page_offset') > $total);

        my ($first, $last) = (!$page, ($page * $c->config('page_offset') <= $total && $total < ($page + 1) * $c->config('page_offset')));

        my @urls  = LstuModel::Lstu->select("WHERE url IS NOT NULL ORDER BY counter DESC LIMIT ? offset ?", $c->config('page_offset'), $page * $c->config('page_offset'));
        $c->respond_to(
            json => sub {
                my $c = shift;
                $c->render(
                    json => {
                        prefix   => $c->prefix,
                        urls     => \@urls,
                        first    => $first,
                        last     => $last,
                        page     => $page,
                        admin    => 1,
                        total    => $total
                    }
                );
            },
            any => sub {
                my $c = shift;
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
            }
        );
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
}

sub get {
    my $c = shift;
    my $short = $c->param('short');

    my ($url, @urls);
    if (defined $c->cache->{$short}) {
        $url = $c->cache->{$short}->{url};
    } else {
        @urls = LstuModel::Lstu->select('WHERE short = ?', $short);
        if (scalar(@urls)) {
            $url = $urls[0]->url;
        }
    }
    if ($url) {
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
            @urls = LstuModel::Lstu->select('WHERE short = ?', $short) if (defined $c->cache->{$short});
            $c->cache->{$short} = {
                last_used => time,
                url       => $url
            };

            if ($c->config('minion')->{enabled} && $c->config('minion')->{db_path}) {
                $c->app->minion->enqueue(increase_counter => [$short, $c->{url}]);
            } else {
                my $counter = $urls[0]->counter + 1;
                $urls[0]->update(counter => $counter);

                my $piwik = $c->config('piwik');
                if (defined($piwik) && $piwik->{idsite} && $piwik->{url}) {
                    $c->piwik_api(
                        'Track' => {
                            idSite     => $piwik->{idsite},
                            action_url => $c->{url},
                            url        => $piwik->{url}
                        }
                    );
                }

            }
            $c->clear_cache;
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
}

1;
