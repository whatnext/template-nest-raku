use v6;
use Data::Dump;

class Template::Nest:ver<0.02> {
    has Str $.template_dir is rw;
    has Str $.template_ext is rw = '.html';
    has %.template_hash is rw;
    has %.defaults is rw;

    subset Char of Str where .chars == 1 || .chars == 0;

    has Char $.defaults_namespace_char is rw = '.';

    my @comment_delims_defaults[2] = '<!--', '-->';
    has Str @.comment_delims[2] is rw;

    my @token_delims_defaults[2] = '<%', '%>';
    has Str @.token_delims[2] is rw;

    has Bool $.show_labels is rw = False;
    has Str $.name_label is rw = 'TEMPLATE';
    has Bool $.fixed_indent is rw = False;
    has Bool $.die_on_bad_params is rw = False;
    has Char $.escape_char is rw = '\\';

    submethod TWEAK(){
        self.comment_delims = @comment_delims_defaults unless grep {$_}, @!comment_delims;
        self.token_delims = @token_delims_defaults unless grep {$_}, @!token_delims;
    }

    method render ( $comp ){

        my $html;
        if $comp ~~ Array {
            $html = self!render_array( $comp );
        } elsif $comp ~~ Hash {
            $html = self!render_hash( $comp );
        } else {
    		$html = $comp;
        }

        return $html;
    }


    method !render_hash( %h ){
        #say "render hash: " ~ %h<NAME>;
        my $template_name = %h{ self.name_label };

        die 'Encountered hash with no name_label ("' ~ self.name_label ~ '"): ' ~ Dump( %h ) unless $template_name;

        my %param;

        for %h.keys -> $k {
            next if $k eq self.name_label;
            %param{$k} = self.render( %h{$k} );
        }

        my $template = self!get_template( $template_name );
        my $html = self!fill_in( $template_name, $template, %param );

        if self.show_labels {

            my $ca = self.comment_delims[0];
            my $cb = self.comment_delims[1];

    		$html = "$ca BEGIN $template_name $cb\n$html\n$ca END $template_name $cb\n";
        }

        return $html;

    }


    method !render_array( @arr ){
        #say "render array";
        my $html = '';
        for @arr -> $comp {
            $html ~= self.render( $comp );
        }
        return $html;

    }



    method !get_template( Str $template_name ){
        #say "get template";

        my $template = '';
        if self.template_hash {
            $template = self.template_hash{$template_name};
        } else {

            my $filename = self.template_dir.IO.add(
                $template_name ~ self.template_ext
            );

            $template = slurp $filename;

        }

        $template ~~ s/\n$//;
        return $template;
    }




    method params( $template_name ){
        #say "params";

        my $esc = self.escape_char;
        my $template = self!get_template( $template_name );
        my @frags = $template.split( /$esc$esc/ );
        my $tda = self.token_delims[0];
        my $tdb = self.token_delims[1];

        my %rem;
        for @frags.keys -> $i {
            my @f = @frags[$i] ~~ m:g/<!after $esc> $tda <(.*?)> $tdb/;
            for @f -> $f {
                my Str $elem = $f.Str;
                $elem ~~ s/^\s*//;
                $elem ~~ s/\s*$//;
                %rem{$elem} = True;
            }
        }

        my @params = %rem.keys.sort;
        return @params;
    }



