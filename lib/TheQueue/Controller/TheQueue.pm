package TheQueue::Controller::TheQueue;
use Mojo::Base 'Mojolicious::Controller';

use Digest::SHA qw(sha512_hex);
use URI::Escape;
use Mango::BSON 'bson_oid';
use Encode qw(decode encode);

sub login {
    my $self = shift;
    my $stash = $self->stash;
    my $config = $stash->{config};

    my $username = $self->param('username') // '';
    my $password = $self->param('password') // '';
    if ($username and $password)  {
        $self->session(username => $username);
        $self->session(password => sha512_hex sha512_hex $password);
        return $self->redirect_to($self->session('target') // '/');
    } else {
        if ($self->req->method eq 'POST') {
            $self->flash(msg => 'Please fill the complete form', type => 'danger');
            return $self->redirect_to('login');
        }
    }
}

sub logout {
    my $self = shift;
    $self->session(logged_in => 0);
    $self->session(username => '');
    return $self->redirect_to('index');
}

sub register {
    my $self = shift;
    my $username  = $self->param('username')  // '';
    my $password1 = $self->param('password1') // '';
    my $password2 = $self->param('password2') // '';

    if ($self->req->method eq 'GET') {
        return $self->render;
    }

    if (not $username or not $password1 or not $password2) {
        $self->flash(msg => 'Please fill the complete form', type => 'danger');
        return $self->redirect_to('register');
    }
    if ($password1 ne $password2) {
        $self->flash(msg => 'Passwords do not match', type => 'danger');
        return $self->redirect_to('register');
    }

    $self->users->search({ username => $username })->single(sub {
        my ($users, $err, $user) = @_;
        $self->reply->exception($err) if $err;
        if ($user) {
            $self->flash(msg => 'Username already taken', type => 'danger');
            return $self->redirect_to('register');
        } else {
            my $password = sha512_hex sha512_hex $password1;
            $self->users->create({ username   => $username,
                                   password   => $password
                                 })->save(sub {
                                       my ($users, $err, $user) = @_;
                                       $self->reply->exception($err) if $err;
                                       $self->render(success => 1);
                                   });
        }
    });
    $self->render_later;
}

sub changepw {
    my $self = shift;
    my $old_password  = $self->param('old_password')  // '';
    my $new_password1 = $self->param('new_password1') // '';
    my $new_password2 = $self->param('new_password2') // '';

    if ($self->req->method eq 'GET') {
        return $self->render;
    }
    if (not $old_password or not $new_password1 or not $new_password2) {
        $self->flash(msg => 'Please fill the complete form', type => 'danger');
        return $self->redirect_to('changepw');
    }
    if ($new_password1 ne $new_password2) {
        $self->flash(msg => 'Passwords do not match', type => 'danger');
        return $self->redirect_to('changepw');
    }

    my $username = $self->session('username');
    $old_password = sha512_hex sha512_hex $old_password;

    $self->users->search({ username => $username, password => $old_password })->single(sub {
        my ($users, $err, $user) = @_;
        $self->reply->exception($err) if $err;
        if ($user) {
            $user->password(sha512_hex sha512_hex $new_password1);
            $user->save;
            return $self->redirect_to('logout');
        } else {
            $self->flash(msg => 'Old password is incorrect', type => 'danger');
            return $self->redirect_to('changepw');
        }

    });
    $self->render_later;
}

sub deleteacc {
    my $self = shift;

    if ($self->req->method eq 'GET') {
        return $self->render;
    }

    my $confirmation = $self->param('confirmation') // '';
    if ($confirmation eq 'YES') {
        my $username = $self->session('username');
        $self->users->search({ username => $username })->single(sub {
            my ($users, $err, $user) = @_;
            $self->reply->exception($err) if $err;
            my $logins = $user->logins;
            for my $login (@$logins) {
                $login->remove;
            }
            $user->remove;
            $self->redirect_to('logout');
        });
    } else {
        $self->redirect_to('account');
    }

    $self->render_later;
}

sub submissions_list {
    my $self = shift;
    my $username = $self->session('username');
    my $query = $self->req->param('q') // '';
    $self->users->search({ username => $username })->single(sub {
        my ($users, $err, $user) = @_;
        $self->reply->exception($err) if $err;
        my $search = { done => 0 };
        $search = { } if $query eq 'all';
        $self->submissions->search($search)->all(sub {
            my ($submissions, $err, $submission) = @_;
            $self->reply->exception($err) if $err;
            for my $sub (@$submission) {
                my $found = grep { $_->id eq $user->id }  @{ $sub->interested };
                $sub->{match} = 1 if $found;
            }
            $self->render(submissions => $submission);
        });
    });
    $self->render_later;
}

sub wtw {
    # What to watch list
    # Do not show submissions of people not in attendance
    # Sort by "interest" (percent of interested people in attendence?) or age?
    my $self = shift;
    my $username = $self->session('username');
    my $attendees = $self->req->every_param('username');
    # Store attendees info to session, so we can recall it later
    $self->session(attendees => $attendees) if @$attendees;
    $attendees = $self->session('attendees');
    $self->session(attendees => $attendees) if $attendees;
    $self->submissions->search({done => 0})->all(sub {
        my ($submissions, $err, $submission) = @_;
        my @relevant_submissions = grep {
            my $sub = $_;
            grep {
                my $att = $_;
                $sub->user->username eq $att;
            } @$attendees;
        } @$submission;
        $self->users->all(sub { 
            # Do this just to get a list of all usernames?
            my ($users, $err, $user) = @_;
            $self->reply->exception($err) if $err;
            $self->render(people => $user, attendees => $attendees, submissions => \@relevant_submissions);
        });
    });
    $self->render_later;
}

sub upsert {
    my $self = shift;
    my $stash = $self->stash;
    my $username = $self->session('username');
    my $id       = $self->req->param('id') || $stash->{id};
    my $link     = $self->req->param('link') // '';
    my $comment  = $self->req->param('comment') // '';

    if ($id) {
        # Update existing record
        $self->users->search({ username => $username })->single(sub {
            my ($users, $err, $user) = @_;
            $self->reply->exception($err) if $err;
            $self->submissions->search({'user.$id' => bson_oid($user->id), _id => bson_oid($id)})->single(sub {
                my ($submissions, $err, $submission) = @_;
                $self->reply->exception($err) if $err;
                $submission->link($link);
                $submission->comment($comment);
                $submission->save;
                $self->redirect_to($self->req->headers->referrer);
            });
        });
    } else {
        # Create new record
        my $newsubmission = $self->submissions->create({ link    => $link,
                                             done    => 0,
                                                         comment => $comment });

        $self->users->search({ username => $username })->single(sub {
            my ($users, $err, $user) = @_;
            $self->reply->exception($err) if $err;
            $user->add_submissions($newsubmission);
        $newsubmission->push_interested($user);
        $user->save;
        $newsubmission->save;
            $self->redirect_to($self->req->headers->referrer);
        });
    }
    $self->render_later;
}

sub edit {
    my $self = shift;
    my $stash = $self->stash;
    my $username = $self->session('username');
    my $id = $self->req->param('id') || $stash->{id};
    $self->users->search({ username => $username })->single(sub {
        my ($users, $err, $user) = @_;
        $self->reply->exception($err) if $err;
        $self->submissions->search({'user.$id' => bson_oid($user->id), _id => bson_oid($id)})->single(sub {
            my ($submissions, $err, $submission) = @_;
            $self->reply->exception($err) if $err;
            $self->stash(id      => $id);
            $self->stash(link    => $submission->link);
            $self->stash(comment => $submission->comment);
            $self->render('the_queue/form');
        });
    });
    $self->render_later;
}

sub done {
    my $self = shift;
    my $stash = $self->stash;
    my $id = $self->req->param('id') || $stash->{id};
    $self->submissions->search({_id => bson_oid($id)})->single(sub {
        my ($submissions, $err, $submission) = @_;
        $self->reply->exception($err) if $err;
    if ($submission->done == 1) {
            $submission->done(0);
        } else {
            $submission->done(1);
    }
    $submission->save;
    $self->redirect_to($self->req->headers->referrer);
    });
    $self->render_later;
}

sub thumbs {
    my $self = shift;
    my $stash = $self->stash;
    my $id = $self->req->param('id') || $stash->{id};
    my $username = $self->session('username');

    $self->submissions->search({_id => bson_oid($id)})->single(sub {
        my ($submissions, $err, $submission) = @_;
        $self->reply->exception($err) if $err;
        $self->users->search({ username => $username })->single(sub {
            my ($users, $err, $user) = @_;
            $self->reply->exception($err) if $err;

        my $found = grep { $_->id eq $user->id }  @{ $submission->interested };
        $submission->remove_interested($user) if $found;
        $submission->push_interested($user) if not $found;
        });
        $submission->save;
        $self->redirect_to($self->req->headers->referrer);
    });
    $self->render_later;
}

sub delete {
    my $self = shift;
    my $stash = $self->stash;
    my $id = $self->req->param('id') || $stash->{id};
    my $username = $self->session('username');

    $self->users->search({ username => $username })->single(sub {
        my ($users, $err, $user) = @_;
        $self->reply->exception($err) if $err;
        $self->submissions->search({'user.$id' => bson_oid($user->id), _id => bson_oid($id)})->single(sub {
            my ($submissions, $err, $submission) = @_;
            $self->reply->exception($err) if $err;
            $submissions->remove;
            $self->redirect_to($self->req->headers->referrer);
        });
    });

    $self->render_later;
}

1;
