package routeFinder;
require Exporter;
@ISA = qw(Exporter);

@EXPORT_OK=qw(createRoutes getFlights);

my $cache="/var/tmp/flights.bin";

use Data::Dumper;
use DateTime;

my @savefields=qw(from to date flightDeparts flightArrives flightNumber upperclass_seats premEconomy_seats data_age);

sub new {
  my $self = bless {}, shift;
  $self->loadFlights(); 
  return $self;
}

sub addFlight {
   my ($self,$flight)=@_;
   my $key=getflightkey($flight);
   print "adding flight with key:$key\n";
   if ($self->{flights}->{$key}) {
      print "we aleady had this flight\n";
   }
   $self->{flights}->{$key}=$flight;
   $self->saveFlights();
}

sub loadEnriched {
   my @flights;
   #open (MYFILE, '/home/rich/bin/routes/enrichedflights.csv');
   open (MYFILE,$cache);
   my $count=0;
   while (<MYFILE>) {
      chomp;
      if ($count eq 0) {$count++; next;}
      my %flight;
      $flight{raw}=$_;
      ($flight{from},$flight{to},$flight{d},$flight{depart},$flight{arrive},$flight{flightno},$flight{upperseats},$flight{premEconomy})=split(",",$_);
      $flight{from_country}=($flight{from} eq "LON") ? "GB" : "US";
      $flight{to_country}=($flight{to} eq "LON") ? "GB" : "US";
      my ($day,$month,$year)=split("/",$flight{d});
      my ($hour,$min)=split(":",$flight{depart});
      $flight{date}=DateTime->new(year=>$year,month=>$month,day=>$day,hour=>$hour,minute=>$min);
      push (@flights,\%flight);
      $count++;
   }
   close (MYFILE);
   return \@flights;
}

sub getflightkey {
  my ($flight)=@_;
  return $flight->{from} . ":" . $flight->{to} . ":" . $flight->{date};
}

sub getDateTime {
  my ($flight)=@_;
  my ($day,$month,$year)=split("/",$flight->{date});
  my ($hour,$min)=(0,0) ;
  if ($flight->{flightDeparts}) {
     ($hour,$min)=split(":",$flight->{flightDeparts});
  }
  return DateTime->new(year=>$year,month=>$month,day=>$day,hour=>$hour,minute=>$min);
}

sub loadFlights {
   my ($self)=@_;
   print "loading flight data from $cache\n";
   open (FILE,"<$cache") ;
   my %flights;
   while (<FILE>) {
      chomp;
      my @data=split(",",$_);
      my $cc=0;
      my %flight;
      foreach my $field (@savefields) {
        $flight{$field}=$data[$cc];
        $cc++;
      }
      my $key=getflightkey(\%flight);
      $flight{datetime}=getDateTime(\%flight);
      $flights{$key}=\%flight;
   } 
   $self->{flights}=\%flights;
}

sub saveFlights {
  my ($self)=@_;
  print "write files to cache\n";
  open (FILE,">$cache") ;
  foreach my $fkey (keys %{$self->{flights}}) {
    my $f=$self->{flights}->{$fkey};
    my $line;
    foreach my $field (@savefields) {
       $line.=$f->{$field} . ",";
    }
    chop $line;
    print FILE $line . "\n";
  } 
  close FILE;
}

