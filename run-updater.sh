#!/bin/sh
#Function: To aid in the execution of the updater perl script
#
#Arguments Start-Year Start-Day End-Year End-Day Collector
#Example:  2007 1 2010 12 linx

#
#BASE DIRECTORY
basedir=/home_netwisdom/study/

#ARGUMENTS
startyear=$1
startmonth=$2
endyear=$3
endmonth=$4
collector=$5

#Input Checks
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
	
	echo $basedir$year/$fixmon/$collector;
    done
done


