#!/bin/bash

##########################################################################
# System Audit v0.4					
# 20131222 translated to bash - je
# 20131225 added ftp, spx, power functions, bug fixes - je
##########################################################################
#
# Feature request, software update custom url and available updates, internet plugins-version, OD binding?,

# Trap unknown errors and clean up
trap "exit 1" 1 2 3 5 15

# Fatal error function
function fatal {
    echo "$0: fatal error: $@"
    exit 1
}

# Print usage information
function usage ()
{
scriptname=`basename $0`
cat << EOF
usage: $scriptname -c <client name> -s <ftp server> -u <username> [-p <password>]

OPTIONS:
-c unique identifier for audit, a folder of this name will be made on your ftp server
-s ftp server fqdn/path sans protocol ie: mybigfat.ftpserver.com
-u username to connect to ftp server
-p password for username, will prompt if none given

NOTE:
Requires root privileges to successfully deduce all features

EOF
}

# Get the command line arguments
if [ $# -ne 0 ] && [ $# -lt 8 ]; then
    usage
    fatal "Not enough arguments given"
    exit 1
fi

# Read command line options
while getopts "c:s:u:p:" option
do
    case $option in
        c)
        clientname=$OPTARG
        ;;
        s)
        ftpserver=$OPTARG
        ;;
        u)
        username=$OPTARG
        ;;
        p)
        password=$OPTARG
        ;;
        ?)
        usage
        exit
        ;;
    esac
done

# Date stamp
dateStamp=`date +%s`
hostname=`hostname`

# Declare log files
checklog="systemAudit-$dateStamp-$hostname.log"
checkLog="/tmp/${checklog}"
touch $checkLog
echo Audit report will be saved to ${checkLog}
spxreport="spxReport-$dateStamp-$hostname.spx"
spxReport="/tmp/${spxreport}"
echo spx report will be saved to ${spxReport}
echo Running audit report...


################################################################################
#
# Functions
#
################################################################################

### SYSTEM SUMMARY ###
# change this so it figures out what adapters are called via sysprefs
function sysSum {
	echo >> $checkLog
	echo -----SYSTEM SUMMARY------- >> $checkLog
	echo Hostname: `hostname` >> $checkLog
	echo Uptime: `uptime` >> $checkLog
	echo Power: >> $checkLog
	pmset -g batt >> $checkLog
	echo Current User: `whoami` >> $checkLog
	echo en0 IP Address: `ipconfig getifaddr en0` >> $checkLog
	echo en1 IP Address: `ipconfig getifaddr en1` >> $checkLog
	echo Mac OS X Version: `sw_vers -productVersion` >> $checkLog
	echo Memory Report: >> $checkLog
		var1=(`vm_stat | tail -n +2 | head -n 5| sed 's/[^A-Z,a-z]//g' | sed 's/Pages/Memory_/g'`)
		var2=(`vm_stat | tail -n +2 | head -n 5 | sed 's/[^0-9]//g'`)
		for ((x=0;x<=4;x++)); do
		   echo "${var1[x]}" "$((${var2[x]}*4096/1024/1024))MB" >> $checkLog
		done
	system_profiler SPHardwareDataType -detailLevel >> $checkLog
	
}

### SMART ###
function smartStat {
	echo  >> $checkLog
	echo -----SMART STATUS CHECK------- >> $checkLog
	for fn in `diskutil list | grep /dev/`; do
	   echo $fn `diskutil info $fn | grep SMART` >> $checkLog
	done
}

### DISK I/O ERRORS ###
function diskIO {
	echo  >> $checkLog
        echo -----DISK IO CHECK------- >> $checkLog
        diskchk=`cat /var/log/system.log | egrep ".*disk.*I/O.*"`
	echo $diskchk >> $checkLog
}

### DISK USAGE ###
function diskSum {
	echo  >> $checkLog
	echo -----DISK USAGE ------- >> $checkLog
	df -h >> $checkLog
}

### RAID CHECK ###
function raidCheck {
	echo  >> $checkLog
	echo -----RAID CHECK ------- >> $checkLog
	diskutil AppleRAID list >> $checkLog
}

### SPOTLIGHT ###
function spotLight {
	echo  >> $checkLog
	echo -----SPOTLIGHT CHECK------- >> $checkLog
	mdutil -s -a >> $checkLog
}