    method !fill_in( Str $template_name, Str $template, %params){

        my Str $esc = self.escape_char;
        my Str @frags;

        if $esc {
            @frags = $template.split( /$esc$esc/ );
        } else {
            @frags = ( $template );
        }

        for %params.keys -> $param_name {
            #say "for params.keys";

            my $param_val = %params{$param_name};

            my Bool $replaced = False;

            if self.fixed_indent { #if fixed_indent we need to add spaces during the replacement
                for @frags.keys -> $i {
                    #say "frags.keys";
                    my Regex $rx = self!token_regex( $param_name );
                    my Match @spaces_repl = @frags[$i] ~~ m:g/(<-[\S\r\n]>*) <$rx>/;

                    while @spaces_repl {
                        #say "spaces_repl: " ~ Dump( @spaces_repl );
                        #say "while";
                        my Match $repl = shift @spaces_repl;
                        my Match $sp = $repl.list[0];

                        my Str $param_out = $param_val;
                        #say "param out before: " ~ $param_out;
                        $param_out ~~ s:g/\n/\n$sp/;
                        $param_out = $sp ~ $param_out;
                        #say "param out after: " ~ $param_out;

                        if $esc {
                            $replaced = True if @frags[$i] ~~ s/<!after $esc> $repl/$param_out/;
                        } else {
                            $replaced = True if @frags[$i] ~~ s/$repl/$param_out/;
                        }
                    }
                }
            } else {
                for @frags.keys -> $i {
                    #say "for ffk";
                    my Regex $rx = self!token_regex( $param_name );
                    #say "regex: " ~ $rx.gist;
                    #say "frag: " ~ @frags[$i];
                    #say "param_val: " ~ $param_val.gist;
                    #say "param_name: " ~ $param_name.Str;
                    #say "m: " ~ $m.gist;
                    $replaced = True if @frags[$i] ~~ s:g/<$rx>/$param_val/;
                    #say "end of ffk";
                }
            }

            if self.die_on_bad_params and not $replaced  {
                die "Could not replace template param '$param_name': token does not exist in template '$template_name'";
            }
        }

        #say "finished for";

        for @frags.keys -> $i {
            #say "for frags keys";

            if self.defaults {
                my Str @rem = self!params_in( @frags[$i] );
                #say "defaults rem: " ~ Dump( @rem );
                my $char = self.defaults_namespace_char;
                #say "namespace char: $char";
                for @rem -> $name {
                    my Str @parts = ( $name );
                    @parts = $name.split($char) if $char;

                    my $val = self!get_default_val( self.defaults, @parts );
                    my $rx = self!token_regex( $name );
                    @frags[$i] ~~ s:g/<$rx>/$val/;
                }
            }

            my Regex $rx = self!token_regex;
            #say "frags regex: " ~ $rx.raku;
            #say "frag: " ~ @frags[$i];
            @frags[$i] ~~ s:g/<$rx>//;
            #say "after frags regex";
        }

        if $esc {
            for @frags.keys -> $i {
                @frags[$i] ~~ s:g/$esc//;
            }
        }

        my $text = $esc ?? @frags.join( $esc ) !! @frags[0];
        return $text;
    }


    method !params_in( Str $text ){

        my Str $esc = self.escape_char;
        my Str $tda = self.token_delims[0];
        my Str $tdb = self.token_delims[1];

        #my @rem;
        my Match @m;
        if $esc {
            @m = $text ~~ m:g/<!after $esc> $tda \s+ <(.*?)> \s+ $tdb/;
            #@rem = grep { $_.chunks[0].keys[0] }, @m;
        } else {
            @m = $text ~~ m:g/$tda \s+ <(.*?)> \s+ $tdb/;
            #@rem = grep { $_.chunks[0].keys[0] }, @m;
        }
        #say "m: " ~ Dump( @m );
        #say "arr rem: " ~ Dump( @rem );

        my Bool %rem;
        for @m -> $name {
            %rem{ $name } = True
        }
        #say "rem: " ~ Dump( %rem );

        return %rem.keys;
    }

    method !get_default_val( %def, Str @parts ){
        #say "get default val";
        #say "parts: " ~ Dump( @parts );
        #say "defaults: " ~ Dump( self.defaults );

        if @parts == 1 {
            my $val = %def{ @parts[0] } || '';
            return $val;
        } else {
            my $ref_name = shift @parts;
            #say "def: " ~ Dump( %def );
            #say "ref_name: $ref_name";
            my $new_def = %def{ $ref_name };
            #say "new def: $new_def";
            my %new_def = %def{ $ref_name };
            #say "new def: " ~ Dump( %new_def );
            return '' unless %new_def;
            return self!get_default_val( %new_def, @parts );
        }
    }

