package AssetImageEditor::API::Pixlr;

use strict;
use warnings;
use base qw(AssetImageEditor::API);
use MT::Util;

sub edit {
    my ($class,$app,$config,$asset,$return_url,$save_url) =  @_;

    my $type = '';
    $type = $1 if $asset->file_path =~ /\.([^\.]+)$/;
    $type = 'jpg' if $type eq 'jpeg';

    my $contents = [
         image      => [ MT::I18N::utf8_off($asset->file_path) ],
         title      => MT::I18N::utf8_off($asset->label),
         exit       => MT::Util::encode_url($return_url),
         target     => MT::Util::encode_url($save_url),
         referrer   => 'MovableType',
         locktitle  => 'true',
         locktarget => 'true',
    ];
    push @$contents , ( locktype => $type ) if $type;
    my $res = $class->call_editor($app,$config->{request},$contents);
    return $app->error if $app->error;

    my $url = $res->content;
    if ( $url =~ /a\ href="([^"]+)"/ ) {
       $url = $1;
       return $app->redirect( $url );
    }
    return $url;

} 

sub save {
    my ($class,$app,$config,$asset) = @_;
    my $image_url = $app->param('image');
    return $class->save_image($app,$config,$asset,$image_url);
}

sub config {
    my ($class,$app,$config,$param,$scope) = @_;
    return '';
}

sub save_config {
    my ($class,$app,$config,$pdata,$scope) = @_;
    return;
}

1;
__END__
