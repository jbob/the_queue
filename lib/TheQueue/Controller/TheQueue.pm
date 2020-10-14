package TheQueue::Controller::TheQueue;
use Mojo::Base 'Mojolicious::Controller';

use Mango::BSON 'bson_oid';
use Array::Utils qw(:all);
use DateTime;

sub submissions_list {
    my $self     = shift;
    my $username = $self->session('username');
    my $query    = $self->req->param('q') // '';

    $self->users->search({username => $username})->single(
        sub {
            my ($users, $err, $user) = @_;
            return $self->reply->exception($err) if $err;
            return $self->reply->not_found if not $user;
            my $search = {done => 0};
            $search = {}          if $query eq 'all';
            $search = {done => 1} if $query eq 'watched';
            $self->submissions->search($search)->all(
                sub {
                    my ($submissions, $err, $submission) = @_;
                    return $self->reply->exception($err) if $err;
                    for my $sub (@$submission) {
                        my $found =
                            grep { $_->id eq $user->id } @{$sub->interested};
                        $sub->{match} = 1 if $found;
                    }
                    if ($self->req->url->path =~ m|^/api/|) {
                        $self->render(json => {
                                submissions => [map {
                                        my $sub = $_;
                                        {
                                            id    => $sub->id,
                                            title => $sub->ogp->title,
                                            image => $sub->ogp->image,
                                            description => $sub->ogp->description,
                                            comment   => $sub->comment,
                                            link      => $sub->link,
                                            available => $sub->available,
                                            done      => $sub->done,
                                            match     => $sub->{match},
                                            submitter => {
                                                username => $sub->user->username,
                                                id => $sub->user->id
                                            },
                                            interested => [map {
                                                    {
                                                        username => $_->username,
                                                        id => $_->id
                                                    }
                                            } @{$sub->interested}]
                                        };
                                } @$submission],
                        });
                    } else {
                        $self->render(submissions => $submission);
                    }
                }
            );
        }
    );
    $self->render_later;
}

sub wtw {

    # What to watch list
    # Do not show submissions of people not in attendance
    # Sort by "interest" (percent of interested people in attendence?) or age?
    my $self      = shift;
    my $username  = $self->session('username');
    my $attendees = $self->req->every_param('username');
    my $available = $self->req->param('available');

    # Store attendees info to session, so we can recall it later
    $self->session(attendees => $attendees) if @$attendees;
    $attendees = $self->session('attendees');
    $self->session(attendees => $attendees) if $attendees;
    $self->users->search({username => $username})->single(
        sub {
            my ($users, $err, $user) = @_;
            return $self->reply->exception($err) if $err;
            return $self->reply->not_found if not $user;
            my $search = {done => 0};
            $search->{available} = 1 if $available;
            $self->submissions->search($search)->all(
                sub {
                    my ($submissions, $err, $submission) = @_;
                    return $self->reply->exception($err) if $err;
                    return $self->reply->not_found if not $submission;
                    my @relevant_submissions = grep {
                        my $sub = $_;
                        my @interested_users =
                            map { $_->username } @{$sub->interested};
                        $sub->{interested_attendees} =
                            [intersect(@$attendees, @interested_users)];
                        grep {
                            my $att = $_;
                            $sub->user->username eq $att;
                        } @$attendees;
                    } @$submission;
                    @relevant_submissions = sort {
                        scalar @{$b->{interested_attendees}} <=>
                            scalar @{$a->{interested_attendees}}
                    } @relevant_submissions;
                    for my $sub (@relevant_submissions) {
                        my $found =
                            grep { $_->id eq $user->id } @{$sub->interested};
                        $sub->{match} = 1 if $found;
                    }
                    $self->users->all(
                        sub {
                            # Do this just to get a list of all usernames?
                            my ($users, $err, $user) = @_;
                            return $self->reply->exception($err) if $err;
                            if ($self->req->url->path =~ m|^/api/|) {
                                $self->render(json => {
                                        attendees   => $attendees,
                                        submissions => [map {
                                                my $sub = $_;
                                                {
                                                    id    => $sub->id,
                                                    title => $sub->ogp->title,
                                                    image => $sub->ogp->image,
                                                    description => $sub->ogp->description,
                                                    comment => $sub->comment,
                                                    link    => $sub->link,
                                                    available => $sub->available,
                                                    done      => $sub->done,
                                                    match     => $sub->{match},
                                                    submitter => {
                                                        username => $sub->user->username,
                                                        id => $sub->user->id
                                                    },
                                                    interested => [map {
                                                            {
                                                                username => $_->username,
                                                                id => $_->id
                                                            }
                                                    } @{$sub->interested}]
                                                };
                                        } @relevant_submissions],
                                        people => [map { 
                                            {
                                                username => $_->username,
                                                id       => $_->id
                                            }
                                        } @{$user}]
                                    });
                            } else {
                                $self->render(
                                    people      => $user,
                                    attendees   => $attendees,
                                    submissions => \@relevant_submissions
                                );
                            }
                        }
                    );
                }
            );
        }
    );
    $self->render_later;
}

