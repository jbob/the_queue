package TheQueue::Model::User;
use Mandel::Document;
use Types::Standard qw( Str Int ArrayRef HashRef Num Bool);

field username       => (isa => Str);
field password       => (isa => Str);
field salt           => (isa => Str);
field cost           => (isa => Num);
field admin          => (isa => Bool);
has_many submissions => 'TheQueue::Model::Submission';
has_many feeds       => 'TheQueue::Model::Feed';

1;
