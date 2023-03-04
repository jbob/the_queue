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
  $r->any('/login')->to('User#login');
  $r->any('/register')->to('User#register');
  $r->get('/about')->to('TheQueue#about');
  my $l = $r->under(sub {
    my $self = shift;
    return $self->auth;
  });
  $l->get('/logout')->to('User#logout');
  $l->get('/submissions')->to('TheQueue#submissions_list');
  $l->post('/submissions')->to('TheQueue#upsert');
  $l->get('/submissions/new')->to('TheQueue#form');
  $l->get('/submissions/delete/:id')->to('TheQueue#delete');
  $l->get('/submissions/done/:id')->to('TheQueue#done');
  $l->get('/submissions/available/:id')->to('TheQueue#available');
  $l->get('/submissions/thumbs/:id')->to('TheQueue#thumbs');
  $l->get('/submissions/edit/:id')->to('TheQueue#edit');
  $l->get('/submissions/:id')->to('TheQueue#show');
  $l->get('/users')->to('User#users_list');
  $l->get('/user/:id')->to('User#users_list');
  $l->get('/account')->to('User#account');
  $l->any('/wtw')->to('TheQueue#wtw');
  $l->any('/account/changepw')->to('User#changepw');
  $l->any('/account/delete')->to('User#deleteacc');
  $l->any('/account/theme/:themename')->to('User#theme');
  $l->any('/search')->to('TheQueue#search');
  $l->any('/feed')->to('Feed#feed');
  $l->any('/impersonate')->to('User#impersonate');

  # API
  $self->plugin(OpenAPI => {spec => 'api.json', route => $l});
}

1;
