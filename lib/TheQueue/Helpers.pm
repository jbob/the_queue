package TheQueue::Helpers;

use Mojo::Base 'Mojolicious::Plugin';
use Mojo::IOLoop;

use Encode qw(decode encode);

sub register {
    my ($self, $app) = @_;

    $app->helper(model => sub {
        state $model = TheQueue::Model->connect($app->config->{mongouri});
    });

    $app->helper(users => sub { $_[0]->app->model->collection('user') } );
    $app->helper(submissions => sub { $_[0]->app->model->collection('submission') } );
    $app->helper(ogps => sub { $_[0]->app->model->collection('ogp') } );

    $app->helper(auth => sub {
        my $self = shift;
        return 1 if $self->session
                  and $self->session('logged_in')
                  and $self->session('logged_in') == 1;
        if (not $self->session('username')) {
            $self->session(logged_in => 0);
            $self->session(target => $self->req->url->to_abs->path);
            $self->redirect_to('/login');
            return 0;
        }

        my $username = $self->session('username');
        my $password = $self->session('password');
        my $user = $app->users->search({ username => $username, password => $password })->single;

        if ($user) {
            $self->session(logged_in => 1);
            $self->session(password => '');
            return 1;
        } else {
            $self->flash(msg => 'Invalid login', type => 'danger');
            $self->session(logged_in => 0);
            $self->session(target => $self->req->url->to_abs->path);
            $self->redirect_to('/login');
            return 0;
        }
    });
}

1;