    method !token_regex( Str $param_name? ){
        #say "token regex begins";
        my Str $esc = self.escape_char;
        my Str $tda = self.token_delims[0];
        my Str $tdb = self.token_delims[1];

        my $param_title = $param_name || '.*?';

        #say "tda: $tda";
        #say "tdb: $tdb";
        #say "param_title: $param_title";

        my Regex $token_regex = /$tda \s+ <$param_title> \s+ $tdb/;
        if $esc {
            $token_regex = /<!after $esc> $tda \s+ <$param_title> \s+ $tdb/;
        }
        #say "token regex ends";
        return $token_regex;
    }

}

=begin pod
=head1 NAME

Template::Nest - manipulate a generic template structure via a Raku hash

=head1 SYNOPSIS

	page.html:
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
			<% contents %>
		</body>
	</html>



	box.html:
	<div>
		<% title %>
	</div>


	use Template::Nest;

	my $page = {
		NAME => 'page',
		contents => [{
			NAME => 'box',
			title => 'First nested box'
		}]
	};

	push @{$page->{contents}},{
		NAME => 'box',
		title => 'Second nested box'
	};

	my $nest = Template::Nest->new(
		template_dir => '/html/templates/dir',
        fixed_indent => 1
	);

	print $nest->render( $page );


	# output:

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
            <div>
	            First nested box
            </div>
            <div>
	            Second nested box
            </div>
	    </body>
    </html>

=head1 OVERVIEW

This is a native Raku version of my Perl5 L<Template::Nest> module. This means there are now Perl5, Python3 and Raku versions of L<Template::Nest> so the same templates can be used with any of the 3 languages. (If e.g. you were upgrading a Perl5 project that used L<Template::Nest> there would be no overhead converting templates since you could use exactly the same ones.)

At the time of writing there is currently very little difference between (latest) versions - they include (almost) the same methods which have near-identical functionality. Again I did this primarily for my own benefit; I have Perl5 and Python projects which use a certain set of templates, and I plan to keep using them now I am moving into Raku. To me, this is the only templating philosophy that makes any sense.

The usage instructions below are adapted from the original Perl5 documentation.

=head2 DESCRIPTION

There are a wide number of templating options out there, and many are far more longstanding than L<Template::Nest>. However, his module takes a different approach to many other systems, and in the author's opinion this results in a better separation of "control" from "view".

The philosophy behind this module is simple: don't allow any processing of any kind in the template. Treat templates as dumb pieces of text which only have holes to be filled in. No template loops, no template ifs etc. Regard ifs and loops as control processing, which should be in your main code and not in your templates.

=head1 AN EXAMPLE

Lets say you have a template for a letter (if you can remember what that is!), and a template for an address. Using L<HTML::Template> you might do something like this:

    # in letter.html

    <TMPL_INCLUDE NAME="address.html">

    Dear <TMPL_VAR NAME=username>

    ....


However, in L<Template::Nest> there's no such thing as a C<TMPL_INCLUDE>, there are only tokens to fill in, so you would have

    # letter.html:

    <% address %>

    Dear <% username %>

    ...


I specify that I want to use C<address.html> when I fill out the template, thus:

    my %letter =
        NAME => 'letter',
        username => 'billy',
        address => {
            NAME => 'address', # this specifies "address.html"
                               # provided template_ext=".html"

            # variables in 'address.html'
        };

    $nest.render( $letter );

This is much better, because now C<letter.html> is not hard-coded to use C<address.html>. You can decide to use a different address template without needing to change the letter template.

Commonly used template structures can be labelled (C<main_page> etc.) stored in your code in subs, hashes, Moose attributes or whatever method seems the most convenient.

=head2 Another example

