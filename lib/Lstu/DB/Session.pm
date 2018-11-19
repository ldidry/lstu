# vim:set sw=4 ts=4 sts=4 ft=perl expandtab:
package Lstu::DB::Session;
use Mojo::Base -base;

has 'token';
has 'until';
has 'record' => 0;
has 'app';

=head1 NAME

Lstu::DB::Session - Abstraction layer for Lstu session system

=head1 Contributing

When creating a new database accessor, make sure that it provides the following subroutines.
After that, modify this file and modify the C<new> subroutine to allow to use your accessor.

Have a look at Lstu::DB::Session::SQLite's code: it's simple and may be more understandable that this doc.

=head1 Attributes

=over 1

=item B<token>  : random string

=item B<until>  : unix timestamp

=item B<app>    : a mojolicious object

=back

=head1 Sub routines

=head2 new

=over 1

=item B<Usage>     : C<$c = Lstu::DB::Session-E<gt>new(app =E<gt> $self);>

=item B<Arguments> : any of the attribute above

=item B<Purpose>   : construct a new Lstu::DB::Session object. If the C<token> attribute is provided, it have to load the informations from the database

=item B<Returns>   : the Lstu::DB::Session object

=item B<Info>      : the app argument is used by Lstu::DB::Session to choose which db accessor will be used, you don't need to use it in new(), but you can use it to access helpers or configuration settings in the other subroutines

=back

=cut

sub new {
    my $c = shift;

    $c = $c->SUPER::new(@_);

    if (ref($c) eq 'Lstu::DB::Session') {
        my $dbtype = $c->app->config('dbtype');
        if ($dbtype eq 'sqlite') {
            require Lstu::DB::Session::SQLite;
            $c = Lstu::DB::Session::SQLite->new(@_);
        } elsif ($dbtype eq 'postgresql') {
            require Lstu::DB::Session::Pg;
            $c = Lstu::DB::Session::Pg->new(@_);
        } elsif ($dbtype eq 'mysql') {
            require Lstu::DB::Session::MySQL;
            $c = Lstu::DB::Session::MySQL->new(@_);
        }
    }

    return $c;
}

sub is_valid {
    my $c = shift;

    return 0 unless defined $c->until;
    return ($c->until > time);
}

sub to_hash {
    my $c = shift;

    return {
        token => $c->token,
        until => $c->until
    }
}

=head2 remove

=over 1

=item B<Usage>     : C<$c-E<gt>remove>

=item B<Arguments> : none

=item B<Purpose>   : remove the session record from the database

=item B<Returns>   : the Lstu::DB::Session object

=back

=cut

sub remove {
    my $c = shift;

    $c->app->dbi->db->query('DELETE FROM sessions WHERE token = ?', $c->token);
    my $h = $c->app->dbi->db->query('SELECT * FROM sessions WHERE token = ?', $c->token)->hashes;
    if ($h->size) {
        # We found the session, it hasn't been removed
        return 0;
    } else {
        $c = Lstu::DB::Session->new(app => $c->app);
        # We didn't found the session, it has been removed
        return 1;
    }
}

=head2 write

=over 1

=item B<Usage>     : C<$c-E<gt>write>

=item B<Arguments> : none

=item B<Purpose>   : create or update the object in the database

=item B<Returns>   : the Lstu::DB::Session object

=back

=cut

sub write {
    my $c     = shift;

    if ($c->record) {
        $c->app->dbi->db->query('UPDATE sessions SET until = ? WHERE token = ?', $c->until, $c->token);
    } else {
        $c->app->dbi->db->query('INSERT INTO sessions (token, until) VALUES (?, ?)', $c->token, $c->until);
        $c->record(1);
    }

    return $c;
}

=head2 clear

=over 1

=item B<Usage>     : C<$c-E<gt>clear>

=item B<Arguments> : none

=item B<Purpose>   : delete all session records from database where until < time

eg: C<WHERE until E<lt> ?, time>

=item B<Returns>   : nothing is expected

=back

=cut

sub clear {
    my $c = shift;

    $c->app->dbi->db->query('DELETE FROM sessions WHERE until < ?', time);
}

=head2 delete_all

=over 1

=item B<Usage>     : C<$c-E<gt>delete_all>

=item B<Arguments> : none

=item B<Purpose>   : delete all session records from database unconditionnally

=item B<Returns>   : nothing is expected

=back

=cut

sub delete_all {
    my $c = shift;

    $c->app->dbi->db->query('DELETE FROM sessions');
}

=head2 _slurp

=over 1

=item B<Usage>     : C<$c-E<gt>_slurp>

=item B<Arguments> : none

=item B<Purpose>   : put a database record's columns into the Lstu::DB::Session object's attributes

=item B<Returns>   : the Lstu::DB::Session object

=back

=cut

sub _slurp {
    my $c = shift;

    my $h = $c->app->dbi->db->query('SELECT * FROM sessions WHERE token = ?', $c->token)->hashes;
    if ($h->size) {
        $c->token($h->first->{token});
        $c->until($h->first->{until});
        $c->record(1);
    }

    return $c;
}

1;
