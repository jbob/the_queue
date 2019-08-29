#!/usr/bin/env perl

use strict;
use warnings;

use FindBin;
BEGIN { unshift @INC, "$FindBin::Bin/lib" }

use TheQueue::Model;

my $connection = TheQueue::Model->connect("mongodb://localhost/the_queue");
my $users = $connection->collection('user');

my $username = $ARGV[0];
die "Please specifiy the username to promote/demote\n" if not $username;

my $user  = $users->search({ username => $username })->single;
die "User not found in database\n" if not $user;

$user->admin(not $user->admin);
$user->save;