=begin code

    # table.html:

    <table>
        <tr>
            <th>Name</th><th>Job</th>
        </tr>

        <!--% rows %-->

    </table>


    # table_row.html:

    <tr>
        <td><!--% name %--></td>
        <td><!--% job %--></td>
    </tr>


    # and in the Raku:

    my %table =
        NAME => 'table',
        rows => [{
            NAME => 'table_row',
            name => 'Sam',
            job => 'programmer'
        }, {
            NAME => 'table_row',
            name => 'Steve',
            job => 'soda jerk'
        }];

    my $nest = Template::Nest.new(
        token_delims => ['<!--%','%-->']
    );

    say $nest.render( $table );

To fill this in:

    my @rows;

    for @data -> $item {

        @rows.push: {
            NAME => 'table_row',
            name => $item->name,
            job => $item->job
        };

    }

    my %table =
        NAME => 'table',
        rows => $rows;

    my $nest = Template::Nest.new(
        token_delims => ['<!--%','%-->']
    );

    say $nest.render( %table );

=end code


=head1 METHODS


=head2 comment_delims

Use this in conjunction with show_labels. Get/set the delimiters used to define comment labels. Expects a 2 element arrayref. E.g. if you were templating javascript you could do:

    $nest.comment_delims = '/*', '*/';

Now your output will have labels like

    /* BEGIN my_js_file */
    ...
    /* END my_js_file */


You can set the second comment token as an empty string if the language you are templating does not use one. E.g. for Raku:

    $nest.comment_delims = '#','';


=head2 defaults

Provide a hashref of default values to have L<Template::Nest> auto-fill matching parameters (no matter where they are found in the template tree). For example:

    my $nest = Template::Nest.new(
        token_delims => ['<!--%','%-->']
    });

    # box.html:
    <div class='box'>
        <!--% contents %-->
    </div>

    # link.html:
    <a href="<--% soup_website_url %-->">Soup of the day is <!--% todays_soup %--> !</a>

    my %page =
        NAME => 'box',
        contents => {
            NAME => 'link',
            todays_soup => 'French Onion Soup'
        };


    # prints:

    <div class='box'>
        <a href="">Soup of the day is French Onion Soup !</a>
    </div>

    # Note the blank "href" value - because we didn't pass it as a default, or specify it explicitly
    # Now lets set some defaults:

    $nest.defaults =
        soup_website_url => 'http://www.example.com/soup-addicts',
        some_other_url => 'http://www.example.com/some-other-url'; #any default that doesn't appear
                                                                   #in any template is simply ignored

    $html = $nest.render( $page );

    # this time "href" is populated:

    <div class='box'>
        <a href="http://www.example.com/soup-addicts">Soup of the day is French Onion Soup</a>
    </div>

    # Alternatively provide the value explicitly and override the default:

    $page =
        NAME => 'box',
        contents => {
            NAME => 'link',
            todays_soup => 'French Onion Soup',
            soup_website_url => 'http://www.example.com/soup-url-override'
        };

    $html = $nest.render( $html );

    # result:

    <div class='box'>
        <a href='http://www.example.com/soup-url-override'
    </div>

ie. C<defaults> allows you to preload your C<$nest> with any values which you expect to remain constant throughout your project.



You can also B<namespace> your default values. Say you think it's a better idea to differentiate parameters coming from config from those you are expecting to explicitly pass in. You can do something like this:

    # link.html:
    <a href="<--% config.soup_website_url %-->">Soup of the day is <!--% todays_soup %--> !</a>

ie you are reserving the C<config.> prefix for parameters you are expecting to come from the config. To set the defaults in this case you could do this:

    my %defaults =
        'config.soup_website_url' => 'http://www.example.com/soup-addicts',
        'config.some_other_url' => 'http://www.example.com/some-other-url',
        #...
    ;


    $nest.defaults = %defaults;

but writing 'config.' repeatedly is a bit effortful, so L<Template::Nest> allows you to do the following:

    my %defaults =

        config => {

            soup_website_url => 'http://www.example.com/soup-addicts',
            some_other_url => 'http://www.example.com/some-other-url'

            #...
        },

        some_other_namespace => {

            # other params?

        };


    $nest.defaults = %defaults;
    $nest.defaults_namespace_char = '.'; # not actually necessary, as '.' is the default

    # Now L<Template::Nest> will replace C<config.soup_website_url> with what
    # it finds in

    %defaults{config}{soup_website_url}

