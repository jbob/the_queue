package TheQueue::Controller::User;
use Mojo::Base 'Mojolicious::Controller';

use Mango::BSON 'bson_oid';
use Array::Utils qw(:all);
use DateTime;

sub login {
  my $self     = shift;
  my $username = $self->param('username') // '';
  my $password = $self->param('password') // '';

  if ($username and $password) {
    $self->session(username => $username);
    $self->session(password => $password);
    $self->session(themename => $self->session('themename') // 'default');
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
  $self->session(username  => undef);
  $self->session(attendees => undef);
  return $self->redirect_to('index');
}

sub register {
  my $self      = shift;
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

  $self->users->search({username => $username})->single(sub {
    my ($users, $err, $user) = @_;
    return $self->reply->exception($err) if $err;
    if ($user) {
      $self->flash(msg => 'Username already taken', type => 'danger');
      return $self->redirect_to('register');
    }
    my $info = $self->gen_pwhash({password => $password1});
    $self->users->create({username => $username, password => $info->{hash}, salt => $info->{salt}, cost => $info->{cost}
    })->save(sub {
      my ($users, $err, $user) = @_;
      return $self->reply->exception($err) if $err;
      $self->render(success => 1);
    });
  });
  $self->render_later;
}

sub changepw {
  my $self          = shift;
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

  $self->users->search({username => $username})->single(sub {
    my ($users, $err, $user) = @_;
    return $self->reply->exception($err) if $err;
    return $self->reply->not_found       if not $user;
    if ($user) {
      my $old_hash = $self->gen_pwhash({password => $old_password, salt => $user->salt, cost => $user->cost})->{hash};
      if ($old_hash eq $user->password) {
        my $new_info = $self->gen_pwhash({password => $new_password1});
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
    $self->users->search({username => $username})->single(sub {
      my ($users, $err, $user) = @_;
      return $self->reply->exception($err) if $err;
      return $self->reply->not_found       if not $user;
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

sub theme {
  my $self = shift;
  my $themename = $self->stash('themename') || 'default';
  $self->session('themename', $themename);
  return $self->redirect_to('account');
}

sub impersonate {
  my $self          = shift;
  my $stash         = $self->stash;
  my $orig_username = $self->session('username');
  $self->users->search({username => $orig_username})->single(sub {
    my ($users, $err, $orig_user) = @_;
    return $self->reply->exception($err) if $err;
    return $self->reply->not_found       if not $orig_user;
    return $self->render(status => 403, text => 'Forbidden')
        if not $orig_user->admin and not $self->session('was_admin');
    my $username = $self->param('username') // '';

    if ($self->req->method eq 'GET') {
      $self->users->all(sub {
        my ($users, $err, $user) = @_;
        return $self->reply->exception($err) if $err;
        return $self->reply->not_found       if not $user;
        $self->render(users => $user);
      });
      return $self->render_later;
    }

    if (not $username) {
      $self->flash(msg => 'Please choose an user!', type => 'danger');
      return $self->redirect_to('impersonate');
    }

    $self->users->search({username => $username})->single(sub {
      my ($users, $err, $user) = @_;
      return $self->reply->exception($err) if $err;
      return $self->reply->not_found       if not $user;
      $self->session(username  => $username);
      $self->session(was_admin => 1);
      $self->flash(msg => 'Be excellent to each other!', type => 'danger');
      return $self->redirect_to('/');
    });
  });
  $self->render_later;
}

sub users_list {
  my $self  = shift;
  my $stash = $self->stash;
  my $id    = $stash->{id} || $self->req->param('id') || '';
  if ($id) {
    $self->users->search({_id => bson_oid($id)})->single(sub {
      my ($users, $err, $user) = @_;
      return $self->reply->exception($err) if $err;
      return $self->reply->not_found       if not $user;
      if ($self->req->url->path =~ m|^/api/|) {
        return if not $self->openapi->valid_input;
        $self->render(
          openapi => {
            users => [
              {id => $user->id, username => $user->username, submissions => $user->submissions, feed => $user->feeds}
            ]
          }
        );
      } else {
        $self->render('user/user', user => $user);
      }
    });
  } else {
    $self->users->all(sub {
      my ($users, $err, $user) = @_;
      return $self->reply->exception($err) if $err;
      return $self->reply->not_found       if not $user;
      if ($self->req->url->path =~ m|^/api/|) {
        return if not $self->openapi->valid_input;
        $self->render(
          openapi => {
            users => [
              map { {id => $_->id, username => $_->username, submissions => $_->submissions, feed => $_->feeds}; }
                  @$user
            ]
          }
        );
      } else {
        $self->render(users => $user);
      }
    });
  }
  $self->render_later;
}
1;
