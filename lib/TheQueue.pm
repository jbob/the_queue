package TheQueue;
use Mojo::Base 'Mojolicious';
use TheQueue::Model;

# This method will run once at server start
sub startup {
    my $self = shift;

    my $config = $self->plugin('Config');
    $self->secrets($config->{secret});

    $self->plugin('TheQueue::Helpers');
    $self->ua->proxy->detect;
    $self->ua->max_redirects(3);
    $self->ua->connect_timeout(3);
    $self->ua->request_timeout(3);

    # Router
    my $r = $self->routes;

    # Normal route to controller
    $r->get('/')->to('TheQueue#index')->name('index');
    $r->any('/login')->to('TheQueue#login');
    $r->any('/register')->to('TheQueue#register');
    $r->get('/about')->to('TheQueue#about');
    my $l = $r->under(
        sub {
            my $self = shift;
            return $self->auth;
        }
    );
    $l->get('/logout')->to('TheQueue#logout');
    $l->get('/submissions')->to('TheQueue#submissions_list');
    $l->post('/submissions')->to('TheQueue#upsert');
    $l->get('/submissions/new')->to('TheQueue#form');
    $l->get('/submissions/delete/:id')->to('TheQueue#delete');
    $l->get('/submissions/done/:id')->to('TheQueue#done');
    $l->get('/submissions/available/:id')->to('TheQueue#available');
    $l->get('/submissions/thumbs/:id')->to('TheQueue#thumbs');
    $l->get('/submissions/edit/:id')->to('TheQueue#edit');
    $l->get('/submissions/:id')->to('TheQueue#show');
    $l->get('/users')->to('TheQueue#users_list');
    $l->get('/user/:id')->to('TheQueue#users_list');
    $l->get('/account')->to('TheQueue#account');
    $l->any('/wtw')->to('TheQueue#wtw');
    $l->any('/account/changepw')->to('TheQueue#changepw');
    $l->any('/account/delete')->to('TheQueue#deleteacc');
    $l->any('/search')->to('TheQueue#search');
    $l->any('/feed')->to('TheQueue#feed');
    $l->any('/impersonate')->to('TheQueue#impersonate');

    # API
    $l->get('/api/submissions')->to('TheQueue#submissions_list');
    $l->any('/api/wtw')->to('TheQueue#wtw');
    $l->any('/api/feed')->to('TheQueue#feed');

}

1;
