package AssetImageEditor;

use strict;
use warnings;
use File::Basename qw/dirname/;
use File::Spec;
use AssetImageEditor::Log qw/do_log error_log warn_log/;
use Data::Dumper;

sub instance {
   return MT->component( 'AssetImageEditor' );
}

sub condition {
    my $asset = shift;

    if ( $asset ) {
       return 0 
          unless $asset && $asset->isa('MT::Asset::Image');
    }

    my $editor;
    eval { $editor = editor_selector( MT->app ); }; 
    return 0 if $@;
    return 0 unless defined $editor && $editor;
    return 1;
}

## エディタ情報の取得
##  ・プラグイン設定をもとに取得 editor( $app )
##  ・サービス名を指定して取得 editr( $app, 'pixlr' ) 
sub editor_selector {
    my $app = shift;

    my $config = _editor_config()
        or return '';

    my $plugin = instance()
        or return '';

    my $key;
    $key = scalar @_
       ? shift
       : _get_editor_key($app);

    return '' unless $key;

    my $editor =  _init_editor($app, $config, $key)
        or return '';

    $editor->{id} ||= $key;
    return $editor;
}

## 各ブログ、ウェブサイトのエディタを示すキーを取得
sub _get_editor_key {
    my $app = shift;

    my $plugin = instance() or return 0;

    my $key = 0;
    my $blog_id = $app->param('blog_id') || 0;
    if ( $blog_id ) {
        my $blog = $app->blog;
        if ( $blog->is_blog ) {
            $key = $plugin->get_config_value('service','blog:'.$blog->id)
                 or return 0;
            return $key unless $key == 1; ## 1の場合は設定の継承を行う
            $blog = $blog->website;
        }
        $key = $plugin->get_config_value('service','blog:'.$blog->id)
            or return 0;
        return $key unless $key == 1;
    }
    $key = $plugin->get_config_value('service','system');

    return 0 if $key == 1;
    return $key;
}

## エディタ定義ファイル editors.yaml 読み込み
our $AIE_EDITORS;
our $AIE_EDITORS_ENABLE;
sub _editor_config {

    return $AIE_EDITORS if defined $AIE_EDITORS && $AIE_EDITORS;

    my $path = __FILE__;
    $path = dirname( $path );
    $path = File::Spec->catdir( $path , 'editors.yaml' );

    require MT::Util::YAML; 
    $AIE_EDITORS = MT::Util::YAML::LoadFile( $path );

    return $AIE_EDITORS;

}

##  初期化
##  $all_edtiors_key = _init_editor ( $app, $config );
##  $editor = _init_editor ( $app , $config , $service_key );
sub _init_editor {
    my $app = shift;
    my $config = shift;
    my $service_key = '';

    my @service_keys;
    if ( @_ ) {
        ( $service_key ) = @_;
        return '' unless $service_key;
        push @service_keys, $service_key;
    }
    else {
        @service_keys = keys %$config;
    }

    my @editors;
    for ( @service_keys ) {

        next if exists $AIE_EDITORS_ENABLE->{$_};

        my $editor = $config->{$_};
        my $class  = $editor->{class};
        if ( defined $class && $class ) {

            eval "require $class";
            if ( $@ ) {
                my $metadata = $@;
                error_log(
                    $app,
                    {
                        message => 'AssetImageEditor: ' 
                           . instance()->translate('Faild require [_1]' , $class),
                        metadata => $metadata,
                    },
                );
                $AIE_EDITORS_ENABLE->{$_} = 0;
                next;
            }
            $AIE_EDITORS_ENABLE->{$_} = 1;
        }
    }
    if ( @_ ) {
        if ( $AIE_EDITORS_ENABLE->{$service_key} ) {
           return $config->{$service_key};
        } 
        return '';
    }
    my @keys = keys %$AIE_EDITORS_ENABLE;
    return wantarray ? @keys : \@keys;
}

sub save_config_filter {
    my ($plugin,$data,$scope) = @_;

    my $app = MT->instance->app;
    my $service = $data->{service}; 
    if ( $service == 1 || $service == 0 ) {
        return 1;
    }
    my $editor = editor_selector($app,$service)
        or return 1;

    my $class = $editor->{class};
    {
        no strict 'refs';
        *{ $class . '::save_config'}->($class,$app,$plugin,$editor,$data,$scope);
    }
    return 1;
}

