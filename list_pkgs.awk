#!/usr/bin/awk -f
#
# Description:	List packages in the 'packages.tsv' file as per the input parameters.
#
# Parameters:
#	os	Operating System (openbsd, arch, void)
#	machine	Machine type (desktop, laptop, server)
#

# Set the 'Field Separator', and assert the definition of the mandatory
# parameters.
BEGIN {
	FS="\t";
	if(!os){
		print "Error: No 'os' variable defined." > "/dev/stderr";
		exit 1;
	}
	if(!machine){
		print "Error: No 'machine' variable must be defined as desktop, laptop, or server." > "/dev/stderr";
		exit 1;
	}
}

# Accept files saved with CRLF line endings.
{ sub(/\r$/, "") }

# Load the data header into an associative array
NR==1 {
	for(i=1; i<=NF; i++){
		idx[$i] = i
	}
	# A missing column would otherwise select whole rows ($0).
	split(os " " machine " essential", required, " ")
	for(i in required){
		if(!(required[i] in idx)){
			print "Error: No '" required[i] "' column in the header." > "/dev/stderr";
			exit 1;
		}
	}
}

NR > 1 {
	#---- Skip package if ----#
	# Not applicable to OS
	if(!$idx[os]){ next }

	# Not applicable to the machine type
	if($idx[machine]!="TRUE") { next }

	# The package is not essential, and the user did not request listing the
	# non essential packages by defining the 'extra' variable.
	if($idx["essential"]!="TRUE" && !extra ) { next }


	print $idx[os]
}
