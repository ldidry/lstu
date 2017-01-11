# vim:set sw=4 ts=4 sts=4 ft=perl expandtab:
package Lstu::DB::SQLite;
use Mojolicious;
use FindBin qw($Bin);
use File::Spec::Functions;

BEGIN {
    my $m = Mojolicious->new;
    our $config = $m->plugin('Config' =>
        {
            file    => catfile($Bin, '..' , '..', '..', ,'lstu.conf'),
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
               short     TEXT PRIMARY KEY,
               url       TEXT,
               counter   INTEGER,
               timestamp INTEGER)'
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
