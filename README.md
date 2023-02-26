# TheQueue

Web-based queue thingy written in Perl. Depends on:
* Perl
* Mojolicious
* Mandel (ORM module for Mango/MongoDB)
* MongoDB

See it in action at [https://q.markusko.ch](https://q.markusko.ch).

## Installing dependencies

Simply clone or download the repository and run:

```bash
cpanm --notest --installdeps .
```

### MongoDB

MongoDB version 6 (and higher is not yet supported by [Mango](https://metacpan.org/pod/Mango). Only use up to version
5.x. See also [https://www.mongodb.com/docs/v6.0/release-notes/6.0-compatibility/#legacy-opcodes-removed](https://www.mongodb.com/docs/v6.0/release-notes/6.0-compatibility/#legacy-opcodes-removed).

## Configuration

Found in [the_queue.conf](the_queue.conf).

## Running production

```bash
hypnotoad script/the_queue
```

By default, the production server will listen on `[::1]:8014`.

To access your app via a reverse proxy, create a minimal VHost like this:

```
<VirtualHost *:443>
    ServerName q.markusko.ch
    ProxyPass / http://localhost:8014/
</VirtualHost>
```

## Running dev environment

Start the dev server listening on http://127.0.0.1:3000 with:

```bash
morbo script/the_queue
```

Hint: if you don't have a mongo server, you can simply spin one up in Docker with:

```bash
docker run --rm -d --name queue-mongo -p 27017:27017 mongo:5.0.15
```

(just remember to `docker stop queue-mongo` the database again when you don't need it anymore)
