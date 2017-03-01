# vim:set sw=4 ts=4 sts=4 ft=perl expandtab:
package Lstu::DB::URL::Pg;
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

    my $h = $c->app->pg->db->query('UPDATE lstu SET counter = counter + 1 WHERE short = ? RETURNING counter', $c->short)->hashes->first;
    $c->counter($h->{counter});

    return $c;
}

sub write {
    my $c     = shift;

    if ($c->record) {
        $c->app->mysql->db->query('UPDATE lstu SET url = ?, counter = ?, timestamp = ?, expires_at = ?, expires_after = ? WHERE short = ?', $c->url, $c->counter, $c->timestamp, $c->short, $c->expires_at, $c->expires_after);
    } else {
        $c->app->mysql->db->query('INSERT INTO lstu (short, url, counter, timestamp, expires_at, expires_after) VALUES (?, ?, ?, ?, ?, ?)', $c->short, $c->url, $c->counter, $c->timestamp, $c->expires_at, $c->expires_after);
        $c->record(1);
    }

    return $c;
}

sub delete {
    my $c = shift;

    my $h = $c->app->pg->db->query('DELETE FROM lstu WHERE short = ? RETURNING *', $c->short)->hashes;
    $c->app->debug($h->size);
    if ($h->size) {
        $c = Lstu::DB::URL->new(app => $c->app);
    }

    return $h->size;
}

sub exist {
    my $c     = shift;
    my $short = shift;

    return undef unless $short;

    return $c->app->pg->db->query('SELECT count(short) FROM lstu WHERE short = ?', $short)->hashes->first->{count};
}

sub choose_empty {
    my $c = shift;

    my $h = $c->app->pg->db->query('SELECT * FROM lstu WHERE url IS NULL LIMIT 1')->hashes;

    if ($h->size) {
        $c->short($h->first->{short});
        $c->record(1);
        return $c;
    } else {
        return undef;
    }
}

sub count_empty {
    my $c = shift;

    return $c->app->pg->db->query('SELECT count(short) FROM lstu WHERE url IS NULL')->hashes->first->{count};
}

sub paginate {
    my $c           = shift;
    my $page        = shift;
    my $page_offset = shift;

    return @{$c->app->pg->db->query('SELECT * FROM lstu WHERE url IS NOT NULL ORDER BY counter DESC LIMIT ? offset ?', $page_offset, $page * $page_offset)->hashes->to_array};
}

sub get_a_lot {
    my $c = shift;
    my $u = shift;

    my $p = join ",", (('?') x @{$u});
    return @{$c->app->pg->db->query('SELECT * FROM lstu WHERE short IN ('.$p.') ORDER BY counter DESC', @{$u})->hashes->to_array};
}

sub total {
    my $c = shift;

    return $c->app->pg->db->query('SELECT count(short) FROM lstu WHERE url IS NOT NULL')->hashes->first->{count};
}

sub delete_all {
    my $c = shift;

    $c->app->pg->db->query('DELETE FROM lstu');
}

sub _slurp {
    my $c = shift;

    my $h;
    if ($c->short) {
       $h = $c->app->pg->db->query('SELECT * FROM lstu WHERE short = ?', $c->short)->hashes;
   } else {
       $h = $c->app->pg->db->query('SELECT * FROM lstu WHERE url = ?', $c->url)->hashes;
   }
    if ($h->size) {
        $c->url($h->first->{url});
        $c->short($h->first->{short});
        $c->counter($h->first->{counter});
        $c->timestamp($h->first->{timestamp});
        $c->expires_at($h->first->{expires_at});
        $c->expires_after($h->first->{expires_after});
        $c->record(1);
    }

    return $c;
}

1;
