NAME
====

Template::Nest - manipulate a generic template structure via a Raku hash

SYNOPSIS
========

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

OVERVIEW
========

This is a native Raku version of my Perl5 [Template::Nest](Template::Nest) module. This means there are now Perl5, Python3 and Raku versions of [Template::Nest](Template::Nest) so the same templates can be used with any of the 3 languages. (If e.g. you were upgrading a Perl5 project that used [Template::Nest](Template::Nest) there would be no overhead converting templates since you could use exactly the same ones.)

At the time of writing there is currently very little difference between (latest) versions - they include (almost) the same methods which have near-identical functionality. Again I did this primarily for my own benefit; I have Perl5 and Python projects which use a certain set of templates, and I plan to keep using them now I am moving into Raku. To me, this is the only templating philosophy that makes any sense.

The usage instructions below are adapted from the original Perl5 documentation.

DESCRIPTION
-----------

There are a wide number of templating options out there, and many are far more longstanding than [Template::Nest](Template::Nest). However, his module takes a different approach to many other systems, and in the author's opinion this results in a better separation of "control" from "view".

The philosophy behind this module is simple: don't allow any processing of any kind in the template. Treat templates as dumb pieces of text which only have holes to be filled in. No template loops, no template ifs etc. Regard ifs and loops as control processing, which should be in your main code and not in your templates.

AN EXAMPLE
==========

Lets say you have a template for a letter (if you can remember what that is!), and a template for an address. Using [HTML::Template](HTML::Template) you might do something like this:

    # in letter.html

    <TMPL_INCLUDE NAME="address.html">

    Dear <TMPL_VAR NAME=username>

    ....

However, in [Template::Nest](Template::Nest) there's no such thing as a `TMPL_INCLUDE`, there are only tokens to fill in, so you would have

    # letter.html:

    <% address %>

    Dear <% username %>

    ...

I specify that I want to use `address.html` when I fill out the template, thus:

    my %letter =
        NAME => 'letter',
        username => 'billy',
        address => {
            NAME => 'address', # this specifies "address.html"
                               # provided template_ext=".html"

            # variables in 'address.html'
        };

    $nest.render( $letter );

This is much better, because now `letter.html` is not hard-coded to use `address.html`. You can decide to use a different address template without needing to change the letter template.

Commonly used template structures can be labelled (`main_page` etc.) stored in your code in subs, hashes, Moose attributes or whatever method seems the most convenient.

Another example
---------------

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

METHODS
=======

comment_delims
--------------

Use this in conjunction with show_labels. Get/set the delimiters used to define comment labels. Expects a 2 element arrayref. E.g. if you were templating javascript you could do:

    $nest.comment_delims = '/*', '*/';

Now your output will have labels like

    /* BEGIN my_js_file */
    ...
    /* END my_js_file */

You can set the second comment token as an empty string if the language you are templating does not use one. E.g. for Raku:

    $nest.comment_delims = '#','';

defaults
--------

Provide a hashref of default values to have [Template::Nest](Template::Nest) auto-fill matching parameters (no matter where they are found in the template tree). For example:

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

ie. `defaults` allows you to preload your `$nest` with any values which you expect to remain constant throughout your project.

You can also **namespace** your default values. Say you think it's a better idea to differentiate parameters coming from config from those you are expecting to explicitly pass in. You can do something like this:

    # link.html:
    <a href="<--% config.soup_website_url %-->">Soup of the day is <!--% todays_soup %--> !</a>

ie you are reserving the `config.` prefix for parameters you are expecting to come from the config. To set the defaults in this case you could do this:

    my %defaults =
        'config.soup_website_url' => 'http://www.example.com/soup-addicts',
        'config.some_other_url' => 'http://www.example.com/some-other-url',
        #...
    ;


    $nest.defaults = %defaults;

but writing 'config.' repeatedly is a bit effortful, so [Template::Nest](Template::Nest) allows you to do the following:

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

See [defaults_namespace_char](defaults_namespace_char).

defaults_namespace_char
-----------------------

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

Specify your `defaults_namespace_char` to tell [Template::Nest](Template::Nest) how to match these defaults in your template:

    $nest.defaults_namespace_char = '-';

so now the token

    <% namespace1-variable1 %>

will be replaced with `value2`. Note the default `defaults_namespace_char` is a fullstop (period) character.

die_on_bad_params
-----------------

