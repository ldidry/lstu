# vim:set sw=4 ts=4 sts=4 ft=perl expandtab:
package Lstu::DB::SQLite;
use Mojolicious;
use Mojo::File;
use FindBin qw($Bin);

BEGIN {
    my $m = Mojolicious->new;
    my $cfile = Mojo::File->new($Bin, '..' , 'lstu.conf');
    if (defined $ENV{MOJO_CONFIG}) {
        $cfile = Mojo::File->new($ENV{MOJO_CONFIG});
        unless (-e $cfile->to_abs) {
            $cfile = Mojo::File->new($Bin, '..', $ENV{MOJO_CONFIG});
        }
    }
    our $config = $m->plugin('Config' =>
        {
            file    => $cfile->to_abs->to_string,
            default => {
                db_path => 'lstu.db'
            }
        }
    );
}

# Create database
use ORLite {
      file    => $config->{db_path},
      unicode => 1,
      create  => sub {
          my $dbh = shift;
          $dbh->do(
              'CREATE TABLE IF NOT EXISTS lstu (
               short         TEXT PRIMARY KEY,
               url           TEXT,
               counter       INTEGER,
               timestamp     INTEGER,
               expires_at    INTEGER,
               expires_after INTEGER)'
          );
          $dbh->do(
              'CREATE TABLE IF NOT EXISTS sessions (
              token TEXT PRIMARY KEY,
              until INTEGER)'
          );
          $dbh->do(
              'CREATE TABLE IF NOT EXISTS ban (
              ip TEXT PRIMARY KEY,
              until INTEGER,
              strike INTEGER)'
          );
          return 1;
    }
};

1;
