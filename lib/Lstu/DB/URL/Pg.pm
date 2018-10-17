# vim:set sw=4 ts=4 sts=4 ft=perl expandtab:
package Lstu::DB::URL::Pg;
use Mojo::Base 'Lstu::DB::URL';

sub new {
    my $c = shift;

    $c = $c->SUPER::new(@_);

    $c = $c->_slurp if ($c->short || $c->url);

    return $c;
}

sub increment_counter {
    my $c = shift;

    my $h = $c->app->dbi->db->query('UPDATE lstu SET counter = counter + 1 WHERE short = ? RETURNING counter', $c->short)->hashes->first;
    $c->counter($h->{counter});

    return $c;
}

sub delete {
    my $c = shift;

    my $h = $c->app->dbi->db->query('DELETE FROM lstu WHERE short = ? RETURNING *', $c->short)->hashes;
    # $h->size is the number of deleted rows
    # 0 means failure
    # 1 means success
    if ($h->size) {
        $c = Lstu::DB::URL->new(app => $c->app);
    }

    return $h->size;
}

1;
