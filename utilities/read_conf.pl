#!/usr/bin/env perl

# read_conf.pl - Outputs lstu's config value for given keypath

use strict;
use warnings;

use FindBin;
use Cwd qw(realpath);
use Config::FromHash;

sub print_help {
    print <<END;
  Usage:
      $0 [-h] KEYPATH [DEFAULT] -- reads the lstu.conf file and outputs value at KEYPATH, or prints DEFAULT value

  where:
      -h                   prints this help message and exit
      KEYPATH              refers to the path in the hash, slash-separated (ie. mysqldb/host)
      DEFAULT              if keypath is undefined, return this value (ie. localhost)
END
    return;
}

if (defined $ARGV[0] and $ARGV[0] eq "-h") {
    print_help();
    exit 0;
}
 
if (not defined $ARGV[0]) {
    print_help();
    exit 1;
}

my $filename = realpath("$FindBin::Bin/../lstu.conf");
if (! -r $filename) {
    print STDERR "Error: unable to read config file \"$filename\"\n";
    exit 1;
}

my $config = Config::FromHash->new(filename => $filename);
my $value = $config->get($ARGV[0]);

if (defined $value) {
    print $value;
    exit 0;
}
if (not defined $value and defined $ARGV[1]) {
    print $ARGV[1];
    exit 0;
}
print STDERR "Error: keypath \"$ARGV[0]\" not found in config, and no default value provided.\n";
exit 1;