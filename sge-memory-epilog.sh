#!/bin/bash

# SCIcore epilog script to check the memory usage by job
# For this to work you need to configure ENABLE_MEM_DETAILS=true
# so maxrss value by job is available in qstat -j output

# reserved memory including the unit (last character)
reserved_memory=${SGE_HGR_h_rss}

# JSV sets a default value of 2G for reserved memory
# if this is a single core job reserving the default 2G memory
# we don't do any process and exit now
if [ "$reserved_memory" == "2.000G" ];
then
	exit 0
fi

# if we reach here we will need to use qstat to parse the memory usage
# so firt load the SGE environment vars
source /etc/profile.d/sge.sh

# save the qstat output to $TMPDIR so it gets deleted when the job finishes
#qstat_output=$TMPDIR/qstat.txt
qstat_output=/tmp/qstat.txt

env > /tmp/epilog-env2.txt


# function to normalize memory size values to something 
# homogeneous we can compare. 
# memory format can be 568.000K, 98.535M or 2.000G
function convert(){
	
	echo $1 | sed '
      	s/\([0-9][0-9]*\(\.[0-9]\+\)\?\)K/\1*1000/g;
     	s/\([0-9][0-9]*\(\.[0-9]\+\)\?\)M/\1*1000000/g;
      	s/\([0-9][0-9]*\(\.[0-9]\+\)\?\)G/\1*1000000000/g;
      	s/\([0-9][0-9]*\(\.[0-9]\+\)\?\)T/\1*1000000000000/g;
      	s/\([0-9][0-9]*\(\.[0-9]\+\)\?\)P/\1*1000000000000000/g;
      	s/\([0-9][0-9]*\(\.[0-9]\+\)\?\)E/\1*1000000000000000000/g
  	' | bc 

}

normalized_reserved_memory=`convert ${reserved_memory}`

qstat -j $JOB_ID >> $qstat_output

# Verify if in the qstat output we find the maxrss value.
# For short jobs this information is not available
if grep --quiet maxrss $qstat_output; then
	# parse the maxrss value from qstat output
	# maxrss can be in format 568.000K, 98.535M or 2.000G
	maxrss=`grep maxrss $qstat_output|awk -F "," {'print $10'} | awk -F "=" {'print $2'}`
	normalized_maxrss=`convert ${maxrss}`
	used_memory_percentage=`echo "scale=0; $normalized_maxrss*100/$normalized_reserved_memory" | bc`
	echo $normalized_reserved_memory >> $qstat_output
	echo $normalized_maxrss >> $qstat_output
	echo $used_memory_percentage >> $qstat_output

else
	# maxrss not found in qstat output
	# probably because this was a really short job
	exit 0
fi

