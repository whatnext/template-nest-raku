use v6;
use lib '../lib';

use Test;
use Template::Nest;
use Data::Dump;

use-ok('Template::Nest');

my $template_dir = $*PROGRAM.IO.parent.add('templates').resolve.Str;


my $nest = Template::Nest.new( template_dir => $template_dir );
ok( $nest, "new");

say "nest: " ~ Dump( $nest );

say "template_dir: " ~ $nest.template_dir;

for qw[
    new
    template_dir
    template_hash
    token_delims
    comment_delims
    show_labels
    template_ext
    name_label
    render
    defaults
    defaults_namespace_char
    fixed_indent
    die_on_bad_params
    escape_char
] -> $method {
    can-ok( $nest, $method, "can $method" );
}


#delim type fields
for <comment token> -> $type {
    my $method = $type ~ '_delims';
    say "method: $method";
    my @delims = $nest."$method"();
    test_delims(@delims,$type,'default');
    @delims = $nest."$method"() = "(", ")";
    test_delims(@delims,$method,'set');
    is( @delims[0], "(", "first set $method" );
    is( @delims[1], ")", "second set $method" );
}


# booleans
for <fixed_indent show_labels die_on_bad_params> -> $method {
    $nest."$method"() = True;
    is( $nest."$method"(), True, "set $method" );
    $nest."$method"() = False;
    is( $nest."$method"(), False, "unset $method" );
    try { $nest."$method"(2) };
    ok( $!, "Non-boolean error");
}


# 1 char fields
for <defaults_namespace_char escape_char> -> $method {
    $nest."$method"() = '';
    is( $nest."$method"(), '', "$method: set as empty string");
    $nest."$method"() = 'A';
    is( $nest."$method"(), 'A', "$method: set as single char");
    try { $nest."$method"() = 'AB'; };
    ok( $!, "$method: Non-single char error" );
}



for <template_hash defaults> -> $method {
    $nest."$method"() = param1 => 'val1';

    is( $nest."$method"().WHAT, Hash, "$method returns a hash");
    is( $nest."$method"()<param1>, 'val1', "$method sets correctly");
}


for <name_label template_ext template_dir> -> $method {
    my $default_value = $nest."$method"();
    test_scalar( $method,'default',$default_value );
    $nest."$method"() = 'HELLO';
    my $set_value = $nest."$method"();
    test_scalar( $method,'set',$set_value );
    is($set_value,'HELLO',"set $method");
}

done-testing;


sub test_delims( @delims, $type, $mode ){

    my $method = $type ~ '_delims';
    ok( @delims, "$mode $type is defined");
    is( @delims.elems, 2, "$mode $type has 2 values" );
    is( @delims[0].WHAT, Str, "first $mode $type is a Str" );
    is( @delims[1].WHAT, Str, "second $mode $type is a scalar" );

}

sub test_scalar( $method, $type, $value ){

    ok( $value, "$type $method is defined" );
    is( $value.WHAT, Str, "$type $method is a Str");

}