sub blog_config_template {
    my $app   = MT->instance->app;
    my $scope = $app->blog->is_blog
         ? 'blog'
         : 'website';
    return _config_template($scope,@_);
}

sub system_config_template {
    return _config_template('system',@_);
}

sub _config_template {
    my ($scope,$plugin,$param,$data_scope) = @_;

    my $tmpl = <<'HTMLHEREDOC'; 
<script type="text/javascript">
/* <![CDATA[ */
function change_asset_image_editor_settings(e) {
 var s = e.value;
 var k = 'asset-image-editor-' + s;
 jQuery('#asset-image-editor-settings').children('div').each(function() {
  if ( jQuery(this).attr('id') === k ) {
   jQuery(this).removeClass("hidden");
   jQuery(this).attr('style','display:block');
  } else {
   jQuery(this).addClass("hidden");
   jQuery(this).attr('style','display:none');
  }
 });
}
/* ]]> */
</script>

<mtapp:setting
   id="assset-image-editor-service-type"
   label="<__trans phrase="Editor Choice">">
<select name="service" id="asset-image-editor-service" onChange="change_asset_image_editor_settings(this);">
<option value="0" <mt:if name="service" eq="0">selected="selected"</mt:if>><__trans phrase="Disable"></option>
<mt:if name="is_website">
<option value="1" <mt:if name="service" eq="1">selected="selected"</mt:if>><__trans phrase="Use the system settings"></option>
<mt:elseif name="is_blog">
<option value="1" <mt:if name="service" eq="1">selected="selected"</mt:if>><__trans phrase="Use the website settings"></option>
</mt:if>
<mt:loop name="asset_image_editor_services">
<option value="<mt:var name="service_key">"<mt:if name="selected">selected="selected"</mt:if>><mt:var name="service_key"></option>
</mt:loop>
</select>
</mtapp:setting>

<div id="asset-image-editor-settings">

<div id="asset-image-editor-1" <mt:unless name="service" eq="1">style="display:none"</mt:unless> >
  <!-- inheritance information -->
  <mt:if name="inheritance_service_name">
  <mtapp:setting
      id="asset-image-editor-inheritance-name"
      label="<__trans phrase="Service Name">:">
      <label><mt:var name="inheritance_service_name"></label>
  </mtapp:setting>
  <mt:else>
  <mtapp:setting
      id="asset-image-editor-inheritance-name">
      <label><__trans phrase="Disable"></label>
  </mtapp:setting>
  </mt:if>
  <!-- //inheritance information -->
</div>

<mt:loop name="asset_image_editor_services">
<div id="asset-image-editor-<mt:var name="service_key">" <mt:unless name="selected">style="display:none"</mt:unless> >

  <!-- information -->
  <mtapp:setting
      id="asset-image-editor-<mt:var name="service_key">-name"
      label="<__trans phrase="Service Name">:">
      <label><mt:var name="service_name"></label>
  </mtapp:setting>
  
  <mtapp:setting
      id="asset-image-editor-<mt:var name="service_key">-description"
      label="<__trans phrase="Service Description">:">
      <label><mt:var name="service_description"></label>
  </mtapp:setting>

  <mtapp:setting
      id="asset-image-editor-<mt:var name="service_key">-provider"
      label="<__trans phrase="Service Provider">:">
      <label><mt:var name="service_provider"></label>
  </mtapp:setting>

  <mtapp:setting
      id="asset-image-editor-<mt:var name="service_key">-terms"
      label="<__trans phrase="Terms of Service">:">
      <label><mt:var name="service_terms"></label>
  </mtapp:setting>

  <!-- //information -->

</div> <!-- // div asset-image-editor-<mt:var name="service_key"> -->
</mt:loop>

</div>
HTMLHEREDOC

    my $app = MT->instance->app;
    $param->{is_website} = $scope eq 'website';
    $param->{is_blog}    = $scope eq 'blog';
    $param->{is_system}  = $scope eq 'system';

    my $config = _editor_config();
    my @editor_keys;
    @editor_keys = _init_editor($app,$config);
    my @editors;

    ## 親オブジェクトの設定を継承している場合、設定内容を表示する
    if ( $param->{service} == 1 ) {

        my $ieditor = editor_selector($app);

        $param->{inheritance_service_name} = $ieditor->{name} if $ieditor;
    }

    ## エディタ情報を表示する
    for my $key ( @editor_keys ) {

        my $editor = editor_selector($app,$key);
        next unless $editor;

        ## 各エディタのサービス情報
        my $is_selected = $param->{service} eq $key;
        my $service = { 
            service_key  => $key, 
            service_name => $editor->{name},
            selected => $is_selected,
            service_provider => $editor->{provider},
            service_description => $editor->{description},
            service_terms => $editor->{terms},
            settings => '',
        };
        unless ( $editor->{settings} ) {
            push @editors , $service;
            next;
        }

        ## エディタ依存の設定項目を追加する
        my @options;
        {
            no strict 'refs';
            my $class = $editor->{class};
            $service->{settings} = *{ $class . '::config'}->($class,$app,$plugin,$editor,$param,$data_scope);
        }
        push @editors, $service; 

    }
    $param->{asset_image_editor_services} = \@editors;
    return $tmpl;
}

