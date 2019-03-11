# TheQueue

Web-based queue thingy written with Perl/Mojolicious/MongoDB/Mandel. See it
in action at [https://queue.markusko.ch](https://queue.markusko.ch)

## Dependencies

* Perl
* Mojolicious
* Mandel (ORM module for Mango/MongoDB)
* MongoDB

## Installation

Simply clone or download the the repository, adjust the the\_queue.conf file and
execute either:

    $ morbo script/the_queue (for development), or
    $ hypnotoad script/the_queue (for production)

The app will then listen on either 127.0.0.1:3000 (development) or 0.0.0.0:8014
(production).

To access your app via a reverse proxy, create a minimal VHost like this:

    <VirtualHost *:443>
        ServerName thequeue.markusko.ch
        ProxyPass / http://127.0.0.1:8014/
    </VirtualHost>
