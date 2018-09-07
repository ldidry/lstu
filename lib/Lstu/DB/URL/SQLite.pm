# vim:set sw=4 ts=4 sts=4 ft=perl expandtab:
package Lstu::DB::URL::SQLite;
use Mojo::Base 'Lstu::DB::URL';

has 'record' => 0;

sub new {
    my $c = shift;

    $c = $c->SUPER::new(@_);

    $c = $c->_slurp if ($c->short || $c->url);

    return $c;
}

sub increment_counter {
    my $c = shift;

    $c->app->dbi->db->query('UPDATE lstu SET counter = counter + 1 WHERE short = ?', $c->short);
    my $h = $c->app->dbi->db->query('SELECT counter FROM lstu WHERE short = ?', $c->short)->hashes->first;
    $c->counter($h->{counter});

    return $c;
}

sub delete {
    my $c = shift;

    $c->app->dbi->db->query('DELETE FROM lstu WHERE short = ?', $c->short);
    my $h = $c->app->dbi->db->query('SELECT * FROM lstu WHERE short = ?', $c->short)->hashes;
    if ($h->size) {
        # We found the URL, it hasn't been deleted
        return 0;
    } else {
        $c = Lstu::DB::URL->new(app => $c->app);
        # We didn't found the URL, it has been deleted
        return 1;
    }
}

1;
