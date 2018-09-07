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

    $c->app->dbi->db->query('DELETE FROM sessions WHERE token = ?', $c->token);
    my $h = $c->app->dbi->db->query('SELECT * FROM sessions WHERE token = ?', $c->token)->hashes;
    if ($h->size) {
        # We found the session, it hasn't been deleted
        return 0;
    } else {
        $c = Lstu::DB::Session->new(app => $c->app);
        # We didn't found the session, it has been deleted
        return 1;
    }
}

1;