The name of this method is stolen from [HTML::Template](HTML::Template), because it basically does the same thing. If you attempt to populate a template with a parameter that doesn't exist (ie the name is not found in the template) then this normally results in an error. This default behaviour is recommended in most circumstances as it guards against typos and sloppy code. However, there may be circumstances where you want processing to carry on regardless. In this case set `die_on_bad_params` to `False`:

    $nest.die_on_bad_params = False;

escape_char
-----------

On rare occasions you may actually want to use the exact character string you are using for your token delimiters in one of your templates. e.g. say you are using token_delims `[%` and `%]`, and you have this in your template:

    Hello [% name %],

        did you know we are using token delimiters [% and %] in our templates?

    lots of love
    Roger

Clearly in this case we are a bit stuck because [Template::Nest](Template::Nest) is going to think `[% and %]` is a token to be replaced. Not to worry, we can *escape* the opening token delimiter:

    Hello [% name %],

        did you know we are using token delimiters \[% and %] in our templates?

    lots of love
    Roger

In the output the backslash will be removed, and the `[% and %]` will get printed verbatim.

`escape_char` is set to be a backslash by default. This means if you want an actual backslash to be printed, you would need a double backslash in your template.

You can change the escape character if necessary:

    $nest->escape_char('X');

or you can turn it off completely if you are confident you'll never want to escape anything. Do so by passing in the empty string to `escape_char`:

    $nest.escape_char = '';

fixed_indent
------------

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

with the `photo.html` template - the nested template starts exactly from where the token was placed, and each character is printed verbatim, including the new lines.

However, a lot of the time we really want output that looks like this:

    <div class='box'>
        <div>
            <image src='/some_image.jpg'>  # the indent is maintained
        </div>                             # for every line in the child
    </div>                                 # template

To get this more readable output, then set `fixed_indent` to `True`:

    $nest.fixed_indent = True;

Bear in mind that this will result in extra space characters being inserted into the output.

name_label
----------

The default is NAME (all-caps, case-sensitive). Of course if NAME is interpreted as the filename of the template, then you can't use NAME as one of the variables in your template. ie

    <% NAME %>

will never get populated. If you really are adamant about needing to have a template variable called 'NAME' - or you have some other reason for wanting an alternative label point to your template filename, then you can set name_label:

    $nest.name_label( 'GOOSE' );

    #and now

    my $component =
        GOOSE => 'name_of_my_component'
        # ...
    ;

new
---

constructor for a Template::Nest object.

    my $nest = Template::Nest.new( %opts );

%opts can contain any of the methods Template::Nest accepts. For example you can do:

    my $nest = Template::Nest->new( template_dir => '/my/template/dir' );

or equally:

    my $nest = Template::Nest.new();
    $nest.template_dir = '/my/template/dir';

render
------

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

show_labels
-----------

Get/set the show_labels property. This is a boolean with default `False`. Setting this to `True` results in adding comments to the output so you can identify which template output text came from. This is useful in development when you have many templates. E.g. adding

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

What if you're not templating html, and you still want labels? Then you should set [comment_delims](comment_delims) to whatever is appropriate for the thing you are templating.

template_dir
------------

Get/set the dir where [Template::Nest](Template::Nest) looks for your templates. E.g.

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

[Template::Nest](Template::Nest) will then prepend NAME with template_dir, append template_ext and look in that location for the file. So in our example if `template_dir = '/my/template/dir'` and `template_ext = '.html'` then the template file will be expected to exist at

    /my/template/dir/my/component/location.html

Of course if you want components to be nested arbitrarily, it might not make sense to contain them in a prescriptive directory structure.

template_ext
------------

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

token_delims
------------

Get/set the delimiters that define a token (to be replaced). token_delims is a 2 element arrayref - corresponding to the opening and closing delimiters. For example

    $nest.token_delims = '[%', '%]';

would mean that [Template::Nest](Template::Nest) would now recognise and interpolate tokens in the format

    [% token_name %]

The default token_delims are the mason style delimiters `&lt;%` and `%&gt;`. Note that for `HTML` the token delimiters `&lt;!--%` and `%--&gt;` make a lot of sense, since they allow raw templates (ie that have not had values filled in) to render as good `HTML`.

AUTHOR
======

Tom Gracey tomgracey@gmail.com

COPYRIGHT AND LICENSE
=====================

Copyright (C) 2021 by Tom Gracey

This library is free software; you can redistribute it and/or modify it under the same terms as Perl itself, either Perl version 5.20.1 or, at your option, any later version of Perl 5 you may have available.

cut
===



