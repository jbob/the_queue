package TheQueue::Helpers;

use Mojo::Base 'Mojolicious::Plugin';
use Mojo::IOLoop;

use Digest::SHA qw(sha512_hex);
use Crypt::Eksblowfish::Bcrypt qw(bcrypt_hash en_base64);
use Data::Entropy::Algorithms qw(rand_bits rand_int);

sub register {
    my ($self, $app) = @_;

    $app->helper(
        model => sub {
            state $model = TheQueue::Model->connect($app->config->{mongouri});
        }
    );

    $app->helper(users => sub { $_[0]->app->model->collection('user') });
    $app->helper(submissions => sub { $_[0]->app->model->collection('submission') });
    $app->helper(ogps => sub { $_[0]->app->model->collection('ogp') });
    $app->helper(feeds => sub { $_[0]->app->model->collection('feed') });

    $app->helper(
        gen_pwhash => sub {
            my $self => shift;
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
    );

    $app->helper(
        auth => sub {
            my $self = shift;
            return 1
                if $self->session
                and $self->session('logged_in')
                and $self->session('logged_in') == 1;
            if (not $self->session('username')) {
                $self->session(logged_in => 0);
                $self->session(target    => $self->req->url->to_abs->path);
                $self->redirect_to('/login');
                return 0;
            }

            my $username = $self->session('username');
            my $password = $self->session('password');
            my $user     = $app->users->search({username => $username})->single;

            if ($user) {
                my $salt = $user->salt;
                my $cost = $user->cost;
                if ($salt and $cost) {
                    my $password_hash = $self->gen_pwhash(
                        {salt => $salt, cost => $cost, password => $password})->{hash};
                    if ($password_hash eq $user->password) {
                        $self->session(logged_in  => 1);
                        $self->session(password   => '');
                        $self->session(admin      => $user->admin);
                        $self->session(expiration => 604800);
                        return 1;
                    }
                }
            }
            $self->flash(msg => 'Invalid login', type => 'danger');
            $self->session(logged_in => 0);
            $self->session(target    => $self->req->url->to_abs->path);
            $self->redirect_to('/login');
            return 0;
        }
    );
}

1;
