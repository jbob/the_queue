package TheQueue::Model::User;
use Mandel::Document;
use Types::Standard qw( Str Int ArrayRef HashRef Num );

field username        => ( isa => Str );
field password        => ( isa => Str );
has_many submissions  => 'TheQueue::Model::Submission';

1;
