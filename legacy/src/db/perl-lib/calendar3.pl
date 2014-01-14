require 'sql.pl';
require 'misc.pl';

###################################
# DESCRIPTION:	Comparison function to sort a list of table records
#		within a weekly schedule, based on the StartTime date stamp.
#		Why, oh why, did I ever try to specify the starting
#		time with a single date stamp?
# ARGUMENTS:	$a, $b -- records to compare
# RETURN value:	
###################################
sub calendarGen {
  my ($a, $b) = @_;

  $a->{StartTime} =~ /(\d{4})-(\d\d)-(\d\d) (\d\d):(\d\d):(\d\d)/;
  my ($ah, $am, $as) = ($4, $5, $6);
  my $aDOW = &DOW($1, $2, $3);

  $b->{StartTime} =~ /(\d{4})-(\d\d)-(\d\d) (\d\d):(\d\d):(\d\d)/;
  my ($bh, $bm, $bs) = ($4, $5, $6);
  my $bDOW = &DOW($1, $2, $3);

  
}


###################################
# DESCRIPTION:	Builds a calendar from the given table by querying the
#		database and using the StartTime and EndTime fields
#		(which must be of type DATETIME).

#		This can be pretty easily parameterized for the length
#		of the calendar (day, month, etc) and the increment,
#		but I'm not going to bother here.

#		Because of the hour granularity, the rule is that if an event
#		takes up any time in an hour, it gets the whole hour (this also
#		affects conflict catching).

# ARGUMENTS:	$tbl - the table to be queried
# RETURN value:	A matrix (a reference to an array of references to arrays of
#		references to event records) representing the calendar,
#		with each hour filled in with the full info for
#		each event, dead time indicated with Type = 'dead',
#		and conflicts indicated with Type = 'conflict'.
#		Should be referenced as $calendar->[$day]->[$hour]
###################################
sub calendarGen {
  my ($tbl, $debug) = @_;

  # initialize with dead time
  my $calendar;
  foreach my $d (0..6) {
    foreach my $h (0..24) {
      foreach my $m (0,30) {
        $$calendar[$d]->[$h]->[$m] = {Type=>'dead', DurationM=>30, Program=>'Dead Air'};
      }
    }
  }

  # get all of the events
  my ($rows) = &sqlSelectMany($tbl, undef, undef, "StartTime DESC", {debug=>$debug});

  foreach my $event (@$rows) {
    print "Processing $$event{Program}<br />\n" if $debug;
    if ($debug>1) {
      print "<TABLE BORDER=1>";
      foreach my $h (0..24) {
	print "<TR><TH>$h</TH>";
        foreach my $d (0..6) {
          print "<TD BGCOLOR=\"".($$calendar[$d]->[$h]->{Type} eq 'dead' ? 'GRAY' : 'BLUE')."\"><SMALL>$h: ".$$calendar[$d]->[$h]->{Type}." / " .$$calendar[$d]->[$h]->{Duration}."</SMALL></TD>";
        }
	print "</TR>";
      }
      print "</TABLE>";
    }

    # Parse starting time
    $$event{StartTime} =~ /(\d{4})-(\d\d)-(\d\d) (\d\d):(\d\d):(\d\d)/;
    my ($sh, $sm, $ss) = ($4, $5, $6);
    my $sDOW = &DOW($1, $2, $3);
    # Then parse ending time
    $$event{EndTime} =~ /(\d{4})-(\d\d)-(\d\d) (\d\d):(\d\d):(\d\d)/;
    my ($eh, $em, $es) = ($4, $5, $6);
    my $eDOW = &DOW($1, $2, $3);

    #$eh = $eh + ($m+$s ? 1 : 0); # any minutes or seconds make it use the whole hour
    $em = ($em ? 30 : 0);
    $eDOW += 7 if $eDOW < $sDOW; # catch events that span weeks
    next if ($eDOW == $sDOW) and ($eh <= $sh); # ignore these. yuck.
    $hours = $eh + 24*($eDOW-$sDOW) - $sh - 1; # actually, hours - 1
    $mins = ($sm != $em) ? 0 : 30;

    #half-hour exceptions
    if (($eh > $sh) and $mins) { $hours = 0; }

    $$event{DurationH} = $hours + 1;
    $$event{DurationM} = $mins;

    # shorten the duration of all preceding dead time
#    if ($sh > 0 and $$calendar[$sDOW]->[$sh-1]->[$sm]->{Type} eq 'dead') {
#      my $dead = $sh;
#      my $deadm = $sm;
#      while ($dead>0 and $$calendar[$sDOW]->[$dead-1]->[$sm]->{Type} eq 'dead') { 
#        $dead--;
#        $$calendar[$sDOW]->[$dead]->[$deadm]->{DurationM} = $sm-$deadm;
#      }
#    }
    foreach my $hour (0..$hours) {
      foreach my $min (0,30) {
        my $d = ($sDOW + int(($hour+$sh) / 24)) % 7;
        my $h = ($hour+$sh) % 24;
        my $m = ($sm);
        print "inserting into [$d, $h]<br />\n" if $debug > 1;
        $$calendar[$d]->[$h]->[$m] = $event;
      }
    }
    if ($debug>1) {
      print "<TABLE BORDER=1>";
      foreach my $h (0..24) {
	print "<TR><TH>$h</TH>";
        foreach my $d (0..6) {
          print "<TD BGCOLOR=\"".($$calendar[$d]->[$h]->{Type} eq 'dead' ? 'GRAY' : 'BLUE')."\"><SMALL>$h: ".$$calendar[$d]->[$h]->{Type}." / " .$$calendar[$d]->[$h]->{Duration}."</SMALL></TD>";
        }
	print "</TR>";
      }
      print "</TABLE>";
    }
  }
  if ($debug>1) {
    print "<TABLE BORDER=1>";
    foreach my $h (0..24) {
      print "<TR><TH>$h</TH>";
      foreach my $d (0..6) {
	print "<TD BGCOLOR=\"".($$calendar[$d]->[$h]->{Type} eq 'dead' ? 'GRAY' : 'BLUE')."\"><SMALL>$h: ".$$calendar[$d]->[$h]->{Type}." / " .$$calendar[$d]->[$h]->{Duration}." / " .$$calendar[$d]->[$h]->{Program}."</SMALL></TD>";
      }
      print "</TR>";
    }
    print "</TABLE>";
  }
  return $calendar;
}

1;