## 権限判定 (許可: システム管理者、ブログ、ウェブサイト管理者、アイテムの編集権限)
sub _permission_check {
    my ($app, $blog) = @_;

    return 0 unless $app->isa('MT::App');

    return 0 unless $app->can('user');
    my $author = $app->user 
        or return 0;

    return 1 if $author->is_superuser;

    my $perms = $author->permissions(0);
    return 1 if $perms->can_administer;

    $perms = $author->permissions($blog->id);
    return 1 if $blog->is_blog ? $perms->can_administer_blog() : $perms->can_administer_website();

    return $author->permissions($blog->id)->can_edit_assets() ? 1 : 0;
}

## 編集の開始
sub edit {
    my $app = shift;

    my $plugin = &instance;
    unless ( $plugin ) {      
       return $app->error( $plugin->translate('Disable Plugin') );
    }
    my $asset_id = $app->param('id');
    unless ( defined $asset_id && $asset_id ) {
       return $app->error( $plugin->translate('Invalid ID') );
    }
    
    my $asset = MT::Asset->load($asset_id);
    unless ( $asset ) {
       return $app->error( $plugin->translate('Invalid request') );
    }
    unless ( $app->validate_magic ) {
       return $app->error( $plugin->translate('Invalid Session') );
    }

    my $blog = MT::Blog->load( $asset->blog_id );
    unless ( $blog ) {
       return $app->error( $plugin->translate('No Blog') );
    }

    unless ( _permission_check( $app , $blog ) ) {
       return $app->error( $plugin->translate('Permission denied') );
    }

    my $editor = editor_selector( $app );
    unless ( $editor ) {
        return $app->error( $plugin->translate('No Editor') );
    }

    my $return_url = $app->base . $app->uri( mode => 'view', 
        args => {
            _type => 'asset',
            id => $asset->id,
            blog_id => $asset->blog_id,
    }); 
    my $save_url = $app->base . $app->uri( mode => 'asset_image_edit_saver',
        args => {
            id => $asset->id,
            _type => $editor->{id},
            blog_id => $asset->blog_id,
            magic_token => $app->current_magic,
    });
    my $class = $editor->{class};
    {
       no strict 'refs';
       return *{ $class . '::edit' }->( $class, $app, $editor, $asset, $return_url, $save_url); 
    }
}

## 編集画像の保存
sub save {
    my $app = shift;
    my $plugin = &instance;
    unless ( $plugin ) {
       return $app->error( $plugin->translate('Disable Plugin') );
    }
    my $asset_id = $app->param('id');
    unless ( defined $asset_id && $asset_id ) {
       return $app->error( $plugin->translate('Invalid ID') );
    }
 
    my $asset = MT::Asset->load($asset_id);
    unless ( $asset ) {
       return $app->error( $plugin->translate('Invalid request') );
    }

    unless ( $app->validate_magic ) {
       return $app->error( $plugin->translate('Invalid Session') );
    }

    my $blog = MT::Blog->load( $asset->blog_id );
    unless ( $blog ) {
       return $app->error( $plugin->translate('No Blog') );
    }

    unless ( _permission_check( $app , $blog ) ) { 
       return $app->error( $plugin->translate('Permission denied') );
    }

    my $editor = editor_selector( $app );
    unless ( $editor ) {
        return $app->error( $plugin->translate('No Editor') );
    }

    my $class = $editor->{class};
    {
       no strict 'refs';
       return *{ $class . '::save' }->($class, $app, $editor, $asset);
    }
}

1;

__END__