sub upsert {
    my $self     = shift;
    my $stash    = $self->stash;
    my $username = $self->session('username');
    my $id       = $self->req->param('id') || $stash->{id};
    my $link     = $self->req->param('link') // '';
    my $comment  = $self->req->param('comment') // '';

    if ($id) {

        # Update existing record
        $self->submissions->search({_id => bson_oid($id)})->single(
            sub {
                my ($submissions, $err, $submission) = @_;
                return $self->reply->exception($err) if $err;
                return $self->reply->not_found if not $submission;
                $submission->link($link);
                $submission->comment($comment);
                $submission->save;
                $self->redirect_to('wtw');
            }
        );
    }
    else {

        # Create new record
        my $newsubmission = $self->submissions->create(
            {
                link      => $link,
                done      => 0,
                available => 0,
                comment   => $comment
            }
        );

        $self->ua->get(
            $link => sub {
                my ($ua, $tx) = @_;
                my $ogtitle = $tx->result->dom->at('meta[property="og:title"]');
                $ogtitle = $ogtitle->attr('content') if $ogtitle;

                my $ogdescription =
                    $tx->result->dom->at('meta[property="og:description"]');
                $ogdescription = $ogdescription->attr('content')
                    if $ogdescription;

                my $ogimage = $tx->result->dom->at('meta[property="og:image"]');
                $ogimage = $ogimage->attr('content') if $ogimage;

                if (not $ogimage) {
                    $ogimage = $tx->result->dom->at('img');
                    $ogimage = $ogimage->attr('src') if $ogimage;
                    $ogimage =
                        $tx->req->url->new($ogimage)->to_abs($tx->req->url)
                        if $ogimage;
                }
                my $newogp = $self->ogps->create(
                    {
                        title       => $ogtitle,
                        description => $ogdescription,
                        image       => $ogimage
                    }
                );
                $newsubmission->ogp($newogp);
                $self->users->search({username => $username})->single(
                    sub {
                        my ($users, $err, $user) = @_;
                        return $self->reply->exception($err) if $err;
                        $user->add_submissions($newsubmission);
                        $newsubmission->push_interested($user);
                        my $feed = $self->feeds->create(
                            {
                                msg => sprintf(
                                    "%s created %s",
                                    $user->username,
                                    (
                                        $newsubmission->ogp->title
                                            || $newsubmission->link
                                    )
                                ),
                                ts => DateTime->now
                            }
                        );
                        $newsubmission->add_feeds($feed);
                        $user->add_feeds($feed);
                        $user->save;
                        $newsubmission->save;
                        $self->redirect_to('wtw');
                    }
                );
            }
        );
    }
    $self->render_later;
}

