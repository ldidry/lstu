# vim:set sw=4 ts=4 sts=4 ft=perl expandtab:
package Lstu::DB::Session::MySQL;
use Mojo::Base 'Lstu::DB::Session';

has 'record' => 0;

sub new {
    my $c = shift;

    $c = $c->SUPER::new(@_);

    $c = $c->_slurp if ($c->token);

    return $c;
}

sub delete {
    my $c = shift;

    $c->app->mysql->db->query('DELETE FROM sessions WHERE token = ?', $c->token);
    my $h = $c->app->mysql->db->query('SELECT * FROM sessions WHERE token = ?', $c->token)->hashes;
    if ($h->size) {
        $c = Lstu::DB::Session->new(app => $c->app);
    }

    return $h->size;
}

sub write {
    my $c     = shift;

    if ($c->record) {
        $c->app->mysql->db->query('UPDATE sessions SET until = ? WHERE token = ?', $c->until, $c->token);
    } else {
        $c->app->mysql->db->query('INSERT INTO sessions (token, until) VALUES (?, ?)', $c->token, $c->until);
        $c->record(1);
    }

    return $c;
}

sub clear {
    my $c = shift;

    $c->app->mysql->db->query('DELETE FROM sessions WHERE until < ?', time);
}

sub delete_all {
    my $c = shift;

    $c->app->mysql->db->query('DELETE FROM sessions');
}

sub _slurp {
    my $c = shift;

    my $h = $c->app->mysql->db->query('SELECT * FROM sessions WHERE token = ?', $c->token)->hashes;
    if ($h->size) {
        $c->token($h->first->{token});
        $c->until($h->first->{until});
        $c->record(1);
    }

    return $c;
}

1;
