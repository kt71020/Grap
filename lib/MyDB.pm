package MyDB;

use strict;
use warnings;
use DBI;

our $dbh;

sub connect_to_db {
    my $host     = $ENV{'POSTGRESQL_HOST'} // '192.168.0.80';
    my $db       = $ENV{'POSTGRESQL_DB'}   // 'Bailey';
    my $user     = $ENV{'POSTGRESQL_USER'} // 'kt';
    my $password = $ENV{'POSTGRESQL_PASS'} // 'b1uxcdq';
    my $dsn      = "DBI:Pg:dbname=$db;host=$host;port=5432";

    $dbh = DBI->connect( $dsn, $user, $password, { RaiseError => 1 } )
      or die $DBI::errstr;

    return $dbh;
}

1;
