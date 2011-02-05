#!/usr/bin/perl

use strict;
use Time::Local;
use DateTime;

print "For help, ./updater.pl -h\nVersion 1.4.3\n\n";
#globals
our $ABSOLUTE = 0;
our $BGPDUMP = "bgpdump";
our $DIRECTORY = "";
our $COLLECTOR = "";
our $YEAR = "";
our $MONTH = "";
our $DAY = "";
our $STOP_HOUR = "";
our $STOP_MINUTE = "";
our $STOP_SECOND = "";
#locals
my $argnum = "";
my $byear = "";
my $bmonth = "";
my $eyear = "";
my $emonth = "";


foreach $argnum (0..$#ARGV){
	if($ARGV[$argnum] eq "-d"){
		$DIRECTORY = $ARGV[$argnum + 1];
	}
	
	if($ARGV[$argnum] eq "-a"){
		$ABSOLUTE = 1;
		$YEAR = $ARGV[$argnum + 1];
		$MONTH = $ARGV[$argnum + 2];
		$DAY = $ARGV[$argnum + 3];
	}
	if($ARGV[$argnum] eq "-b"){
		$byear  = $ARGV[$argnum + 1];
		$bmonth = $ARGV[$argnum + 2];
	}
	
	if($ARGV[$argnum] eq "-e"){
		$eyear  = $ARGV[$argnum + 1];
		$emonth = $ARGV[$argnum + 2];
	}

	if($ARGV[$argnum] eq "-c"){
		$COLLECTOR = $ARGV[$argnum + 1];
	}	
	if(($ARGV[$argnum] eq "-h") || ($ARGV[$argnum] eq "-?")){
		
		print_help();
	}
	if($ARGV[$argnum] eq "-t"){
		$STOP_HOUR = $ARGV[$argnum + 1];
		$STOP_MINUTE = $ARGV[$argnum + 2];
		$STOP_SECOND = $ARGV[$argnum + 3];
	}	
	if($ARGV[$argnum] eq "-bgp"){
		$BGPDUMP = $ARGV[$argnum + 1];
	}	
}

if((($eyear == $byear) && ($emonth < $bmonth)) || ($eyear lt $byear)){
		print "Check your syntax\n";
		if($emonth < $bmonth){
		  print "$emonth < $bmonth\n";
		}
		if($eyear == $byear){
		  print "$eyear == $byear\n";
		}
		  print_help();
	}
	
our $stop_time = 0;

#hash for the stop times to be read in from the final, official rib table dump
our %drifts    = ();
our %tabledump = ();
main($byear, $bmonth, $eyear, $emonth);

sub main {

	#simply looping through the dates

	my $fixMonth = "";
	my $dir = "";
	my $toscan = "";
	my $teststr = "";
	my $toscan_upper = "";
	my $toscan_lower = "";
	my $yr = 0;
	my $mn = 0;
	my $dy = 0;
	if($ABSOLUTE==1){
		$stop_time = getLastSecond(convert($YEAR.$MONTH.$DAY));
		print "Ignoring all updates after timestamp:$stop_time. for $YEAR $MONTH $DAY\n\n";
		applyUpdates($DIRECTORY);
       	}else{
		while (1) {
			if ( $byear == 2011 && $bmonth == 1 ) {
			        exit;
			}
			if ( $bmonth <= 9 ) {
				$fixMonth = "0" . $bmonth;
			}
			else {
				$fixMonth = $bmonth;
			}
			getDriftDirs( $byear, $fixMonth );
			if($bmonth == 12){
				$byear++;
				$bmonth = 1;
			}else {
				$bmonth++;
			}
			foreach $dir ( sort { $a <=> $b } ( keys(%drifts) ) ) {
				$toscan_upper = $drifts{$dir}->{'dir'};
				$toscan_lower = $drifts{$dir}->{'drift'};
				$teststr = $drifts{$dir}->{'drift'};
				$stop_time = getLastSecond(convert($teststr));
				$yr = substr($teststr,0,4);
				$mn = substr($teststr,4,2);
				$dy = substr($teststr,6,2);
				applyUpdates($toscan_upper, $toscan_lower);		  
			}
			%drifts = ();
		}
	}
}
sub getLastSecond{
	#This function is used to get the last update before the stop time.
	#Reasoning: User may want to update a rib table to 00:00, but the two closest
	#updates are 11:57 and 00:04, implying that either 11:57 or 00:04 is the time
	#to which the new table will be updated
	my $lyear = $_[0];
	my $lmon  = $_[1]-1;
	my $lmday = $_[2];
	my $time = timegm($STOP_SECOND,$STOP_MINUTE,$STOP_HOUR,$lmday,$lmon,$lyear);
	return $time;
}
sub getDateTime{
        my $dt = DateTime->from_epoch( epoch => $stop_time );

	my $year   = $dt->year;
	my $month  = $dt->month; # 1-12 - you can also use '$dt->mon'
	if($month <= 9){
	  $month = "0$month";
	}
	my $day    = $dt->day; # 1-31 - also 'day_of_month', 'mday'
	if($day <= 9){
	  $day = "0$day";
	}

	return $year.$month.$day;

}