### NETWORK INTERFACES ###
function netInts {
	echo >> $checkLog
	echo ----- ACTIVE NETWORK INTERFACES ------- >> $checkLog
# get a list of devices by their unique identifier name
	devlist=""
	devlist="$(networksetup -listnetworkserviceorder | grep -E en[0-9]+ | \
	    sed -e 's/^(H.*rt: \(.*\), Device: \(.*\))/\1/' \
	        -e 's/[()\*#]//g' -e 's/[ -]/_/g')"

# get a list of devices by their bsd interface name
	iflist=""
	iflist="$(networksetup -listnetworkserviceorder | grep -E en[0-9]+ | \
	    sed -e 's/^(H.*rt: \(.*\), Device: \(.*\))/\1=\2/' \
	        -e 's/[()\*#]//g' -e 's/[ -]/_/g')"
# rationalize the unique identifiers to the bsd names
	for iface in ${iflist}; do
	    eval export ${iface}
	done
# loop to line all that shit up
	for dev in $devlist; do
		aa="`ipconfig getifaddr ${!dev} 2> /dev/null`"	
		if [[ $aa ]]; then 
			echo >> $checkLog
			echo "${dev} is ${!dev}" >> $checkLog
			echo IP Address: $aa >> $checkLog
		if [[ ${dev} == "Wi_Fi" ]]; then 
			echo Wireless Signal Strength >> $checkLog
			/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I >> $checkLog
		fi
		fi
	done
}

### 3rd Party Plugins, Daemons, and Extensions ###
function 3rdParty {
	echo  >> $checkLog
	echo ----- SYSTEM INTERNET PLUGINS CHECK------- >> $checkLog
	echo System Internet Plugins /Library/Internet Plug-ins `ls /Library/Internet\ Plug-ins | wc -l` >> $checkLog
	ls -C /Library/Internet\ Plug-ins >> $checkLog
	echo >> $checkLog
	echo ----- USER INTERNET PLUGINS CHECK------- >> $checkLog
	# I don't like this code. It assumes the user folders are in /Users. Can't use ~${user}, won't work. :( Guess it doesn't really matter thought cause the for loop is based around /Users
	for user in `ls -1 /Users | grep -Ev "^\\."`; do
		num=`ls -C /Users/${user}/Library/Internet\ Plug-ins 2> /dev/null | grep -Ev "^\\." | wc -l`
		if [[ ${num} -ne "0" ]]; then
			echo User Internet Plugins /User/${user}/Library/Internet Plug-ins `ls /Users/${user}/Library/Internet\ Plug-ins | wc -l` >> $checkLog >> $checkLog
			ls -C /Users/${user}/Library/Internet\ Plug-ins 2> /dev/null | grep -Ev "^\\." >> $checkLog
		fi
	done
	echo  >> $checkLog
	echo -----3RD PARTY KERNEL EXTENSIONS------- >> $checkLog
	kextstat -kl | awk '!/com\.apple/{printf "%s %s\n", $6, $7}' >> $checkLog
	echo  >> $checkLog
	echo -----3RD PARTY LAUNCH DAEMONS and STARTUP ITEMS------- >> $checkLog
	launchctl list | sed 1d | awk '!/0x|com\.(apple|openssh|vix)|org\.(amav|apac|cups|isc|ntp|postf|x)/{print $3}' >> $checkLog
	defaults read com.apple.loginwindow LoginHook 1>> $checkLog 2> /dev/null
}

### USERS ###
function checkUsers {
	echo >> $checkLog
	echo ----- LOCAL USERS ------- >> $checkLog
	for user in `ls -1 /Users | grep -Ev "^\\."`; do
		echo $user home dir: >> $checkLog
		du -sh /Users/${user} >> $checkLog
		num=`ls -C /Users/${user}/Library/Mail/V2/ 2> /dev/null | grep -Ev "^\\." | wc -l`
		if [[ ${num} -ne "0" ]]; then
			echo $user email accounts: >> $checkLog
			du -sch /Users/${user}/Library/Mail/V2/* 2> /dev/null 1>> $checkLog
			echo >> $checkLog
		fi
	done
	echo user footprint: `du -sh /Users` >> $checkLog
}

## POWER REPORT ###
function powerReport {
	echo >> $checkLog
	echo ----- BATTERY ------- >> $checkLog
	pmset -g batt >> $checkLog
	system_profiler SPPowerDataType | grep -E 'Cycle Count|Charge Remaining|Full Charge Capacity|Condition' >> $checkLog
}

### spx REPORT ###
function spxReport {
	echo Fetching spx Report... 
	system_profiler SPSoftwareDataType SPHardwareDataType SPNetworkDataType SPNetworkLocationDataType -xml > $spxReport || echo Could not create spx report
	echo spx Complete
}

### Upload to FTP ###
function ftpUpload {
	echo Uploading to: $ftpserver
	curl -s --ftp-create-dirs -T $checkLog -u ${username}:${password} ftp://${ftpserver}/${clientname}/${checklog} || fatal "Audit Report FTP upload failed"
	echo Audit Report FTP upload OK
	curl -s --ftp-create-dirs -T $spxReport -u ${username}:${password} ftp://${ftpserver}/${clientname}/${spxreport} || fatal "spx Report FTP upload failed"
	echo spx Report FTP upload OK
}

################################################################################
#
# Main Program
#
################################################################################

sysSum
smartStat
diskIO
diskSum
raidCheck
spotLight
netInts
3rdParty
checkUsers
powerReport
spxReport
if [[ $ftpserver ]]; then
ftpUpload
fi
