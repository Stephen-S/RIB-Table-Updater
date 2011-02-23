#!/bin/bash
#Function: To aid in the execution of the updater perl script
#          to loop through a number of months. Directory struct
#          assumed to be basedir/YEAR/MONTH/COLLECTOR/DRIFT-Dir
#
#          DRIFT-Dir was a specific value for our purposes.
#
#Arguments Start-Year Start-Day End-Year End-Day Collector
#Example:  2007 1 2010 12 linx
#
#
#BASE DIRECTORY
basedir=

#ARGUMENTS
startyear=$1
startmonth=$2
endyear=$3
endmonth=$4
collector=$5

#For the directory loop
timestopMon=0
timestopDay=0

#Input Checks

if [ $basedir="" ]
then
    echo "Configure the basedir variable!";
    exit;
fi

if [ $startyear -gt $endyear ]
then
    echo "Start year is greater than end year!";
    exit;
fi

if [ $startyear -eq $endyear ]
then
    if [ $startmonth -gt $endmonth ]
    then
	echo "Start month is greater than the end month for this year!";
	exit;
    fi
fi

for ((  year = $startyear ;  year <= $endyear;  year++  ))
do
    for ((  mon = $startmonth ;  mon <= $endmonth;  mon++  ))
    do
	if [ $mon -le 9 ]
	then
	    fixmon=0$mon;
	else
	    fixmon=$mon;
	fi
	
	for dir in $(ls $basedir$year/$fixmon/$collector | grep drift)
	do
	    echo "./updater.pl -d $basedir$year/$fixmon/$collector/$dir -t ${dir:0:4} ${dir:4:2} ${dir:6:2} 00 00 00";
	    echo "$collector: ${dir:0:4} ${dir:4:2} ${dir:6:2}";
	    ./updater.pl -d $basedir$year/$fixmon/$collector/$dir -t ${dir:0:4} ${dir:4:2} ${dir:6:2} 00 00 00
	    gzip $basedir$year/$fixmon/$collector/$dir/rib.${dir:0:4}${dir:4:2}${dir:6:2}.0000.update
	    mv $basedir$year/$fixmon/$collector/$dir/rib.${dir:0:4}${dir:4:2}${dir:6:2}.0000.update.gz $basedir$year/$fixmon/$collector/rib.${dir:0:4}${dir:4:2}${dir:6:2}.0000.update.gz
	done
    done
done


