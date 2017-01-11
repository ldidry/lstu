# vim:set sw=4 ts=4 sts=4 ft=perl expandtab:
package Lstu::DB::Session::SQLite;
use Mojo::Base 'Lstu::DB::Session';
use Lstu::DB::SQLite;

has 'record';

sub new {
    my $c = shift;

    $c = $c->SUPER::new(@_);

    $c = $c->_slurp if ($c->token);

    return $c;
}

sub clear {
    my $c = shift;

    Lstu::DB::SQLite::Sessions->delete_where('until < ?', time);
}

sub delete_all {
    my $c = shift;

    # Rotten syntax, but prevents "Static Lstu::DB::SQLite->delete has been deprecated"
    Lstu::DB::SQLite::Sessions->delete_where('1 = 1');
}

sub delete {
    my $c = shift;

    if (Lstu::DB::SQLite->begin) {
        $c->record->delete;
        $c->record(undef);
        Lstu::DB::SQLite->commit;
    }

    return $c;
}

sub write {
    my $c     = shift;

    if (Lstu::DB::SQLite->begin) {
        if (defined $c->record) {
            $c->record->update(
                token => $c->token,
                until => $c->until,
            );
        } else {
            my $record = Lstu::DB::SQLite::Sessions->create(
                token => $c->token,
                until => $c->until,
            );
            $c->record($record);
        }
        Lstu::DB::SQLite->commit;
    }

    return $c;
}

sub _slurp {
    my $c = shift;

    my @sessions = Lstu::DB::SQLite::Sessions->select('WHERE token = ?', $c->token);
    if (scalar(@sessions)) {
        $c->token($sessions[0]->token);
        $c->until($sessions[0]->until);
        $c->record($sessions[0]);
    }

    return $c;
}

1;
