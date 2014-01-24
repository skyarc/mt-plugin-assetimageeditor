package AssetImageEditor::API;

use strict;
use warnings;
use AssetImageEditor::Log qw/do_log error_log warn_log/;


sub instance {
    return MT->component('AssetImageEditor');
}

## 編集
sub edit {
    my ($class,$app,$config,$asset,$return_url,$save_url) = @_;
    return $app->error('Invalid request');
}

## 保存
sub save {
    my ($class,$app,$config,$asset) = @_;
    return $app->error('Invalid request');
}

## プラグイン設定の追加
sub config {
    my ($class,$app,$config,$param,$scope) = @_;
    return '';
}

## プラグイン設定の追加保存
sub save_config {
    my ($class,$app,$config,$pdata,$scope) = @_;
    return;
}

## 画像イメージの取得と保存
sub save_image {
    my ($class,$app,$config,$asset,$image_url) = @_;

    return $app->error( $class->instance->translate ('Internal Error in [_1]', __LINE__))
        unless defined $image_url && $image_url;
 
    my $ua = $app->new_ua
        or return $app->error ($class->instance->translate ('Internal Error in [_1]', __LINE__));

    ## アップロード制限を設定する。
    $ua->max_size($app->config('CGIMaxUpload'));

    ## 画像取得
    my $res = $ua->get ($image_url)
        or return $app->error ($class->instance->translate ('Network Error'));

    return $app->error ( $class->instance->translate ('Error in proceeding of [_1] editor - status:[_2]', $config->{id}, $res->status_line))
        unless $res->is_success;

    ## アップロードサイズが画像サイズと一致しない場合
    unless ( $res->header( 'content-length' ) == length $res->content ) {
       return $app->error( 
          sprintf '%s - content-length: %d byte / image-size: %d byte / CGIMaxUpload: %d byte'
          ,$class->instance->translate ('Image size and upload size does not match' )
          ,$res->header('content-length')
          ,length $res->content
          ,$app->config('CGIMaxUpload'));
    }

    my $file_data = $res->content
        or return $app->error ( $class->instance->translate ('No Data - [_1]', MT::Util::encode_html($image_url) ));  

    my $fmgr;
    if ($asset->blog_id) {
        my $blog = MT::Blog->load ($asset->blog_id)
            or return $app->error ($app->translate ('No Blog'));
        $fmgr = $blog->file_mgr;
    } else {
        $fmgr = MT::FileMgr->new('Local');
    }
    $fmgr->put_data ($file_data, $asset->file_path, 'upload');

    $asset->image_height (undef);
    $asset->image_width (undef);
    $asset->modified_by ($app->user->id);
    $asset->save
        or return $app->error ($asset->errstr);

    ## 画像の更新を記録
    my $msg = {
        message => 'AssetImageEditor: ' 
            . $class->instance->translate('Image has been updated - [_1](id:[_2])',$asset->label,$asset->id),
        metadata => sprintf ( "editor: %s - url: %s", $config->{id}, $asset->url ),
    };
    do_log ($app,$msg);

    return $app->redirect ($app->uri (
        mode => 'view',
        args => {
            _type => 'asset',
            blog_id => $asset->blog_id,
            id => $asset->id,
        },
    ));
}

## エディタの呼び出し
sub call_editor {
    my ($class,$app,$request,$contents) = @_;

    my $pname = $class->instance->id;
    my $ua = $app->new_ua;
    unless ( defined $ua && $ua ) {
        my $msg = $class->instance->translate('Internal Error in [_1]', __LINE__);
        $class->error_log ($app, "$pname:$msg" );
        return $app->error( $msg );
    }
    my $respons = $ua->post (
        $request,
        Content_Type => 'form-data',
        Content => $contents
    );
    unless( $respons->is_success ) {

        my $status = $respons->status_line;
        unless ( $status == 302 ) {

            ## エラー
            my $msg = $class->instance->translate ('Error in proceeding - [_1]', $respons->status_line);
            $class->error_log ($app, "$pname:$msg");
            return $app->error( $msg );

        }
    }
    return $respons;
}
1;
__END__
