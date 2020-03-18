#script to run metamap on a folder
use strict;
use warnings;

#NOTE: ensure the tagger server, and optionally the WSD server are
# running before running this script
# ./bin/skrmedpostctl start    <-- starts tagger server
# ./bin/wsdserverctl start     <-- starts wsd server
# they can be stopped by using 'stop' rather than 'start'

#user input
my $inFolder = 'round_0/';
my $outFolder = 'round_0_mm/';
my $metamapDir = 'public_mm/bin/';
my $optionsString = '-q --blanklines 9999999';
&_runMMOnFolder($inFolder, $outFolder, $metamapDir, $optionsString);


################################################################
#                       Begin Code
################################################################
#scipt to run MM on each file in the inFolder and output them
# to the outFolder
sub _runMMOnFolder {
    my $inFolder = shift;
    my $outFolder = shift;
    my $metamapDir = shift;
    my $optionsString = shift;

    #get the files in the input directory
    my $inFilesRef = &_getTxtFiles($inFolder);

    #construct the outFolder
    `mkdir $outFolder`;

    #run metamap on each of the input files
    foreach my $file (@{$inFilesRef}) {
	my $inPath = "$inFolder$file";
	my $outPath = "$outFolder$file";
	$outPath =~ s/\.txt/\.mm/;
	my $command = './'.$metamapDir.'metamap18'." $optionsString $inPath $outPath";
	print "$command\n";
	`$command`;
    }

    print "Done!\n";
}


#script to read all of the .txt files from a directory
sub _getTxtFiles {
    my $directory = shift;
    my @files = ();
    opendir(D, "$directory") || die "Can't open directory: $directory\n";
    while (my $f = readdir(D)) {
	if ($f =~ /\.txt/) {
	    push @files, $f;
	}
    }
    closedir(D);

    return \@files;
}
