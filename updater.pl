#!/usr/bin/perl

#Author: Stephen Smith: sgsmith1 at memphis.edu
#Code is provided as-is
#Use as you wish but keep the author's name
use strict;
use Time::Local;
use DateTime;
use Proc::ProcessTable;

#globals
our $BGPDUMP = "bgpdump";
our $DIRECTORY = "";

our $YEAR = "";
our $MONTH = "";
our $DAY = "";
our $STOP_HOUR = "";
our $STOP_MINUTE = "";
our $STOP_SECOND = "";
#locals
my $argnum = "";
our $logfile = "arcturus.log";

foreach $argnum (0..$#ARGV){
	if($ARGV[$argnum] eq "-d"){
		$DIRECTORY = $ARGV[$argnum + 1];
	}
	
	if($ARGV[$argnum] eq "-t"){
		$YEAR = $ARGV[$argnum + 1];
		$MONTH = $ARGV[$argnum + 2];
		$DAY = $ARGV[$argnum + 3];
		$STOP_HOUR = $ARGV[$argnum + 4];
		$STOP_MINUTE = $ARGV[$argnum + 5];
		$STOP_SECOND = $ARGV[$argnum + 6];
	}	
	if(($ARGV[$argnum] eq "-h") || ($ARGV[$argnum] eq "-?")){
		
		print_help();
	}	
	if($ARGV[$argnum] eq "-bgp"){
		$BGPDUMP = $ARGV[$argnum + 1];
	}	
}

our $stop_time = 0;	
$stop_time = getLastSecond(convert($YEAR.$MONTH.$DAY));
####Debugging####
open( logfile, ">>$logfile" ) || die("Cannot Open arcturus.log File");
print logfile "$YEAR/$MONTH/$DAY|";
close( logfile );
#################
applyUpdates($DIRECTORY);

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
	print "BGP Table Updater - Version 1.6.4\n";
	print "\n-h [help]      :\tThis screen";
	print "\n-d [directory] :\tMain directory where all of the tables are kept.\n\t\t\tbgpdump should be placed here.";
	print "\n-t [timestamp] :\tThe time (inclusive) in HH MM to apply the update ";
	print "\n-bgp [filename]:\tThe filename of bgpdump \n\t\t\tDefault: 'bgpdump'";
	print "\n\nExample:";
	print "\n\t./Updater.pl -d /home/rib_tables -t 2007 05 03 12 45 00\n";
	
	print "\n\nPlease make sure you have the latest version of bgpdump from http://www.ris.ripe.net/source/\n";
	exit;
}

sub stripUpdate {

	#When an update is processed, the string needs to be changed to reflect
	#the typical BGP attributes, so the following are changed with
	#regular expressions
        #Some of these options are written specifically for a modified version of 
        #BGPDump but should not affect results.

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
	my $updateDir  = $_[0];
	opendir( dir_temp, $updateDir );
	

#Need to get the rib file from the directory just opened and give it the full path
	my @rib     = grep( /rib/, readdir(dir_temp) );
	closedir( dir_temp );
	my $ribfile = $rib[0];
	$ribfile = $updateDir . "/" . $ribfile;

	####Debugging####
	open( logfile, ">>$logfile" ) || die("Cannot Open arcturus.log File");
	print logfile "$ribfile|";
	close( logfile );
	#################

	#Do the same with all of the updates, but storing them in an array
	opendir( dir_temp, $updateDir );
	my @updates = sort( grep( /updates/, readdir(dir_temp) ) );
	closedir( dir_temp );
	

#Since the output is obtained from STDOUT, base commands are created for later access
	my $ribcommand_base    = "./".$BGPDUMP." -m -t dump ";
	my $updatecommand_base = "./".$BGPDUMP." -m ";
	my $ribcommand         = $ribcommand_base . $ribfile . " |";
	

	#open the rib file and pipe the output to this script
	open( BGPDUMP, $ribcommand ) || die "Failed at " . $ribcommand . "!\n";

	#Loop through the output's lines
	#Hash array for storing the output from the table dump file
	my %tabledump = ();
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
	close( BGPDUMP );
	#All of the updates in the array are processed here
	foreach (@updates) {
		#Open the update and create the update command
		my $updatefile    = $updateDir . "/" . $_;
		my $updatecommand = $updatecommand_base . $updatefile . " |";

		####Debugging####
		open( logfile, ">>$logfile" ) || die("Cannot Open arcturus.log File");
		print logfile "$updatefile|";
		close( logfile );
		#################

		#Pipe the output and capture
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
			my $nexthop        = $update[8];
			
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
			        undef @info_from_hash;
				}
			undef @update;
			}
		close( UPDATE );
		}
	undef @rib;
	undef @updates;
	
	####Debugging####
	open( logfile, ">>$logfile" ) || die("Cannot Open arcturus.log File");
	print logfile  memory_usage(), "|";
	close( logfile );
	#################
	
	my $dt = getDateTime($stop_time);
	my $outfile = $updateDir . "/" . "rib.".$dt.".0000.update.gz";
	open(OUTPUTFILE,"|gzip -1 >$outfile");

	#Loop through the hash and print everything to the output file.
	foreach my $loop ( sort { $a <=> $b } ( keys(%tabledump) ) ) {
		print OUTPUTFILE $tabledump{$loop};
		

	}
	undef %tabledump;
	close(OUTPUTFILE);

	####Debugging####
	open( logfile, ">>$logfile" ) || die("Cannot Open arcturus.log File");
	print logfile  "SUCCESS";
	close( logfile );
	#################
}

sub convert{
	my @date = (substr($_[0],0,4), substr($_[0],4,2), substr($_[0],6,2));

	return @date;
}

sub memory_usage {
  my $t = new Proc::ProcessTable;
  foreach my $got ( @{$t->table} ) {
    next if not $got->pid eq $$;
    return $got->size;
  }
}