sub flightEnricher {
  my ($self,$from,$to,$date,$reqclass)=@_;
  print "grabbing data from virgin website for $from, $to, $date, $reqclass\n";
  my $sdate=$date;
  $sdate=~s/\/201/\/1/g;
  #date format: 19/02/15
  my $cmd="/usr/bin/wget -q --header=\"User-Agent: Mozilla/5.0 (Windows NT 6.0) AppleWebKit/537.11 (KHTML, like Gecko) Chrome/23.0.1271.97 Safari/537.11\" --header=\"Referer: http://google.com/\"  -O - \"http://www.virgin-atlantic.com/gb/en/book-your-travel/book-your-flight/flight-search-results.html?departure=$from&arrival=$to&adult=2&departureDate=$sdate&search_type=redeemMiles&classType=2&classTypeReturn=2&bookingPanelLocation=BookYourFlight&isreturn=no\"";
  my $data=`$cmd`;
  $data=~s/\n//g;
  my @chunks=split("class=\"departs",$data);
  my @classFields=qw(flightDeparts flightArrives flightDuration flightNumber);
  my @classes=qw(economy premEconomy upperclass);
  my @flights;
  foreach my $chunk (@chunks) {
     my %flight=(
        from=>$from,
        to=>$to,
        date=>$date, 
        dataage=>time,
     );
     foreach my $field (@classFields) {
       ($flight{$field})=$chunk=~/$field\">([^>]*)</;       
       $flight{$field}=~s/&nbsp/\s/g;
     }
     my @subchunks=split("cellOption",$chunk);      
     foreach my $schunk (@subchunks) {
        foreach my $class (@classes) {
	   my ($seats,$price)=$schunk=~/$class.*data-seats=\"(\d*)\".*price\">(.*)<span class=\"postit\">Per Adult/;
           $price =~ s/^\s+|\s+$//g;
           if (length($price)>5) {
              my $id;
              $id=$class . "_seats";
              $flight{$id}=$seats;
              $id=$class ."_price";
              $flight{$id}=$price;
           }
        }
     }
     $flight{datetime}=getDateTime(\%flight);
     $flight{premEconomy_seats} =0 if (!$flight{premEconomy_seats});
     $flight{upperclass_seats}  =0 if (!$flight{upperclass_seats});
     $flight{data_age}=time;
     push(@flights,\%flight);
     $self->addFlight(\%flight);
  }
  print "flight data from enricher\n";
  print Dumper(\@flights);
  return \@flights;
}


sub getwith {
  my ($flights,$criteria,$value)=@_;
  print "get flights with $criteria=$value\n";
  my @ret;
  foreach my $flight (@$flights) {
     if ($flight->{$criteria} eq $value) {
        print "match\n";
        push (@ret,$flight);
     }
  }
  return \@ret;
}

sub dateFromString {
  my ($string)=@_; 
  my ($day,$month,$year)=split("/",$string);
  my $date=DateTime->new(year=>$year,month=>$month,day=>$day);
  return $date;
}

sub createDays {
  my ($f,$t)=@_;
  my $from=dateFromString($f);
  my $runner=$from->clone();
  my $to=dateFromString($t);
  my @dates;
  while ($runner->epoch()<=$to->epoch()) {
   my %obj;
    my $date=sprintf("%02d/%02d/%04d",$runner->day(),$runner->month(),$runner->year());
     $obj{date}=$date;
     $obj{dateobj}=$runner->clone();
     push (@dates,\%obj);
     $runner->add(days=>1); 
  } 
  return \@dates;
}

sub createFlightDays {
  my ($fromDate,$toDate,$fromLoc,$toLoc)=@_;
  print "build date objects for the dates you've given (from:$fromDate to:$toDate)\n";
  my $days=createDays($fromDate,$toDate);
  my @flightdays;
  foreach my $day (@$days) {
     my %fd=(
        from=>$fromLoc, 
        to=>$toLoc,
        date=>$day->{date},
        dateobj=>$day->{dateobj},
     ); 
     $fd{from_country}=($flight{from} eq "LON") ? "GB" : "US";
     $fd{to_country}=($flight{to} eq "LON") ? "GB" : "US";
     push(@flightdays,\%fd);
  }
  return \@flightdays;
}

sub getwith {
  my ($flights,$criteria,$value)=@_;
  my @ret;
  foreach my $flight (@$flights) {
     if ($flight->{$criteria} eq $value) {
        push (@ret,$flight);
     }
  }
  return \@ret;
}

