# vim:set sw=4 ts=4 sts=4 ft=perl expandtab:
package Lstu::DB::URL::SQLite;
use Mojo::Base 'Lstu::DB::URL';
use Lstu::DB::SQLite;

has 'record';

sub new {
    my $c = shift;

    $c = $c->SUPER::new(@_);

    $c = $c->_slurp if ($c->short || $c->url);

    return $c;
}

sub delete_all {
    my $c = shift;

    # Rotten syntax, but prevents "Static Lstu::DB::SQLite->delete has been deprecated"
    Lstu::DB::SQLite::Lstu->delete_where('1 = 1');
}

sub delete {
    my $c = shift;

    my $result;
    if (Lstu::DB::SQLite->begin) {
        $result = $c->record->delete;
        $c->record(undef);
        Lstu::DB::SQLite->commit;
    }

    return $result;
}

sub increment_counter {
    my $c = shift;

    $c->record->update(counter => $c->counter + 1);
    $c->counter($c->counter + 1);

    return $c;
}

sub count_empty {
    my $c = shift;

    return Lstu::DB::SQLite::Lstu->count('WHERE url IS NULL');
}

sub exist {
    my $c     = shift;
    my $short = shift;

    return undef unless $short;

    return Lstu::DB::SQLite::Lstu->count('WHERE short = ?', $short);
}

sub write {
    my $c     = shift;

    if (Lstu::DB::SQLite->begin) {
        if (defined $c->record) {
            $c->record->update(
                short     => $c->short,
                url       => $c->url,
                counter   => $c->counter,
                timestamp => $c->timestamp,
            );
        } else {
            my $record = Lstu::DB::SQLite::Lstu->create(
                short     => $c->short,
                url       => $c->url,
                counter   => $c->counter,
                timestamp => $c->timestamp,
            );
            $c->record($record);
        }
        Lstu::DB::SQLite->commit;
    }

    return $c;
}

sub choose_empty {
    my $c = shift;

    my @urls = Lstu::DB::SQLite::Lstu->select('WHERE url IS NULL LIMIT 1');

    if (scalar(@urls)) {
        $c->short($urls[0]->short);
        $c->record($urls[0]);
        return $c;
    } else {
        return undef;
    }
}

sub total {
    my $c = shift;

    return Lstu::DB::SQLite::Lstu->count("WHERE url IS NOT NULL");
}

sub paginate {
    my $c           = shift;
    my $page        = shift;
    my $page_offset = shift;

    return Lstu::DB::SQLite::Lstu->select("WHERE url IS NOT NULL ORDER BY counter DESC LIMIT ? offset ?", $page_offset, $page * $page_offset);
}

sub get_a_lot {
    my $c = shift;
    my $u = shift;

    my $p = join ",", (('?') x @{$u});
    return Lstu::DB::SQLite::Lstu->select("WHERE short IN ($p) ORDER BY counter DESC", @{$u});
}

sub _slurp {
    my $c = shift;

    my @urls;
    if ($c->short) {
       @urls = Lstu::DB::SQLite::Lstu->select('WHERE short = ?', $c->short);
    } elsif ($c->url) {
       @urls = Lstu::DB::SQLite::Lstu->select('WHERE url = ?', $c->url);
    }
    if (scalar(@urls)) {
        $c->url($urls[0]->url);
        $c->short($urls[0]->short);
        $c->counter($urls[0]->counter);
        $c->timestamp($urls[0]->timestamp);
        $c->record($urls[0]);
    }

    return $c;
}

1;
