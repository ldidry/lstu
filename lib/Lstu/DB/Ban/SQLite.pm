# vim:set sw=4 ts=4 sts=4 ft=perl expandtab:
package Lstu::DB::Ban::SQLite;
use Mojo::Base 'Lstu::DB::Ban';

has 'record' => 0;

sub new {
    my $c = shift;

    $c = $c->SUPER::new(@_);

    $c = $c->_slurp if ($c->ip);

    return $c;
}

sub is_banned {
    my $c              = shift;
    my $ban_min_strike = shift;

    return undef if $c->is_whitelisted;

    my $h = $c->app->sqlite->db->query('SELECT * FROM ban WHERE ip = ? AND until > ? AND strike >= ?', $c->ip, time, $ban_min_strike)->hashes;

    if ($h->size) {
        $c->until($h->first->{until});
        $c->strike($h->first->{strike});
        $c->record(1);

        return $c;
    } else {
        return undef;
    }
}

sub increment_ban_delay {
    my $c       = shift;
    my $penalty = shift;

    my $until = time + $penalty;

    my $h = {
        strike => 1
    };
    if ($c->record) {
        $c->app->sqlite->db->query('UPDATE ban SET until = ?, strike = strike + 1 WHERE ip = ?', $until, $c->ip)->hashes->first;
        $h = $c->app->sqlite->db->query('SELECT strike FROM ban WHERE ip = ?', $c->ip)->hashes->first;
    } else {
        $c->app->sqlite->db->query('INSERT INTO ban (ip, until, strike) VALUES (?, ?, 1)', $c->ip, $until);
        $c->record(1);
    }

    $c->strike($h->{strike});
    $c->until($until);

    return $c;
}

sub clear {
    my $c = shift;

    $c->app->sqlite->db->query('DELETE FROM ban WHERE until < ?', time);
}

sub delete_all {
    my $c = shift;

    $c->app->sqlite->db->query('DELETE FROM ban');
}

sub _slurp {
    my $c = shift;

    my $h = $c->app->sqlite->db->query('SELECT * FROM ban WHERE ip = ?', $c->ip)->hashes;
    if ($h->size) {
        $c->until($h->first->{until});
        $c->strike($h->first->{strike});
        $c->record(1);
    }

    return $c;
}

1;
