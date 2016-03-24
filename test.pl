#!/usr/bin/perl

use routeFinder;
use Data::Dumper;

my $rf=routeFinder->new();

  my $opt=$rf->createRoutes( 
      "01/02/2016",
      "03/02/2016",
      "LON",
      "BOS",
      1, #min
      3, #max
   );

 print Dumper($opt);
