package TheQueue::Controller::TheQueue;
use Mojo::Base 'Mojolicious::Controller';

use Mango::BSON 'bson_oid';
use Array::Utils qw(:all);

sub login {
    my $self = shift;
    my $username = $self->param('username') // '';
    my $password = $self->param('password') // '';

    if ($username and $password)  {
        $self->session(username => $username);
        $self->session(password => $password);
        return $self->redirect_to($self->session('target') // '/');
    }
    if ($self->req->method eq 'POST') {
        $self->flash(msg => 'Please fill the complete form', type => 'danger');
        return $self->redirect_to('login');
    }
}

sub logout {
    my $self = shift;

    $self->session(logged_in => 0);
    $self->session(username => undef);
    $self->session(attendees => undef);
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
        }
        my $info = $self->gen_pwhash({
            password => $password1
        });
        $self->users->create({ username   => $username,
                               password   => $info->{hash},
                               salt       => $info->{salt},
                               cost       => $info->{cost}
                             })->save(sub {
                                   my ($users, $err, $user) = @_;
                                   $self->reply->exception($err) if $err;
                                   $self->render(success => 1);
                             });
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

    $self->users->search({ username => $username })->single(sub {
        my ($users, $err, $user) = @_;
        $self->reply->exception($err) if $err;
        $self->reply->not_found if not $user;
        if ($user) {
            my $old_hash = $self->gen_pwhash({
                password => $old_password,
                salt     => $user->salt,
                cost     => $user->cost
            })->{hash};
            if ($old_hash eq $user->password) {
                my $new_info = $self->gen_pwhash({
                    password => $new_password1,
                });
                $user->password($new_info->{hash});
                $user->salt($new_info->{salt});
                $user->cost($new_info->{cost});
                $user->save;
                return $self->redirect_to('logout');
            }
        }
        $self->flash(msg => 'Old password is incorrect', type => 'danger');
        return $self->redirect_to('changepw');
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
            $self->reply->not_found if not $user;
            my $submissions = $user->submissions;
            for my $submission (@$submissions) {
                $submission->remove;
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
        $self->reply->not_found if not $user;
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
    $self->users->search({ username => $username })->single(sub {
        my ($users, $err, $user) = @_;
        $self->reply->exception($err) if $err;
        $self->reply->not_found if not $user;
        $self->submissions->search({done => 0})->all(sub {
            my ($submissions, $err, $submission) = @_;
            $self->reply->exception($err) if $err;
            $self->reply->not_found if not $submission;
            my @relevant_submissions = grep {
                my $sub = $_;
                my @interested_users = map { $_->username } @{ $sub->interested };
                $sub->{interested_attendees} = [intersect(@$attendees, @interested_users)];
                grep {
                    my $att = $_;
                    $sub->user->username eq $att;
                } @$attendees;
            } @$submission;
            @relevant_submissions = sort {
                scalar @{$b->{interested_attendees}} <=> scalar @{$a->{interested_attendees}}
            } @relevant_submissions;
            for my $sub (@relevant_submissions) {
                my $found = grep { $_->id eq $user->id }  @{ $sub->interested };
                $sub->{match} = 1 if $found;
            }
            $self->users->all(sub {
                # Do this just to get a list of all usernames?
                my ($users, $err, $user) = @_;
                $self->reply->exception($err) if $err;
                $self->render(people => $user, attendees => $attendees,
                              submissions => \@relevant_submissions);
            });
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
        $self->submissions->search({_id => bson_oid($id)})->single(sub {
            my ($submissions, $err, $submission) = @_;
            $self->reply->exception($err) if $err;
            $self->reply->not_found if not $submission;
            $submission->link($link);
            $submission->comment($comment);
            $submission->save;
            $self->redirect_to('wtw');
        });
    } else {
        # Create new record
        my $newsubmission = $self->submissions->create({
            link      => $link,
            done      => 0,
            available => 0,
            comment   => $comment
        });

        $self->ua->get($link => sub {
            my ($ua, $tx) = @_;
            my $ogtitle = $tx->result->dom->at('meta[property="og:title"]');
            $ogtitle = $ogtitle->attr('content') if $ogtitle;

            my $ogdescription = $tx->result->dom->at('meta[property="og:description"]');
            $ogdescription = $ogdescription->attr('content') if $ogdescription;

            my $ogimage = $tx->result->dom->at('meta[property="og:image"]');
            $ogimage = $ogimage->attr('content') if $ogimage;

            if (not $ogimage) {
                $ogimage = $tx->result->dom->at('img');
                $ogimage = $ogimage->attr('src') if $ogimage;
                $ogimage = $tx->req->url->new($ogimage)->to_abs($tx->req->url) if $ogimage;
            }
            my $newogp = $self->ogps->create({
                title       => $ogtitle,
                description => $ogdescription,
                image       => $ogimage
            });
            $newsubmission->ogp($newogp);
            $self->users->search({ username => $username })->single(sub {
                my ($users, $err, $user) = @_;
                $self->reply->exception($err) if $err;
                $user->add_submissions($newsubmission);
                $newsubmission->push_interested($user);
                $user->save;
                $newsubmission->save;
                $self->redirect_to('wtw');
            });
        });
    }
    $self->render_later;
}

sub edit {
    my $self = shift;
    my $stash = $self->stash;
    my $id = $self->req->param('id') || $stash->{id};
    $self->submissions->search({_id => bson_oid($id)})->single(sub {
        my ($submissions, $err, $submission) = @_;
        $self->reply->exception($err) if $err;
        $self->reply->not_found if not $submission;
        $self->stash(id      => $id);
        $self->stash(link    => $submission->link);
        $self->stash(comment => $submission->comment);
        $self->render('the_queue/form');
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
        $self->reply->not_found if not $submission;
        if ($submission->done == 1) {
            $submission->done(0);
        } else {
            $submission->done(1);
        }
        $submission->save;
        $self->respond_to(
            json => { json => { message => 'success' } },
            html => sub {
                $self->redirect_to($self->req->headers->referrer);
            }
        );
    });
    $self->render_later;
}

sub available {
    my $self = shift;
    my $stash = $self->stash;
    my $id = $self->req->param('id') || $stash->{id};
    $self->submissions->search({_id => bson_oid($id)})->single(sub {
        my ($submissions, $err, $submission) = @_;
        $self->reply->exception($err) if $err;
        $self->reply->not_found if not $submission;
        if ($submission->available == 1) {
            $submission->available(0);
        } else {
            $submission->available(1);
        }
        $submission->save;
        $self->respond_to(
            json => { json => { message => 'success' } },
            html => sub {
                $self->redirect_to($self->req->headers->referrer);
            }
        );
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
        $self->reply->not_found if not $submission;
        $self->users->search({ username => $username })->single(sub {
            my ($users, $err, $user) = @_;
            $self->reply->exception($err) if $err;
            $self->reply->not_found if not $user;
            my $found = grep { $_->id eq $user->id }  @{ $submission->interested };
            $submission->remove_interested($user) if $found;
            $submission->push_interested($user) if not $found;
            $submission->save;
            $self->respond_to(
                json => { json => { message => 'success' } },
                html => sub {
                    $self->redirect_to($self->req->headers->referrer);
                }
            );
        });
    });
    $self->render_later;
}

sub delete {
    my $self = shift;
    my $stash = $self->stash;
    my $id = $self->req->param('id') || $stash->{id};

    $self->submissions->search({_id => bson_oid($id)})->single(sub {
        my ($submissions, $err, $submission) = @_;
        $self->reply->exception($err) if $err;
        $self->reply->not_found if not $submission;
        $submission->ogp->remove(sub {}) if $submission->ogp;
        $submissions->remove(sub {});
        $self->respond_to(
            json => { json => { Success => 1 } },
            html => sub {
                $self->redirect_to($self->req->headers->referrer);
            }
        );
    });
    $self->render_later;
}

sub search {
    my $self = shift;
    my $stash = $self->stash;
    my $search = $self->req->param('search') || $stash->{search} || '';
    my $username = $self->session('username');

    $self->users->search({ username => $username })->single(sub {
        my ($users, $err, $user) = @_;
        $self->reply->exception($err) if $err;
        $self->submissions->search({'$or' => [{comment => qr/$search/i}, {link => qr/$search/i}]})->all(sub {
            my ($submissions, $err, $hits1) = @_;
            $self->reply->exception($err) if $err;
            $self->ogps->search({ '$or' => [{title => qr/$search/i}, {description => qr/$search/i}] })->all(sub {
                my ($ogps, $err, $hits2) = @_;
                $self->reply->exception($err) if $err;
                push @$hits1, map { $_->submission } @$hits2;
                my %seen;
                my @result = grep { !$seen{$_->id}++ } @$hits1;
                for my $sub (@result) {
                    my $found = grep { $_->id eq $user->id }  @{ $sub->interested };
                    $sub->{match} = 1 if $found;
                }
                $self->render('the_queue/submissions_list', submissions => \@result);
            });
        });
    });
    $self->render_later;
}

1;
