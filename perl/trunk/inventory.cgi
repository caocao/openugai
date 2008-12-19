#!/usr/bin/perl -w

use strict;
use MyCGI;
use OpenUGAI::InventoryServer;
use OpenUGAI::Util;
use Carp;
require "config.pl";

my $request_uri = $ENV{REQUEST_URI} || Carp::croak("You must have been eaten by a wolf.");
my $request_method = "";
if ($request_uri =~ /([^\/]+)\/$/) {
    $request_method = $1;
} else {
    &MyCGI::outputXml("utf-8", "You must have been eaten by a wolf.");
}

my $param = &MyCGI::getParam();
my $post_data = $param->{'POSTDATA'};
my $response = "";
eval {
    $response = &OpenUGAI::InventoryServer::DispatchRestHandler($request_method, $post_data);
};
if ($@) {
    $response = "<ERROR>$@</ERROR>"; # TODO @@@ need a better error response
}
&MyCGI::outputXml("utf-8", $response);


