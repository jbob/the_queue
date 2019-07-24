#!/usr/bin/env perl

use strict;
use warnings;

use Digest::SHA qw(sha512_hex);
use Crypt::Eksblowfish::Bcrypt qw(bcrypt_hash en_base64);
use Data::Entropy::Algorithms qw(rand_bits rand_int);

use FindBin;
BEGIN { unshift @INC, "$FindBin::Bin/lib" }

use TheQueue::Model;

sub gen_pwhash {
    my $args          = shift;
    my $password      = $args->{password};
    my $salt          = $args->{salt} // en_base64(rand_bits(12 * 8));
    my $cost          = $args->{cost} // rand_int(5) + 1;
    my $password_hash = en_base64(bcrypt_hash({
                key_nul => 1,
                cost    => $cost,
                salt    => $salt
    }, $password));
    return {
        hash => $password_hash,
        salt => $salt,
        cost => $cost
    };
}

my $connection = TheQueue::Model->connect("mongodb://localhost/the_queue");
my $users = $connection->collection('user');

my $idiot = $ARGV[0];
die "Please specifiy the username of the idiot\n" if not $idiot;

my $user  = $users->search({ username => $idiot })->single;
die "Idiot not found in database\n" if not $user;

my $salt  = $user->salt;
my $cost  = $user->cost;
my $newpw = 'i_am_dumb';

my $p = gen_pwhash({ password => $newpw, salt => $salt, cost => $cost});

$user->password($p->{hash});
$user->save;

