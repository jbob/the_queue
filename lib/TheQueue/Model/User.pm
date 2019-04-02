package TheQueue::Model::User;
use Mandel::Document;
use Types::Standard qw( Str Int ArrayRef HashRef Num );

field username        => ( isa => Str );
field password        => ( isa => Str );
field salt            => ( isa => Str );
field cost            => ( isa => Num );
has_many submissions  => 'TheQueue::Model::Submission';

1;
