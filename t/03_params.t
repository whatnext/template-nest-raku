use v6;
use lib '../lib';

use Test;
use Template::Nest;

use-ok('Template::Nest');

my $template_dir = $*PROGRAM.IO.parent.add('templates').resolve.Str;

my $nest = Template::Nest.new(
    template_dir => $template_dir,
    template_ext => '.html',
    name_label => 'NAME',
    token_delims => ['<!--%','%-->'],
    defaults_namespace_char => ''
);


my %templates = (
    'table' => [ "rows" ],
    'tr' => [ 'cols' ],
    'td' => [ 'contents' ],
    'tr_default' => [ 'col1', 'cols' ],
    'nested_default_outer' => [
          'config.default2',
          'config.nested.iexist',
          'contents'
    ],
    'nested_default_contents' => [
          'config.default1',
          'config.default2',
          'config.nested.idontexist',
          'config.nested.iexist',
          'non_config_var',
          'ordinary_default'
    ]
);


for %templates.keys -> $template {

    my $params = $nest.params( $template );

    is-deeply($params, %templates{$template}, "params in $template");

}


done-testing;
