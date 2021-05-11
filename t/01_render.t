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
    token_delims => ['<!--%','%-->']
);




#check any params not specified render as empty strings
my %table =
    NAME => 'table',
    rows => [{
        NAME => 'tr',
        cols => {
            NAME => 'td',
            #no contents
        }
    },{
        NAME => 'tr',
        cols => {
            NAME => 'td',
            #no contents
        }
    }];

my $html = $nest.render( %table );
$html ~~ s:g/\s//;
my $x_html = "<table><tr><td></td></tr><tr><td></td></tr></table>";

is( $html, $x_html, "html correct unspecified parameters" );


%table =
    NAME => 'table',
    rows => [{
        NAME => 'tr',
        cols => {
            NAME => 'td',
            contents => '1'
        }
    },{
        NAME => 'tr',
        cols => {
            NAME => 'td',
            contents => '2'
        }
    }];


$html = $nest.render( %table );
$x_html = "<table><tr><td>1</td></tr><tr><td>2</td></tr></table>";

ok( $html, "html is returned" );
is( $html.WHAT,Str,"returned html is a string" );

$html ~~ s:g/\s//;

is( $html, $x_html, "returned html is correct" );


#my @cd
$nest.comment_delims = "<!--","-->";
$nest.show_labels = True;
$html = $nest.render( %table );

$html ~~ s:g/\s//;

$x_html = "<!--BEGINtable--><table><!--BEGINtr--><tr><!--BEGINtd--><td>1</td><!--ENDtd--></tr><!--ENDtr--><!--BEGINtr--><tr><!--BEGINtd--><td>2</td><!--ENDtd--></tr><!--ENDtr--></table><!--ENDtable-->";

is( $html, $x_html, "html correct with show_labels=True" );





my %templates =
    page => '
        <html>
                <head>
                        <style>
                                div {
                                        padding: 20px;
                                        margin: 20px;
                                        background-color: yellow;
                                }
                        </style>
                </head>

                <body>
                        \<!--% contents %-->
                        <!--% contents %-->
                </body>
        </html>',



    box => '
        <div>
                <!--% title %-->
        </div>';

my %page =
        NAME => 'page',
        contents => [{
                NAME => 'box',
                title => 'First nested box'
        },];

push %page<contents>, {
        NAME => 'box',
        title => 'Second nested box'
};

my $expected = '<!-- BEGIN page -->

        <html>
                <head>
                        <style>
                                div {
                                        padding: 20px;
                                        margin: 20px;
                                        background-color: yellow;
                                }
                        </style>
                </head>

                <body>
                        <!--% contents %-->
                        <!-- BEGIN box -->

        <div>
                First nested box
        </div>
<!-- END box -->
<!-- BEGIN box -->

        <div>
                Second nested box
        </div>
<!-- END box -->

                </body>
        </html>
<!-- END page -->
';

#my $nest = Template::Nest->new(
#    template_hash => $templates,
#    show_labels => 1,
#    token_delims => ['<!--%','%-->']
#);

$nest.template_hash = %templates;

is( $nest.render( %page ), $expected, "template_hash renders correctly");

done-testing;
