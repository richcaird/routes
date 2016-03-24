#!/usr/bin/perl
use lib "/home/rich/bin/routes";
use lib "/home/rich/perl5/lib/perl5";

use Mojolicious::Lite;
use routeFinder;

use Data::Dumper;
get '/' => \&base;
get '/search' => \&search;

app->start;



sub base {
  my $c=shift;
  $c->render(template => "index");
}

sub search {
  my $c=shift;
  my $rf=routeFinder->new();
  print "go and find some routes\n";
  my $opt=$rf->createRoutes( 
       $c->req->param("depart"),
       $c->req->param("return"),
       "LON",
       $c->req->param("airport"),
       $c->req->param("maxdays"),
       $c->req->param("mindays")
   );

  my $options="Once you've worked out which flight you want, go <a href='http://www.virgin-atlantic.com/en/gb/frequentflyer/spendmiles/upgradeandcompanionflights/index.jsp'>here</a> and look for an upgrade fare";
  my $count=scalar @$opt;
  print Dumper($opt);
  if ($count eq 0) {
    $options="<html><body>What a ridiculous proposition, of course there are no flights</body></html>";
  } else {
     $options="<html><body>";
     foreach my $option (@$opt) {
        $options.="<table border=1>\n";
	$options.= "<tr><td colspan=3></td><td>Premium</td><td>Upper</td></tr>\n";
	$options.="<tr><td>$option->{outbound}->{date} $option->{outbound}->{flightDeparts}</td><td>$option->{outbound}->{from} -> $option->{outbound}->{to}</td><td>$option->{outbound}->{flightNumber}</td><td>$option->{outbound}->{premEconomy_seats}</td><td>$option->{outbound}->{upperclass_seats}</td></tr>\n";
	$options.="<tr><td>$option->{return}->{date} $option->{return}->{flightDeparts}</td><td>$option->{return}->{from} -> $option->{return}->{to}</td><td>$option->{return}->{flightNumber}</td><td>$option->{return}->{premEconomy_seats}</td><td>$option->{return}->{upperclass_seats}</td></tr>\n";
        $options.="</table><br>";
     }
     $options.="</body></html>";
  }
  $c->render(text=>$options);
}

__DATA__

@@ index.html.ep
<html>
<body>
<h1>Super, you made it</h1>
<h3>Remember when all websites looked like this?</h3>
Type your shit in below, the dates need to be in the format dd/mm/yyyy otherwise you'll bring down the entire internet
<hr>
<form action=search>
  <table>  
     <tr><td>Flying to</td><td><input type='text' size=3 maxlength=3 name='airport' value='LAX'></td></tr>
     <tr><td>Depart after</td><td><input type='text' name=depart value='01/05/2016'></td></tr>
     <tr><td>Return before</td><td><input type='text' name=return value='15/05/2016'></td></tr>
     <tr><td>Max days away</td><td><input type='text' name=maxdays value=10></td></tr>
     <tr><td>Min days away</td><td><input type='text' name=mindays value=6></td></tr>
  </table>
  <input type='submit' value='press this to wait ages with no idea if anything is happening'>
</form>
If this doesn't work, this guy explains what you need to do. It's bloody tedious <a href='http://www.haebc.com/2014/05/how-to-upgrade-on-virgin-atlantic/'>here</a>
</body>
</html>