sub edit {
    my $self  = shift;
    my $stash = $self->stash;
    my $id    = $self->req->param('id') || $stash->{id};
    $self->submissions->search({_id => bson_oid($id)})->single(
        sub {
            my ($submissions, $err, $submission) = @_;
            return $self->reply->exception($err) if $err;
            return $self->reply->not_found if not $submission;
            $self->stash(id      => $id);
            $self->stash(link    => $submission->link);
            $self->stash(comment => $submission->comment);
            $self->render('the_queue/form');
        }
    );
    $self->render_later;
}

sub done {
    my $self  = shift;
    my $stash = $self->stash;
    my $id    = $self->req->param('id') || $stash->{id};
    $self->submissions->search({_id => bson_oid($id)})->single(
        sub {
            my ($submissions, $err, $submission) = @_;
            return $self->reply->exception($err) if $err;
            return $self->reply->not_found if not $submission;
            if ($submission->done == 1) {
                $submission->done(0);
                my $feed = $self->feeds->create(
                    {
                        msg => sprintf("%s marked as not watched",
                            ($submission->ogp->title || $submission->link)),
                        ts => DateTime->now
                    }
                );
                $submission->add_feeds($feed);
            }
            else {
                $submission->done(1);
                my $feed = $self->feeds->create(
                    {
                        msg => sprintf("%s marked as watched",
                            ($submission->ogp->title || $submission->link)),
                        ts => DateTime->now
                    }
                );
                $submission->add_feeds($feed);
            }
            $submission->save;
            $self->respond_to(
                json => {
                    json => {
                        message => 'success'
                    }
                },
                html => sub {
                    $self->redirect_to($self->req->headers->referrer);
                }
            );
        }
    );
    $self->render_later;
}

sub available {
    my $self  = shift;
    my $stash = $self->stash;
    my $id    = $self->req->param('id') || $stash->{id};
    $self->submissions->search({_id => bson_oid($id)})->single(
        sub {
            my ($submissions, $err, $submission) = @_;
            return $self->reply->exception($err) if $err;
            return $self->reply->not_found if not $submission;
            if ($submission->available == 1) {
                $submission->available(0);
                my $feed = $self->feeds->create(
                    {
                        msg => sprintf("%s marked as not available",
                            ($submission->ogp->title || $submission->link)),
                        ts => DateTime->now
                    }
                );
                $submission->add_feeds($feed);
            }
            else {
                my $feed = $self->feeds->create(
                    {
                        msg => sprintf("%s marked as available",
                            ($submission->ogp->title || $submission->link)),
                        ts => DateTime->now
                    }
                );
                $submission->add_feeds($feed);
                $submission->available(1);
            }
            $submission->save;
            $self->respond_to(
                json => {
                    json => {
                        message => 'success'
                    }
                },
                html => sub {
                    $self->redirect_to($self->req->headers->referrer);
                }
            );
        }
    );
    $self->render_later;
}

sub thumbs {
    my $self     = shift;
    my $stash    = $self->stash;
    my $id       = $self->req->param('id') || $stash->{id};
    my $username = $self->session('username');

    $self->submissions->search({_id => bson_oid($id)})->single(
        sub {
            my ($submissions, $err, $submission) = @_;
            return $self->reply->exception($err) if $err;
            return $self->reply->not_found if not $submission;
            $self->users->search({username => $username})->single(
                sub {
                    my ($users, $err, $user) = @_;
                    return $self->reply->exception($err) if $err;
                    return $self->reply->not_found if not $user;
                    my $found =
                        grep { $_->id eq $user->id } @{$submission->interested};
                    if ($found) {
                        $submission->remove_interested($user);
                        my $feed = $self->feeds->create(
                            {
                                msg => sprintf(
                                    "%s unliked %s",
                                    $user->username,
                                    (
                                        $submission->ogp->title
                                            || $submission->link
                                    )
                                ),
                                ts => DateTime->now
                            }
                        );
                        $submission->add_feeds($feed);
                        $user->add_feeds($feed);
                    }
                    elsif (not $found) {
                        $submission->push_interested($user);
                        my $feed = $self->feeds->create(
                            {
                                msg => sprintf(
                                    "%s liked %s",
                                    $user->username,
                                    (
                                        $submission->ogp->title
                                            || $submission->link
                                    )
                                ),
                                ts => DateTime->now
                            }
                        );
                        $submission->add_feeds($feed);
                        $user->add_feeds($feed);
                    }
                    $submission->save;
                    $self->respond_to(
                        json => {
                            json => {
                                message    => 'success',
                                interested => [
                                    map { $_->username }
                                        @{$submission->interested}
                                ]
                            }
                        },
                        html => sub {
                            $self->redirect_to($self->req->headers->referrer);
                        }
                    );
                }
            );
        }
    );
    $self->render_later;
}

