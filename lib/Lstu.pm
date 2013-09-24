package Lstu;
use Mojo::Base 'Mojolicious';
use LstuModel;
use Data::Validate::URI qw(is_uri);

# This method will run once at server start
sub startup {
    my $self = shift;

    my $config = $self->plugin('Config');

    # Default values
    $config->{provisionning} = 100           unless (defined($config->{provisionning}));
    $config->{provis_step}   = 5             unless (defined($config->{provis_step}));
    $config->{length}        = 8             unless (defined($config->{length}));
    $config->{secret}        = 'hfudsifdsih' unless (defined($config->{secret}));

    $self->plugin('I18N');

    $self->secret($config->{secret});

    $self->helper(
        provisionning => sub {
            my $c = shift;

            # Create some short patterns for provisionning
            if (LstuModel::Lstu->count('WHERE url IS NULL') < $c->config->{provisionning}) {
                for (my $i = 0; $i < $c->config->{provis_step}; $i++) {
                    my $short;
                    do {
                        $short= $c->shortener($c->config->{length});
                    } while (LstuModel::Lstu->count('WHERE short = ?', $short));

                    LstuModel::Lstu->create(
                        short => $short
                    );
                }
            }
        }
    );

    $self->helper(
        shortener => sub {
            my $c      = shift;
            my $length = shift;

            my @chars  = ('a'..'z','A'..'Z','0'..'9');
            my $result = '';
            foreach (1..$length) {
                $result .= $chars[rand scalar(@chars)];
            }
            return $result;
        }
    );

    # For the first launch (after, this isn't really useful)
    $self->provisionning();

    # Router
    my $r = $self->routes;

    # Normal route to controller
    $r->get('/' => sub {
        my $c = shift;

        $c->render(template => 'index');

        # Check provisionning
        $c->on(finish => sub {
            shift->provisionning();
        });
    })->name('index');

    $r->get('/:short' => sub {
        my $c = shift;
        my $short = $c->param('short');

        my @urls = LstuModel::Lstu->select('WHERE short = ?', $short);
        if (scalar(@urls)) {
            $c->res->code(301);
            $c->redirect_to($urls[0]->url);

            # Update counter and check provisionning
            $c->on(finish => sub {
                my $counter = $urls[0]->counter + 1;
                $urls[0]->update (counter => $counter);

                shift->provisionning();
            });
        } else {
            $c->flash(
                msg => $c->l('url_not_found', $c->url_for('/')->to_abs.$short)
            );
            $c->redirect_to('/');
        }
    })->name('short');

    my $add = sub {
        my $c   = shift;
        my $url = $c->param('lsturl');

        if (is_uri($url)) {
            my $short;

            my @keys = $c->param;
            my @params;
            foreach my $key (sort @keys) {
                push @params, $key.'='.$c->param($key) unless ($key eq 'lsturl');
            }
            $url .= '?'.join('&', @params) if (scalar(@params));

            my @records = LstuModel::Lstu->select('WHERE url = ?', $url);

            if (scalar(@records)) {
                # Already got this URL
                $c->flash(
                    short => $records[0]->short,
                    url   => $url
                );
            } else {
                @records = LstuModel::Lstu->select('WHERE url IS NULL LIMIT 1');
                if (scalar(@records)) {
                    $records[0]->update(
                        url       => $url,
                        counter   => 0,
                        timestamp => time()
                    );

                    $c->flash(
                        short => $records[0]->short,
                        url   => $url
                    );
                } else {
                    # Houston, we have a problem
                    $c->flash(
                        msg => $c->l('no_more_short', $c->config->{contact}, $url)
                    );
                }
            }
        } else {
            $c->app->log->debug($c->l('no_valid_url', $url));
            $c->flash(
                msg => $c->l('no_valid_url', $url)
            );
        }
        $c->redirect_to('/');

        # Check provisionning
        $c->on(finish => sub {
            shift->provisionning();
        });
    };

    $r->post('/a/' => $add)->name('add');

    $r->get('/a/*lsturl' => $add)->name('addurl');
}

1;
