package AssetImageEditor::Log;
use strict;
use warnings;
use base 'Exporter';

our @EXPORT = qw/do_log error_log warn_log/;
use MT::Log;

sub do_log {
    my $app = shift;
    _logging($app, MT::Log::INFO(), @_);
}

sub error_log {
    my $app = shift;
    _logging($app, MT::Log::ERROR(), @_);
}

sub warn_log {
    my $app = shift;
    _logging($app, MT::Log::WARNING(), @_);
}

sub _log_category { 'AssetImageEditor'; }
sub _logging {
    my ($app, $level, $msg) = @_;

    my ($message, $metadata);
    if ( 'HASH' eq ref( $msg ) ) {
       $message  = $msg->{message};
       $metadata = $msg->{metadata} if exists $msg->{metadata};
       $metadata ||= '';
    } else {
       $message  = $msg;
       $metadata = '';
    }
    my $blog = $app->can('blog') ? $app->blog : '';
    my $blog_id = 0;
    $blog_id = $blog->id if $blog;

    my $author_id = 1;
    my $author = $app->can('user') ? $app->user : 0;
    my $log = $app->model('log')->new;

    $log->message ($message);
    $log->ip ($ENV{REMOTE_ADDR});
    $log->blog_id ($blog_id);
    $log->author_id ($author_id) if $author_id;
    $log->level ($level);
    $log->category ( &_log_category );
    $log->class ('system');
    my @t = gmtime;
    my $ts = sprintf '%04d%02d%02d%02d%02d%02d', $t[5]+1900,$t[4]+1,@t[3,2,1,0];
    $log->created_on ($ts);
    $log->created_by ($author_id) if $author_id;
    $log->metadata( $metadata ) if $metadata;
    $log->save
        or die $log->errstr;
}

1;
__END__