sub delete {
    my $self  = shift;
    my $stash = $self->stash;
    my $id    = $self->req->param('id') || $stash->{id};

    $self->submissions->search({_id => bson_oid($id)})->single(
        sub {
            my ($submissions, $err, $submission) = @_;
            return $self->reply->exception($err) if $err;
            return $self->reply->not_found if not $submission;
            my $feed = $self->feeds->create(
                {
                    msg => sprintf("%s deleted",
                        ($submission->ogp->title || $submission->link)),
                    ts => DateTime->now
                }
            );
            $feed->save;
            $submission->ogp->remove(sub { }) if $submission->ogp;
            $submissions->remove(sub     { });
            $self->respond_to(
                json => {
                    json => {
                        message => 'success'
                    }
                },
                html => sub {
                    $self->redirect_to($self->req->headers->referrer);
                }
            );
        }
    );
    $self->render_later;
}

sub search {
    my $self     = shift;
    my $stash    = $self->stash;
    my $search   = $self->req->param('search') || $stash->{search} || '';
    my $username = $self->session('username');

    $self->users->search({username => $username})->single(
        sub {
            my ($users, $err, $user) = @_;
            return $self->reply->exception($err) if $err;
            $self->submissions->search(
                {
                    '$or' =>
                        [{comment => qr/$search/i}, {link => qr/$search/i}]
                }
            )->all(
                sub {
                    my ($submissions, $err, $hits1) = @_;
                    return $self->reply->exception($err) if $err;
                    $self->ogps->search(
                        {
                            '$or' => [
                                {title       => qr/$search/i},
                                {description => qr/$search/i}
                            ]
                        }
                    )->all(
                        sub {
                            my ($ogps, $err, $hits2) = @_;
                            return $self->reply->exception($err) if $err;
                            push @$hits1, map { $_->submission } @$hits2;
                            my %seen;
                            my @result = grep { !$seen{$_->id}++ } @$hits1;
                            for my $sub (@result) {
                                my $found = grep { $_->id eq $user->id }
                                    @{$sub->interested};
                                $sub->{match} = 1 if $found;
                            }
                            $self->render(
                                'the_queue/submissions_list',
                                submissions => \@result
                            );
                        }
                    );
                }
            );
        }
    );
    $self->render_later;
}

sub show {
    my $self     = shift;
    my $stash    = $self->stash;
    my $id       = $stash->{id} || $self->req->param('id') || '';
    my $username = $self->session('username');

    $self->users->search({username => $username})->single(
        sub {
            my ($users, $err, $user) = @_;
            return $self->reply->exception($err) if $err;
            $self->submissions->search({_id => bson_oid($id)})->single(
                sub {
                    my ($submissions, $err, $submission) = @_;
                    return $self->reply->exception($err) if $err;
                    return $self->reply->not_found if not $submission;
                    my $found =
                        grep { $_->id eq $user->id } @{$submission->interested};
                    $submission->{match} = 1 if $found;
                    $self->render(
                        'the_queue/submissions_list',
                        submissions => [$submission]
                    );
                }
            );
        }
    );
    $self->render_later;
}

1;
