# vim:set sw=4 ts=4 sts=4 ft=perl expandtab:
package Lstu::Controller::Admin;
use Digest::SHA qw(sha256_hex);
use Mojo::Base 'Mojolicious::Controller';
use LstuModel;

sub login {
    my $c    = shift;
    my $pwd  = $c->param('adminpwd');
    my $act  = $c->param('action');

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
        $c->flash('msg'    => $c->l('Too many bad passwords. You\'re banned.'));
        $c->flash('banned' => 1);
        $c->redirect_to('stats');
    } else {
        if (
            (defined($c->config('adminpwd')) && defined($pwd) && $pwd eq $c->config('adminpwd')) ||
            (defined($c->config('hashed_adminpwd')) && defined($pwd) && sha256_hex($pwd) eq $c->config('hashed_adminpwd'))
           ) {
            my $token = $c->shortener(32);

            LstuModel::Sessions->create(
                token => $token,
                until => time + 3600
            );
            $c->session('token' => $token);
            $c->redirect_to('stats');
        } elsif (defined($act) && $act eq 'logout') {
            LstuModel::Sessions->delete_where('token = ?', $c->session->{token});
            delete $c->session->{token};
            $c->redirect_to('stats');
        } else {
            my @bans = LstuModel::Ban->select('WHERE ip = ?', $ip);

            if (scalar @bans) {
                $bans[0]->update(
                    strike => $bans[0]->strike + 1,
                    until  => time + 3600
                );
            } else {
                LstuModel::Ban->create(
                    ip     => $ip,
                    strike => 1,
                    until  => time + 3600
                );
            }
            $c->flash('msg' => $c->l('Bad password'));
            $c->redirect_to('stats');
        }
    }
}

sub delete {
    my $c = shift;
    my $short = $c->param('short');

    if (defined($c->session('token')) && LstuModel::Sessions->count('WHERE token = ?', $c->session('token'))) {
        my @urls = LstuModel::Lstu->select('WHERE short = ?', $short);
        if (scalar(@urls)) {
            my $deleted = LstuModel::Lstu->delete_where('short = ?', $short);
            $c->respond_to(
                json => { json => { success => Mojo::JSON->true, deleted => $deleted } },
                any  => sub {
                    my $c = shift;
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
}

1;
