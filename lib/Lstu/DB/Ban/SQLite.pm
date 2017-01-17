# vim:set sw=4 ts=4 sts=4 ft=perl expandtab:
package Lstu::DB::Ban::SQLite;
use Mojo::Base 'Lstu::DB::Ban';
use Lstu::DB::SQLite;

has 'record';

sub new {
    my $c = shift;

    $c = $c->SUPER::new(@_);

    $c = $c->_slurp if ($c->ip);

    return $c;
}

sub is_banned {
    my $c              = shift;
    my $ban_min_strike = shift;

    my @banned = Lstu::DB::SQLite::Ban->select('WHERE ip = ? AND until > ? AND strike >= ?', $c->ip, time, $ban_min_strike);

    if (scalar @banned) {
        $c->record($banned[0]);

        $c->until($banned[0]->until);
        $c->strike($banned[0]->strike);

        return $c;
    } else {
        return undef;
    }
}

sub increment_ban_delay {
    my $c       = shift;
    my $penalty = shift;

    my $until = time + $penalty;

    if (defined $c->record) {
        $c->record->update(
            strike => $c->strike + 1,
            until  => $until
        );
    } else {
        my $record = Lstu::DB::SQLite::Ban->create(
            ip     => $c->ip,
            strike => 1,
            until  => $until
        );

        $c->record($record);
    }

    $c->strike($c->strike + 1);
    $c->until($until);

    return $c;
}

sub clear {
    my $c = shift;

    Lstu::DB::SQLite::Ban->delete_where('until < ?', time);
}

sub delete_all {
    my $c = shift;

    # Rotten syntax, but prevents "Static Lstu::DB::SQLite->delete has been deprecated"
    Lstu::DB::SQLite::Ban->delete_where('1 = 1');
}

sub _slurp {
    my $c = shift;

    my @banned = Lstu::DB::SQLite::Ban->select('WHERE ip = ?', $c->ip);
    if (scalar(@banned)) {
        $c->until($banned[0]->until);
        $c->strike($banned[0]->strike);
        $c->record($banned[0]);
    }

    return $c;
}

1;