See L<defaults_namespace_char>.


=head2 defaults_namespace_char

Allows you to provide a "namespaced" defaults hash rather than just a flat one. ie instead of doing this:

    $nest.defaults =
        variable1 => 'value1',
        variable2 => 'value2',

        # ...
    ;

You can do this:

    $nest.defaults =
        namespace1 => {
            variable1 => 'value1',
            variable2 => 'value2'
        },

        namespace2 => {
            variable1 => 'value3',
            variable2 => 'value4
        };

Specify your C<defaults_namespace_char> to tell L<Template::Nest> how to match these defaults in your template:

    $nest.defaults_namespace_char = '-';

so now the token

    <% namespace1-variable1 %>

will be replaced with C<value2>. Note the default C<defaults_namespace_char> is a fullstop (period) character.


=head2 die_on_bad_params

The name of this method is stolen from L<HTML::Template>, because it basically does the same thing. If you attempt to populate a template with a parameter that doesn't exist (ie the name is not found in the template) then this normally results in an error. This default behaviour is recommended in most circumstances as it guards against typos and sloppy code. However, there may be circumstances where you want processing to carry on regardless. In this case set C<die_on_bad_params> to C<False>:

    $nest.die_on_bad_params = False;


=head2 escape_char

On rare occasions you may actually want to use the exact character string you are using for your token delimiters in one of your templates. e.g. say you are using token_delims C<[%> and C<%]>, and you have this in your template:

    Hello [% name %],

        did you know we are using token delimiters [% and %] in our templates?

    lots of love
    Roger

Clearly in this case we are a bit stuck because L<Template::Nest> is going to think C<[% and %]> is a token to be replaced. Not to worry, we can I<escape> the opening token delimiter:

    Hello [% name %],

        did you know we are using token delimiters \[% and %] in our templates?

    lots of love
    Roger

In the output the backslash will be removed, and the C<[% and %]> will get printed verbatim.

C<escape_char> is set to be a backslash by default. This means if you want an actual backslash to be printed, you would need a double backslash in your template.

You can change the escape character if necessary:

    $nest->escape_char('X');

or you can turn it off completely if you are confident you'll never want to escape anything. Do so by passing in the empty string to C<escape_char>:

    $nest.escape_char = '';


=head2 fixed_indent

Intended to improve readability when inspecting nested templates. Consider the following example:

    my $nest = Template::Nest.new(
        token_delims => ['<!--%','%-->']
    });

    # box.html
    <div class='box'>
        <!--% contents %-->
    </div>

    # photo.html
    <div>
        <img src='/some_image.jpg'>
    </div>

    $nest.render({
        NAME => 'box',
        contents => 'image'
    });

    # Output:

    <div class='box'>
        <div>
        <img src='/some_image.jpg'>
    </div>
    </div>

Note the ugly indenting. In fact this is completely correct behaviour in terms of faithfully replacing the token

    <!--% contents %-->

with the C<photo.html> template - the nested template starts exactly from where the token was placed, and each character is printed verbatim, including the new lines.

However, a lot of the time we really want output that looks like this:

    <div class='box'>
        <div>
            <image src='/some_image.jpg'>  # the indent is maintained
        </div>                             # for every line in the child
    </div>                                 # template

To get this more readable output, then set C<fixed_indent> to C<True>:

    $nest.fixed_indent = True;

Bear in mind that this will result in extra space characters being inserted into the output.



=head2 name_label

The default is NAME (all-caps, case-sensitive). Of course if NAME is interpreted as the filename of the template, then you can't use NAME as one of the variables in your template. ie

    <% NAME %>

will never get populated. If you really are adamant about needing to have a template variable called 'NAME' - or you have some other reason for wanting an alternative label point to your template filename, then you can set name_label:

    $nest.name_label( 'GOOSE' );

    #and now

    my $component =
        GOOSE => 'name_of_my_component'
        # ...
    ;



=head2 new

