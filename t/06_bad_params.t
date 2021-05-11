use v6;
use lib '../lib';

use Test;
use Template::Nest;
use Data::Dump;

use-ok('Template::Nest');

my $template_dir = $*PROGRAM.IO.parent.add('templates').resolve.Str;


my $nest = Template::Nest.new(
    template_dir => $template_dir,
    template_ext => '.html',
    name_label => 'NAME',
    token_delims => ['<!--%','%-->'],
    defaults_namespace_char => '',
    die_on_bad_params => True
);


my $table = {
    NAME => 'table',
    rows => [{
        NAME => 'tr',
        cols => {
            NAME => 'tr',
            bad_param => 'stuff'
        }
    },{
        NAME => 'tr',
        cols => {
            NAME => 'td',
            #no contents
        }
    }]
};


try { $nest.render( $table ) };

like( $!, rx/bad_param.*?does \s not \s exist/, "die on bad params" );

$nest.die_on_bad_params = False;

my $x_html = "<table><tr><tr></tr></tr><tr><td></td></tr></table>";
my $html = $nest.render( $table );
$html ~~ s:g/\s*//;

is( $html, $x_html, "ignores bad param with die_on_bad_params = 0" );

done-testing;