sub getFlights {
  my ($self,$start,$end,$from,$to)=@_;
  my $flightdays=createFlightDays($start,$end,$from,$to); #"01/02/2016","10/03/2016","LON","BOS");
  my $cache;
  foreach my $flightday (@$flightdays) {
     my $flightkey=getflightkey($flightday); 
     print "look for data for $flightkey\n";
     if ($self->{flights}->{$flightkey} ){
         my $age=time-$self->{flights}->{$flightkey}->{data_age};
         print "already have data for this flight (key:$flightkey), age is $age\n";
         my $hour=60*60;
         if ($age>$hour) { 
            print "too old, find new data\n";
	    $self->flightEnricher($flightday->{from},$flightday->{to},$flightday->{date});
         }
      } else {
         print "no data, look up from web\n";
         $self->flightEnricher($flightday->{from},$flightday->{to},$flightday->{date});
      }
  }
}

sub getBetween {
  my ($self,$from,$to)=@_;
  my @ret;
  foreach my $fkey (keys %{$self->{flights}}) {
     my $f=$self->{flights}->{$fkey};
     if ($f->{to} eq $to && $f->{from} eq $from) {
        push(@ret,$f);
     }
  }
  return \@ret;
}

sub dt {
  my ($date)=@_;
  my ($day,$month,$year)=split("/",$date);
  my ($hour,$min)=(0,0);   
  my $dt=DateTime->new(year=>$year,month=>$month,day=>$day,hour=>$hour,minute=>$min);
  return $dt->epoch();
}

sub dayMath {
  my ($date,$days)=@_;
  my ($day,$month,$year)=split("/",$date);
  my $dt=DateTime->new(year=>$year,month=>$month,day=>$day,hour=>0,minute=>0);
  $dt->add(days=>$days); 
  my $date=sprintf("%02d/%02d/%04d",$dt->day(),$dt->month(),$dt->year());
  return $date;
}

sub createRoutes {
  my ($self,$start,$end,$from,$to,$maxdays,$mindays)=@_;
  print "finding routes between $start and $end from $from to $to\n";
  #earliest return date is start +min
  my $earliestreturn=dayMath($start,$mindays);
  #latest go date is end -max
  my $latestdepart=dayMath($end,-$max);
  #print "actually get outbound up to $ and return after $newret\n";

  $self->getFlights($start,$end,$from,$to);
  $self->getFlights($start,$end,$to,$from);
  my $outbound=$self->getBetween($from,$to);
  my $return=$self->getBetween($to,$from);
  my $daylength=60*60*24;
  my @options;
  foreach my $outbound (@$outbound) {
      next if $outbound->{datetime}->epoch<dt($start);
      next if $outbound->{datetime}->epoch>dt($end);
      next if $outbound->{upperclass_seats} eq 0 && $outbound->{premEconomy_seats} eq 0;
      print "looking at $outbound->{flightNumber} on $outbound->{date}\n";
      foreach my $return (@$return) {
         next if $return->{datetime}<$outbound->{datetime};
	 next if $return->{datetime}->epoch<dt($start);
	 next if $return->{datetime}->epoch>dt($end);
         next if $return->{upperclass_seats} eq 0 && $return->{premEconomy_seats} eq 0;
         print "   pairing with $return->{flightNumber} on $return->{date}\n";
         my %option;
         my $days=$return->{datetime}->epoch()-$outbound->{datetime}->epoch();
         $days=$days/$daylength;
         print "   duration of this round trip is $days\n";
         print "   too long $days>$maxdays\n" if $days>$maxdays;
         print "   too short $days<$mindays\n" if $days<$mindays;
         next if ($days>$maxdays);
         next if ($days<$mindays);
         print "right duration\n";
         #if ($retmin && $retmax) {
            %option=(outbound=>$outbound,
                     return=>$return);
            push (@options,\%option);
         #}
      }
  }
  return \@options;
}

#my $c=createFlightDays("01/01/2015","10/03/2015","BOS","LON");
#createRoutes();
#loadFlights();
#createRoutes();
1;
