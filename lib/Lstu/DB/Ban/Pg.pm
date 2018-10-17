# vim:set sw=4 ts=4 sts=4 ft=perl expandtab:
package Lstu::DB::Ban::Pg;
use Mojo::Base 'Lstu::DB::Ban';

sub new {
    my $c = shift;

    $c = $c->SUPER::new(@_);

    $c = $c->_slurp if ($c->ip);

    return $c;
}

sub increment_ban_delay {
    my $c       = shift;
    my $penalty = shift;

    my $until = time + $penalty;

    my $h = {
        strike => 1
    };
    if ($c->record) {
        $h = $c->app->dbi->db->query('UPDATE ban SET until = ?, strike = strike + 1 WHERE ip = ? RETURNING strike', $until, $c->ip)->hashes->first;
    } else {
        $c->app->dbi->db->query('INSERT INTO ban (ip, until, strike) VALUES (?, ?, 1)', $c->ip, $until);
        $c->record(1);
    }

    $c->strike($h->{strike});
    $c->until($until);

    return $c;
}

sub ban_ten_years {
    my $c = shift;

    my $until = time + 315360000;

    my $h = {
        strike => time
    };
    if ($c->record) {
        $h = $c->app->dbi->db->query('UPDATE ban SET until = ?, strike = ? WHERE ip = ? RETURNING strike', $until, time, $c->ip)->hashes->first;
    } else {
        $c->app->dbi->db->query('INSERT INTO ban (ip, until, strike) VALUES (?, ?, ?)', $c->ip, $until, time);
        $c->record(1);
    }

    $c->strike($h->{strike});
    $c->until($until);

    return $c;
}

1;