constructor for a Template::Nest object.

    my $nest = Template::Nest.new( %opts );

%opts can contain any of the methods Template::Nest accepts. For example you can do:

    my $nest = Template::Nest->new( template_dir => '/my/template/dir' );

or equally:

    my $nest = Template::Nest.new();
    $nest.template_dir = '/my/template/dir';



=head2 render

Convert a template structure to output text. Expects a hashref containing hashrefs/arrayrefs/plain text.

e.g.

    widget.html:
    <div class='widget'>
        <h4>I am a widget</h4>
        <div>
            <!-- TMPL_VAR NAME=widget_body -->
        </div>
    </div>


    widget_body.html:
    <div>
        <div>I am the widget body!</div>
        <div><!-- TMPL_VAR NAME=some_widget_property --></div>
    </div>


    my $widget = {
        NAME => 'widget',
        widget_body => {
            NAME => 'widget_body',
            some_widget_property => 'Totally useless widget'
        }
    };


    print $nest.render( $widget );


    #output:
    <div class='widget'>
        <h4>I am a widget</h4>
        <div>
            <div>
                <div>I am the widget body!</div>
                <div>Totally useless widget</div>
            </div>
        </div>
    </div>



=head2 show_labels

Get/set the show_labels property. This is a boolean with default C<False>. Setting this to C<True> results in adding comments to the output so you can identify which template output text came from. This is useful in development when you have many templates. E.g. adding

    $nest.show_labels = True;

to the example in the synopsis results in the following:

    <!-- BEGIN page -->
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

What if you're not templating html, and you still want labels? Then you should set L<comment_delims> to whatever is appropriate for the thing you are templating.



=head2 template_dir

Get/set the dir where L<Template::Nest> looks for your templates. E.g.

    $nest.template_dir = '/my/template/dir';

Now if I have

    my %component =
        NAME => 'hello',
        # ...

and template_ext = '.html', we'll expect to find the template at

    /my/template/dir/hello.html


Note that if you have some kind of directory structure for your templates (ie they are not all in the same directory), you can do something like this:

    my %component =
        NAME => '/my/component/location',
        contents => 'some contents or other'
        # ...
        ;

L<Template::Nest> will then prepend NAME with template_dir, append template_ext and look in that location for the file. So in our example if C<template_dir = '/my/template/dir'> and C<template_ext = '.html'> then the template file will be expected to exist at

 /my/template/dir/my/component/location.html


Of course if you want components to be nested arbitrarily, it might not make sense to contain them in a prescriptive directory structure.


=head2 template_ext

Get/set the template extension. This is so you can save typing your template extension all the time if it's always the same. The default is '.html' - however, there is no reason why this templating system could not be used to construct any other type of file (or why you could not use another extension even if you were producing html). So e.g. if you are wanting to manipulate javascript files:

    $nest.template_ext = '.js';

then

    my %js_file =
        NAME => 'some_js_file'
        # ...
        ;

So here HTML::Template::Nest will look in template_dir for

some_js_file.js


If you don't want to specify a particular template_ext (presumably because files don't all have the same extension) - then you can do

    $nest.template_ext('');

In this case you would need to have NAME point to the full filename. ie

    $nest.template_ext('');

    my $component =
        NAME => 'hello.html',
        # ...
    ;


=head2 token_delims

Get/set the delimiters that define a token (to be replaced). token_delims is a 2 element arrayref - corresponding to the opening and closing delimiters. For example

    $nest.token_delims = '[%', '%]';

would mean that L<Template::Nest> would now recognise and interpolate tokens in the format

    [% token_name %]

The default token_delims are the mason style delimiters C<&lt;%> and C<%&gt;>. Note that for C<HTML> the token delimiters C<&lt;!--%> and C<%--&gt;> make a lot of sense, since they allow raw templates (ie that have not had values filled in) to render as good C<HTML>.


=head1 AUTHOR

Tom Gracey tomgracey@gmail.com

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2021 by Tom Gracey

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.20.1 or,
at your option, any later version of Perl 5 you may have available.

=cut

=end pod
