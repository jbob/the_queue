package TheQueue::Model::Ogp;
use Mandel::Document;
use Types::Standard qw( Str Int ArrayRef HashRef Num Bool );

field title           => (isa => Str);
field description     => (isa => Str);
field image           => (isa => Str);
belongs_to submission => 'TheQueue::Model::Submission';

1;
