package TheQueue::Model::Feed;
use Mandel::Document;
use Types::Standard qw( Str Int ArrayRef HashRef Num Bool );
use Types::DateTime -all;

field msg             => (isa => Str);
field ts              => (isa => DateTime);
belongs_to user       => 'TheQueue::Model::User';
belongs_to submission => 'TheQueue::Model::Submission';

1;