sub print_help{
	print "\nOptions:";
	print "\n-d [directory] :\tMain directory where all of the tables are kept.\n\t\t\tbgpdump should be placed here.";
	print "\n-b [begin date]:\tStarting year followed by month.";
	print "\n-e [end date]  :\tEnd year followed by month.";
	print "\n-c [collector] :\tName of the collecter";
	print "\n-t [timestamp] :\tThe time (inclusive) in HH MM to apply the update ";
	print "\n-bgp [filename]:\tThe filename of bgpdump \n\t\t\tDefault: 'bgpdump'";
	print "\n-a\t       :\tDirectory given with -d will be taken as the absolute path and only updates in that\n\t\t\tdirectory will be applied to the rib in that directory.";
	print "\n\nExample:";
	print "\n\t./Updater.pl -bgp bgpdump_x86 -d /home/rib_tables -c linx -b 2007 5 -e 2007 4 -t 12 45\n";
	print "\n\t./Updater.pl -d /home/rib_tables -a 2007 5 3 -t 12 45\n";
	
	print "\n\nPlease make sure you have the latest version of bgpdump from http://www.ris.ripe.net/source/\n";
	exit;
}

sub stripUpdate {

	#When an update is processed, the string needs to be changed to reflect
	#the typical BGP attributes, so the following are changed with
	#regular expressions

	$_[0] =~ s/BGP4MP/TABLE_DUMP/;
	$_[0] =~ s/\|A\|/\|B\|/;
	$_[0] =~ s/M4//;
	$_[0] =~ s/B4//;
	$_[0] =~ s/U4//;
	$_[0] =~ s/M6//;
	$_[0] =~ s/B6//;
	$_[0] =~ s/U6//;
	$_[0] =~ s/RI//;
	return ( $_[0] );
}
sub applyUpdates {

	#the update directory as given from the main subroutine and open it
	my $baseDir  = $_[0];
	my $driftDir = $_[1];
	my $updateDir = $baseDir."/".$driftDir;
	opendir( dir_temp, $updateDir );


#Need to get the rib file from the directory just opened and give it the full path
	my @rib     = grep( /rib/, readdir(dir_temp) );
	my $ribfile = $rib[0];
	$ribfile = $updateDir . "/" . $ribfile;

	print "Appyling updates to $ribfile until $stop_time\n";

	#Do the same with all of the updates, but storing them in an array
	opendir( dir_temp, $updateDir );
	my @updates = sort( grep( /updates/, readdir(dir_temp) ) );
	

#Since the output is obtained from STDOUT, base commands are created for later access
	my $ribcommand_base    = "./".$BGPDUMP." -m -t dump ";
	my $updatecommand_base = "./".$BGPDUMP." -m ";
	my $ribcommand         = $ribcommand_base . $ribfile . " |";


	#open the rib file and pipe the output to this script
	print "opening ribfile, " . $ribfile . "\n";
	open( BGPDUMP, $ribcommand ) || die "Failed at " . $ribcommand . "!\n";

	#Loop through the output's lines
	#Hash array for storing the output from the table dump file
	%tabledump = ();
	while (<BGPDUMP>) {

		#for each line, split on the "|" delimeter and store it in an array
		my @dump = split( /\|/, $_ );
		my $key = $dump[3] . "|" . $dump[4] . "|" . $dump[5];
		chomp($key);

	#The prefix that will be used as the key to the hash table is always the [5] element.
	
	#If this prefix does not already exist in the hash array, add it and set the "info"
	#attribute equal to the line
	#
	#If it does exist in there, just append the current information
		if ( !( exists( $tabledump{$key} ) ) ) {
			$tabledump{$key} = $_;
		}
	}
	
	#All of the updates in the array are processed here
	foreach (@updates) {

		#Open the update and create the update command
		my $updatefile    = $updateDir . "/" . $_;
		my $updatecommand = $updatecommand_base . $updatefile . " |";

		#Pipe the output and capture
		print "opening update, " . $updatefile . "\n\n";
		open( UPDATE, $updatecommand ) || die "Failed at " . $updatecommand . "!\n";
		while (<UPDATE>) {
#Loop through the update, line by line, and break the lines up based on the
# "|" delimeter. We need to be able to analyze the action, either Apply or Withdraw
# We need the timestamp for comparison, and the "interior key" for the values in the
# hash table are the peer_ip, peer_as, and prefix
			my @update         = split( /\|/, $_ );
			my $updates_string = $_;
			my $timestamp      = $update[1];
			my $action         = $update[2];
			my $peer_ip        = $update[3];
			my $peer_as        = $update[4];
			my $prefix         = $update[5];
			my $nexthop	= $update[8];
			
			my $key = $peer_ip . "|" . $peer_as . "|" . $prefix;
			chomp($prefix);
			chomp($key);
			
			if(!($updates_string =~ m/M4/)){
			  my @info_from_hash = split( /\|/, $tabledump{$key} );
			my $hash_timestamp = $info_from_hash[1];
					if(!($timestamp gt $stop_time)){
						if (exists( $tabledump{$key})) {
								if (!($timestamp lt $hash_timestamp) || ($timestamp eq $hash_timestamp)) {	
									if ( $action eq "W" ) {								
												delete $tabledump{$key};
									} elsif ( $action eq "A" ) {
										$tabledump{$key} = &stripUpdate($updates_string);	
									}
								}
						}							
						if ( !exists( $tabledump{$key} ) && ($action eq "A")) {
							$tabledump{$key} = &stripUpdate($updates_string);
						}	
					}				
				} 
			}
		}
	my $dt = getDateTime($stop_time);
	my $outfile = $baseDir . "/" . "rib.".$dt.".0000.update.gz";
	open(OUTPUTFILE, "|gzip -1 >$outfile");

	#Loop through the hash and print everything to the output file.
	foreach my $loop ( sort { $a <=> $b } ( keys(%tabledump) ) ) {
		print OUTPUTFILE $tabledump{$loop};
		#delete $tabledump{$loop};

	}
	close(OUTPUTFILE);
	#zip($outfile);
	#unlink $outfile;
	@rib = [];

}

#Loops through the entire contents of our downloaded files
#Retrieves all subdirectories with .drift
sub getDriftDirs {
  
	my $year  = $_[0];
	my $month = $_[1];
	my $dir = "";

	#base directoryt on Netwisdom where all of the RIBs are located
	my $basedir = $DIRECTORY . $year . "/" . $month;
	my $dir = $basedir . "/" . $COLLECTOR;    #the collectors directory
	opendir( dir_temp, $dir );                        #open that directory
	my @dirList =  grep( /drift/, readdir(dir_temp) );    #and get the directory of all drifts

	foreach (@dirList) {
		if ( !( exists( $drifts{$_} ) ) ) {
			$drifts{$_}->{'dir'} = $dir;
			$drifts{$_}->{'drift'} = $_;
		}
	}
}
sub convert{
	my @date = (substr($_[0],0,4), substr($_[0],4,2), substr($_[0],6,2));

	return @date;
}


