package TheQueue::Model::Submission;
use Mandel::Document;
use Types::Standard qw( Str Int ArrayRef HashRef Num Bool );
use Types::DateTime -all;

field link         => (isa => Str);
field comment      => (isa => Str);
field done         => (isa => Bool);
field available    => (isa => Bool);
field ts           => (isa => DateTime);
has_one ogp        => 'TheQueue::Model::Ogp';
belongs_to user    => 'TheQueue::Model::User';
list_of interested => 'TheQueue::Model::User';
has_many feeds     => 'TheQueue::Model::Feed';

1;
