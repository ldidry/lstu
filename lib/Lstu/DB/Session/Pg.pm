# vim:set sw=4 ts=4 sts=4 ft=perl expandtab:
package Lstu::DB::Session::Pg;
use Mojo::Base 'Lstu::DB::Session';

sub new {
    my $c = shift;

    $c = $c->SUPER::new(@_);

    $c = $c->_slurp if ($c->token);

    return $c;
}

sub delete {
    my $c = shift;

    my $h = $c->app->dbi->db->query('DELETE FROM sessions WHERE token = ? RETURNING *', $c->token)->hashes;
    if ($h->size) {
        $c = Lstu::DB::Session->new(app => $c->app);
    }

    return $h->size;
}

1;
