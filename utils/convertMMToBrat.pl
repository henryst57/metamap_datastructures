#script to convert metamap machine output to brat annotations
use strict;
use warnings;
use lib '/home/sam/projects/annotation/preannotation/MetaMap-DataStructures-0.03/lib/';
use MetaMap::DataStructures;

my $inFolder = 'round_0_mm/';
my $outFolder = 'round_0_preAnn/';
my $textFolder = 'round_0/';
#semantic types are hardwired as dysn, sosy, clnd, phsu



#########################################################
#                    Begin Code
##########################################################
#Read the files from the inFolder
my $inFilesRef = &_getMMFiles($inFolder);
my $textFilesRef = &_getTxtFiles($textFolder);
`mkdir $outFolder`;

#read each .mm file and output a brat file
# with the desired semantic types annotated
foreach my $inFile (@{$inFilesRef}) {

    #initialize MM data structures which will be used to stor
    # info about the file as it is processed
    my %params = ();
    my $datastructures = MetaMap::DataStructures->new(\%params); 
    
    #open test input
    my $inPath = $inFolder.$inFile;
    open (IN, $inPath) || die "Coudn't open the input file: $inPath\n";

    #create Output
    my $outPath = $outFolder.$inFile;
    $outPath =~ s/\.mm/\.ann/;
    open (OUT, ">$outPath") ||  die "Could not open output file: $outPath\n";

    #open the corresponding text file and read its lines into an array
    my $textInPath = $inFile;
    $textInPath =~ s/\.mm/\.txt/;
    $textInPath = $textFolder.$textInPath;
    open (TXT_IN, $textInPath) or die ("ERROR: unable to open text file: $textInPath\n");
    my $inputText = '';
    while (my $line = <TXT_IN>) {
	$inputText .= $line;
    }
    close TXT_IN;
    
   #copy the text file to the pre-annoation (output) directory
    my $textOutPath = $inFile;
    $textOutPath =~ s/\.mm/\.txt/;
    $textOutPath = $outFolder.$textOutPath;
    `cp $textInPath $textOutPath`;


    #read each utterance 
    my $input = '';
    my $idCount = 1;
    my @citationOrder = ();
    while(<IN>) {
	#build a string until the utterance has been read in
	chomp $_;
	$input .= $_;
	if ($_ eq "\'EOU\'.") {
	    my $id = 'ab.'.$idCount;
	    $datastructures->createFromTextWithId($input,$id); 
	    $input = '';
	    $idCount++;
	    push @citationOrder, $id;
	}
    }
    close IN;

    #there will only be a single citation per file
    my $conceptCount = 0;
    my $citations = $datastructures->getCitations(); 
    my %alreadyOutput = ();
    foreach my $key (@citationOrder) {
	my $citation = ${$citations}{$key};

	#get an ordered list of all the concepts in the document
	my $utterances = $datastructures->getOrderedUtterances($citation);
	foreach my $utterance (@{$utterances}) {
	    my $utteranceCharLength = length($utterance->{text});
	    my $concepts = $utterance->getConcepts();

	    #save the set of concepts of the desired semantic type
	    # and their positional information to the output .ann
	    # file that will be used in Brat
	    foreach my $concept (@{$concepts}) {

	        #check the semantic type
		my $correctType = 0;
		if ($concept->{semanticTypes} =~ /sosy/
		    || $concept->{semanticTypes} =~ /dsyn/
		    || $concept->{semanticTypes} =~ /clnd/
		    || $concept->{semanticTypes} =~ /phsu/) {
		    $correctType = 1;
		}

		if ($correctType > 0) {
		    #we want to save this, so grab its semantic type, and 
		    # its positional information and output in brat format
		    #convert the semantic type
		    my $semanticType = $concept->{semanticTypes};
		    my $type = 'err';
		    if ($semanticType =~ /sosy/ || $semanticType =~ /dsyn/) {
			$type = 'Problem';
		    }
		    if ($semanticType =~ /clnd/ || $semanticType =~ /phsu/) {
			$type = 'Medication';
		    }
		    if ($type eq 'err' ) {
			die ("ERROR reading semantic type: $semanticType\n");
		    }

		    # Get the matching text by converting multiple spans 
		    # into a single span if necessary 
		    my $segmentsRef = $concept->{positionalSegments};
		    my @vals = split(/\//,${$segmentsRef}[0]);
		    my $originalStart = $vals[0];
		    my $length = $vals[1];
		    #check if you need to adjust length for multiple segments
		    my $segmentNum = 0;
		    foreach my $segmentRef (@{$concept->{positionalSegments}}) {
			if ($segmentNum == 0) {
			    next;
			}  
			my @vals = split(/\//,${$segmentsRef}[0]);
			my $newStart = $vals[0];
			my $newLength = $vals[1];
			$length = ($newStart + $newLength)-$originalStart;
			$segmentNum++;
		    } 
		    #get the matched text
		    my $matchedText = substr($inputText, $originalStart,$length);
		    
		    #construct the brat position output, be sure to care for 
		    # new lines
		    my @segments = split (/\n/,$matchedText);
		    my $positionString = '';
		    my $previousEnd = $originalStart-1;
		    foreach my $segment (@segments) {
			my $start = $previousEnd+1;
			my $end = $start+length($segment);
			$previousEnd = $end;
			$positionString .= "$start $end;"
		    }
		    chop $positionString; #remove trailing ';'
		    

		    #remove any new lines from matched text
		    # ... this is needed for correct brat output
		    $matchedText =~ s/\n/ /g;

		    #output the concept info if there isn't already
		    # something labeled in this text span. Duplicate labels
		    # are caused by ambiguous terms
		    if (!defined $alreadyOutput{$positionString}) {
			$alreadyOutput{$positionString} = 1;
			my $conceptID = 'T'.$conceptCount;
			print OUT "$conceptID\t$type $positionString\t$matchedText\n";
			$conceptCount++;
		    }
		}
	    }
	}
    }
    close OUT;
}




#script to read all of the .txt files from a directory
sub _getMMFiles {
    my $directory = shift;
    my @files = ();
    opendir(D, "$directory") || die "Can't open directory: $directory\n";
    while (my $f = readdir(D)) {
	if ($f =~ /\.mm/) {
	    push @files, $f;
	}
    }
    closedir(D);

    return \@files;
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
