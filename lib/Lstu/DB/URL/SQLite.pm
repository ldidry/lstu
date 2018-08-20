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

    $c->app->sqlite->db->query('UPDATE lstu SET counter = counter + 1 WHERE short = ?', $c->short);
    my $h = $c->app->sqlite->db->query('SELECT counter FROM lstu WHERE short = ?', $c->short)->hashes->first;
    $c->counter($h->{counter});

    return $c;
}

sub write {
    my $c     = shift;

    if ($c->record) {
        $c->app->sqlite->db->query('UPDATE lstu SET url = ?, counter = ?, timestamp = ?, created_by = ? WHERE short = ?', $c->url, $c->counter, $c->timestamp, $c->created_by, $c->short);
    } else {
        $c->app->sqlite->db->query('INSERT INTO lstu (short, url, counter, timestamp, created_by) VALUES (?, ?, ?, ?, ?)', $c->short, $c->url, $c->counter, $c->timestamp, $c->created_by);
        $c->record(1);
    }

    return $c;
}

sub delete {
    my $c = shift;

    $c->app->sqlite->db->query('DELETE FROM lstu WHERE short = ?', $c->short);
    my $h = $c->app->sqlite->db->query('SELECT * FROM lstu WHERE short = ?', $c->short)->hashes;
    if ($h->size) {
        # We found the URL, it hasn't been deleted
        return 0;
    } else {
        $c = Lstu::DB::URL->new(app => $c->app);
        # We didn't found the URL, it has been deleted
        return 1;
    }
}

sub exist {
    my $c     = shift;
    my $short = shift;

    return undef unless $short;

    return $c->app->sqlite->db->query('SELECT count(short) AS count FROM lstu WHERE short = ?', $short)->hashes->first->{count};
}

sub choose_empty {
    my $c = shift;

    my $h = $c->app->sqlite->db->query('SELECT * FROM lstu WHERE url IS NULL')->hashes->shuffle;

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

    return $c->app->sqlite->db->query('SELECT count(short) AS count FROM lstu WHERE url IS NULL')->hashes->first->{count};
}

sub paginate {
    my $c           = shift;
    my $page        = shift;
    my $page_offset = shift;

    return @{$c->app->sqlite->db->query('SELECT * FROM lstu WHERE url IS NOT NULL ORDER BY counter DESC LIMIT ? offset ?', $page_offset, $page * $page_offset)->hashes->to_array};
}

sub get_a_lot {
    my $c = shift;
    my $u = shift;

    if (scalar @{$u}) {
    my $p = join ",", (('?') x @{$u});
        return @{$c->app->sqlite->db->query('SELECT * FROM lstu WHERE short IN ('.$p.') ORDER BY counter DESC', @{$u})->hashes->to_array};
    } else {
        return ();
    }
}

sub total {
    my $c = shift;

    return $c->app->sqlite->db->query('SELECT count(short) AS count FROM lstu WHERE url IS NOT NULL')->hashes->first->{count};
}

sub delete_all {
    my $c = shift;

    $c->app->sqlite->db->query('DELETE FROM lstu');
}

sub search_url {
    my $c = shift;
    my $s = shift;

    $c->app->sqlite->db->select('lstu', undef, { url => {-like => '%'.$s.'%'}})->hashes;
}

sub search_creator {
    my $c = shift;
    my $s = shift;

    $c->app->sqlite->db->select('lstu', undef, { created_by => $s })->hashes;
}

sub _slurp {
    my $c = shift;

    my $h;
    if ($c->short) {
       $h = $c->app->sqlite->db->query('SELECT * FROM lstu WHERE short = ?', $c->short)->hashes;
   } else {
       $h = $c->app->sqlite->db->query('SELECT * FROM lstu WHERE url = ?', $c->url)->hashes;
   }
    if ($h->size) {
        $c->url($h->first->{url});
        $c->short($h->first->{short});
        $c->counter($h->first->{counter});
        $c->timestamp($h->first->{timestamp});
        $c->created_by($h->first->{created_by});
        $c->record(1);
    }

    return $c;
}

1;
