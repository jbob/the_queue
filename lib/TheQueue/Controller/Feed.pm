package TheQueue::Controller::Feed;
use Mojo::Base 'Mojolicious::Controller';

use Mango::BSON 'bson_oid';
use Array::Utils qw(:all);
use DateTime;

sub feed {
    my $self  = shift;
    my $stash = $self->stash;

    my $search = {
        ts => {
            '$gt' => DateTime->now->subtract(days => 120)->stringify
        }
    };

    $self->feeds->search($search)->all(
        sub {
            my ($feeds, $err, $feed) = @_;
            $self->reply->exception($err) if $err;
            $self->reply->not_found if not $feed;

            # Sort here, should really happen at the DB level but neither
            # Mandel nor Mango seem to support that
            @{$feed} = sort { $a->ts cmp $b->ts } @{$feed};
            if ($self->req->url->path =~ m|^/api/|) {
                $self->render(json => {
                        feed => [
                            reverse map {
                                my $item = $_;
                                my $ret  = {};
                                $ret->{msg}  = $item->msg;
                                $ret->{user} = {
                                    username => $item->user->username,
                                    id       => $item->user->id
                                } if $item->user;
                                $ret->{submission} = {
                                    id    => $item->submission->id,
                                    title => $item->submission->ogp->title,
                                    image => $item->submission->ogp->image,
                                    description => $item->submission->ogp->description,
                                    comment   => $item->submission->comment,
                                    link      => $item->submission->link,
                                    available => $item->submission->available,
                                    done      => $item->submission->done,
                                    submitter => {
                                        username => $item->submission->user->username,
                                        id => $item->submission->user->id
                                    },
                                    interested => [
                                        map {
                                            {
                                                username => $_->username,
                                                id       => $_->id
                                            }
                                        } @{$item->submission->interested}
                                    ]
                                } if $item->submission;
                                $ret;
                            } @{$feed}
                        ]
                });
            } else {
                $self->render(feed => [reverse @{$feed}]);
            }
        }
    );
    $self->render_later;
}

1;
