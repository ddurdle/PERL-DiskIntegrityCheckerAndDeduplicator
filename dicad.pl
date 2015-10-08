#!/usr/bin/env perl
#
# Disk Integrity Checker and De-duplicator
#


######
#  Configuration
###
use FileHandle;
use constant DEBUG => 0;
use Fcntl;
use DB_File;


use Getopt::Std;
my $usage = <<EOM;
usage: $0 -s source_directory [-t source_directory] [-l logfile] [-X dbmfile] [-I dbmfile [-d destination_path]] [-i size] [-f] [-v]
\t-f force checksum calculation and validate against pre-existing
\t-v verbose
\t-D check for duplicates
\t-X create duplicate exclusion list based on MD5 dbm file
\t-I create duplicate inclusion list based on MD5 dbm file
\t\t-d destination path
\t-i ignore size (ignore files < this size)
EOM
my %opt;
die ($usage) unless (getopts ('l:s:t:fDvCi:I:d:X:', \%opt));

die($usage) unless ($opt{s} ne '');

my $isForce = 0;
$isForce = 1 if $opt{f};
my $logfile = $opt{l};
my $isVerbose = 0;
$isVerbose = 1 if $opt{v};
my $checkDuplicates = 0;
$checkDuplicates = 1 if $opt{D};

my $compareDrives = 0;
$compareDrives = 1 if $opt{C};

my $ignoreSize = 0;
$ignoreSize = $opt{i} if $opt{i};

my $fileCount=0;
my $dirCount=0;
my $MD5Count=0;
my $errCount=0;

my %duplicateMD5;
#recursively scan source directory
scanDir($opt{s});

my %duplicateMD52;
if ($opt{t} ne ''){
	#recursively scan source directory
	scanDir2($opt{t});
}

if ($opt{X} ne ''){
	open (LOG, '>'.$logfile) if ($logfile ne '');
	tie( my %dbase, DB_File, $opt{X} ,O_RDONLY, 0666) or die "can't open ". $opt{X}.": $!";
	foreach my $md5 (keys %duplicateMD5){
	  	if ((defined($dbase{$md5 . '_0'}) and $dbase{$md5 . '_0'} ne '') or (defined($dbase{$md5 . '_'}) and $dbase{$md5 . '_'} ne '')){
    		print STDERR $duplicateMD5{$md5}[1] . "\n";
    		print LOG $duplicateMD5{$md5}[1] . "\n";
	  	}
	}
	untie $dbase;
	close (LOG) if ($logfile ne '');
	exit(0);
}
if ($opt{I} ne ''){
	open (LOG, '>'.$logfile) if ($logfile ne '');
	tie( my %dbase, DB_File, $opt{I} ,O_RDONLY, 0666) or die "can't open ". $opt{I}.": $!";
	foreach my $md5 (keys %duplicateMD5){
	  	if ((defined($dbase{$md5 . '_0'}) and $dbase{$md5 . '_0'} ne '') or (defined($dbase{$md5 . '_'}) and $dbase{$md5 . '_'} ne '')){
	  	}else{
    		print STDERR $duplicateMD5{$md5}[1] . "\n";
    		$duplicateMD5{$md5}[1] =~ s%\n%%;
    		my ($path) = $duplicateMD5{$md5}[1] =~ m%(.*?)\/[^\/]+$%;
    		print LOG 'mkdir -p "' .$path . "\"\n";
    		print LOG 'cp "' . $duplicateMD5{$md5}[1] .'" "' .$opt{d}. "\"\n";
	  	}
	}
	untie $dbase;
	close (LOG) if ($logfile ne '');
	exit(0);
}
if ($opt{I} ne ''){
	open (LOG, '>'.$logfile) if ($logfile ne '');
	tie( my %dbase, DB_File, $opt{I} ,O_RDONLY, 0666) or die "can't open ". $opt{I}.": $!";
	foreach my $md5 (keys %duplicateMD5){
	  	if ((defined($dbase{$md5 . '_0'}) and $dbase{$md5 . '_0'} ne '') or (defined($dbase{$md5 . '_'}) and $dbase{$md5 . '_'} ne '')){
    		print STDERR $duplicateMD5{$md5}[1] . "\n";
    		print LOG $duplicateMD5{$md5}[1] . "\n";
	  	}
	}
	untie $dbase;
	close (LOG) if ($logfile ne '');
	exit(0);
}
#report duplicates
if ($checkDuplicates){
	my $duplicateCount=0;
	my $duplicateSize=0;
	print STDERR "check for duplicates...\n";
	open (LOG, '>'.$logfile)  if ($logfile ne '');
  	foreach my $md5 (keys %duplicateMD5){
	   	if ($duplicateMD5{$md5}[0] > 1 and $duplicateMD5{$md5}[2] > $ignoreSize) {
    		print STDERR ($duplicateCount++ +1) . ') duplicates for '.$md5 . "\n". $duplicateMD5{$md5}[1]."\n";
      		print LOG '#' .$duplicateCount."\n".$duplicateMD5{$md5}[3]."\n"  if ($logfile ne '');
      		$duplicateSize += $duplicateMD5{$md5}[2] * ($duplicateMD5{$md5}[0]-1);
	  	}
	}
	close (LOG) if ($logfile ne '');
	print STDERR "no duplicates found\n" if ($duplicateCount ==0);
	print STDERR sprintf('disk savings if duplicates were removed: %f MB', $duplicateSize/1000000);
}

#report differences
if ($compareDrives){
	my $duplicateCount=0;
	my $missingCount1=0;
	my $missingCount2=0;
	my $missingSize1=0;
	my $missingSize2=0;
	print STDERR "compare drives...\n";

	open (LOG, '>'.$logfile) if ($logfile ne '');
	foreach my $md5 (keys %duplicateMD5){
		#file is on both source & target
		if ($duplicateMD5{$md5}[0] >= 1 and $duplicateMD52{$md5}[0] >= 1 ) {
			$duplicateCount++;
		#file is missing on target
		}elsif ($duplicateMD5{$md5}[0] >= 1 and $duplicateMD52{$md5}[0] eq '' ) {
			if ($duplicateMD5{$md5}[2] > $ignoreSize){
				$missingCount1++;
				$missingSize1 += $duplicateMD5{$md5}[2];
				print STDERR ($missingCount1) . ') missing for '.$md5 . ' size ('.$duplicateMD5{$md5}[2].")\n". $duplicateMD5{$md5}[1]."\n";
				print LOG '#'.($missingCount1) . ') missing for '.$md5 . "\n". $duplicateMD5{$md5}[3]."\n" if ($logfile ne '');
			}
		}
	}
	foreach my $md5 (keys %duplicateMD52){
		#file is missing on source
		if ($duplicateMD5{$md5}[0] eq '' and $duplicateMD52{$md5}[0] >= 1 ) {
			if ($duplicateMD52{$md5}[2] > $ignoreSize){
				$missingCount2++;
				$missingSize2 += $duplicateMD52{$md5}[2];
				print STDERR ($missingCount2) . ') missing for '.$md5 . ' size ('.$duplicateMD52	{$md5}[2].")\n". $duplicateMD52{$md5}[1]."\n";
				print LOG '#'.($missingCount2) . ') missing for '.$md5 . "\n". $duplicateMD52{$md5}[3]."\n" if ($logfile ne '');
			}
		}
	}
	close (LOG) if ($logfile ne '');
	print STDERR sprintf('in sync: %f ', $duplicateCount) . "\n";
	print STDERR sprintf('missing/different on target: %d, %f MB', $missingCount1, $missingSize1/1000000) . "\n";
	print STDERR sprintf('missing/different on source: %d, %f MB', $missingCount2, $missingSize2/1000000) . "\n";
}

print STDERR 'dirs processed: ' . $dirCount . "\n";
print STDERR 'files processed: ' . $fileCount . "\n";
print STDERR 'MD5 files encountered: ' . $MD5Count . "\n";
print STDERR 'unhandled errors encountered: ' . $errCount . "\n";



#
#
#
sub scanDir($){

	my $directory = shift;
	$dirCount++;
	print STDERR 'Scanning dir '.$directory."\n";
	opendir(IMD, $directory) || die("Cannot open directory");
	my @dirContents = readdir(IMD);

	my %fileMD5;

	#scan MD5 files
	foreach my $item (@dirContents){

		if ($item =~ m%^\..*\.[^\.]{32}$%){
	    	my ($file,$md5) = $item =~ m%^\.(.*)\.([^\.]{32})$%;
	    	print STDERR "MD5 = $item, $file $md5\n" if (DEBUG);
	     	$fileMD5{$file} = $md5;
	    	if ($checkDuplicates or $compareDrives){
	      		$duplicateMD5{$md5}[0]++;
	      		$duplicateMD5{$md5}[1] .= $directory . '/'.$file .	"\n";
	      		$duplicateMD5{$md5}[2] = (-s $directory . '/'.$file);
	      		$duplicateMD5{$md5}[3] .= '#REMrm "' .$directory . '/'.$file ."\"\n";
	      		$duplicateMD5{$md5}[3] .= "#REMrm \"$directory/.$file.$md5\"\n";
	    	}
	  	}
	}

	#scan files [skip dirs] (non-MD5)
	foreach my $item (@dirContents){
		my $item_fixed = $item;
		$item_fixed =~ s%\`%\\\`%g;
		my $fullPath = $directory . '/' . $item;
		my $fullPath_fixed =  $directory . '/' . $item_fixed;

		#ignore . and ..
		#item is a symlink (skip)
		#print STDERR "checking . " . $item . "\n";
		if (-l $fullPath){

		}elsif (-d $fullPath){

			#is a MD5 checksum file; skip
		}elsif (-z $fullPath and $item =~ m%\.[^\.]+\.[^\.]{32}$%){
			$MD5Count++;
		#    print STDERR "skip MD5 file = " . $item . "\n"  if (DEBUG);

		#isForce -  item is a file and a MD5 file exists - check MD5
		}elsif ($isForce and -f $fullPath and $fileMD5{$item} ne ''){
			$fileCount++;
			open (MD5, "md5sum \"$fullPath_fixed\" |");
			my @md5 = split(' ', <MD5>);
			if ($md5[0] ne ''){
				#same MD5
				if ($md5[0] eq $fileMD5{$item}){
					print STDERR '.';
				}elsif ($md5[0] eq $fileMD5{$item}){
				print STDERR "** different MD5, " . $item . ', original MD5 = ' . $fileMD5{$item} .' new MD5 = '.$md5[0]."\n";
			}
		}

		#a MD5 file exists
		}elsif (!$isForce and -f $fullPath and $fileMD5{$item} ne ''){
			$fileCount++;
			print STDERR "skip (MD5 exists) = " . $item . "\n" if ($isVerbose);

		#item is a file and no MD5 file exists
		}elsif (-f $fullPath){
			$fileCount++;
			open (MD5, "md5sum \"$fullPath_fixed\" |");
			my @md5 = split(' ', <MD5>);
			if ($md5[0] ne ''){
				print STDERR "file = " . $item . ',' . $md5[0] ."\n" if ($isVerbose);

				`touch "$directory/.$item_fixed.$md5[0]"`;

				if ($checkDuplicates or $compareDrives){
					$duplicateMD5{$md5[0]}[0]++;
					$duplicateMD5{$md5[0]}[1] .= $fullPath ."\n";
					$duplicateMD5{$md5[0]}[2] = (-s $fullPath);
					$duplicateMD5{$md5[0]}[3] .= '#REMrm "'.$fullPath ."\"\n";
					$duplicateMD5{$md5[0]}[3] .= "#REMrm \"$directory/.$item.$md5[0]\"\n";
				}
			}

		}else{
			++$errCount;
			#unhandled
			print STDERR "unhandled = " . $fullPath . "\n";
		}

	}

	#scan dirs
	foreach my $item (@dirContents){
  		my $fullPath = $directory . '/' . $item;
		#ignore . and ..
  		if (-l $fullPath){

		}elsif (-d $fullPath and ($item eq '.' or $item eq '..') ){

			#item is a directory
		}elsif (-d $fullPath and ($item ne '.' and $item ne '..') ){
    		scanDir($fullPath);

		}

	}
	closedir(IMD);

}



#
#
#
sub scanDir2($){

	my $directory = shift;
	$dirCount++;
	print STDERR 'Scanning dir '.$directory."\n";
	opendir(IMD, $directory) || die("Cannot open directory");
	my @dirContents = readdir(IMD);

	my %fileMD5;

	#scan MD5 files
	foreach my $item (@dirContents){
		if ($item =~ m%^\..*\.[^\.]{32}$%){
	    	my ($file,$md5) = $item =~ m%^\.(.*)\.([^\.]{32})$%;
	    	print STDERR "MD5 = $item, $file $md5\n" if (DEBUG);
	    	$fileMD5{$file} = $md5;
	    	if ($checkDuplicates or $compareDrives){
				$duplicateMD52{$md5}[0]++;
				$duplicateMD52{$md5}[1] .= $directory . '/'.$file ."\n";
				$duplicateMD52{$md5}[2] = (-s $directory . '/'.$file);
				$duplicateMD52{$md5}[3] .= '#REMrm "'.$directory . '/'.$file ."\"\n";
				$duplicateMD52{$md5}[3] .= "#REMrm \"$directory/.$file.$md5\"\n";

			}
		}

	}

	#scan files [skip dirs] (non-MD5)
	foreach my $item (@dirContents){
		my $item_fixed = $item;
		$item_fixed =~ s%\`%\\\`%g;
		my $fullPath = $directory . '/' . $item;
		my $fullPath_fixed =  $directory . '/' . $item_fixed;

		#ignore . and ..
		#item is a symlink (skip)
		#print STDERR "checking . " . $item . "\n";
		if (-l $fullPath){

		}elsif (-d $fullPath){

		#is a MD5 checksum file; skip
		}elsif (-z $fullPath and $item =~ m%\.[^\.]+\.[^\.]{32}$%){
			$MD5Count++;
			#print STDERR "skip MD5 file = " . $item . "\n"  if (DEBUG);

		#isForce -  item is a file and a MD5 file exists - check MD5
		}elsif ($isForce and -f $fullPath and $fileMD5{$item} ne ''){
			$fileCount++;
			open (MD5, "md5sum \"$fullPath_fixed\" |");
			my @md5 = split(' ', <MD5>);
			if ($md5[0] ne ''){
				#same MD5
				if ($md5[0] eq $fileMD5{$item}){
					print STDERR '.';
				}elsif ($md5[0] eq $fileMD5{$item}){
					print STDERR "** different MD5, " . $item . ', original MD5 = ' . $fileMD5{$item} .' new MD5 = '.$md5[0]."\n";
				}
			}

		#a MD5 file exists
		}elsif (!$isForce and -f $fullPath and $fileMD5{$item} ne ''){
			$fileCount++;
			print STDERR "skip (MD5 exists) = " . $item . "\n" if ($isVerbose);

		#item is a file and no MD5 file exists
		}elsif (-f $fullPath){
			$fileCount++;
			open (MD5, "md5sum \"$fullPath_fixed\" |");
			my @md5 = split(' ', <MD5>);
			if ($md5[0] ne ''){
				print STDERR "file = " . $item . ',' . $md5[0] ."\n" if ($isVerbose);

				`touch "$directory/.$item_fixed.$md5[0]"`;
				if ($checkDuplicates or $compareDrives){
					$duplicateMD52{$md5[0]}[0]++;
					$duplicateMD52{$md5[0]}[1] .= $fullPath ."\n";
					$duplicateMD52{$md5[0]}[2] = (-s $fullPath);
					$duplicateMD52{$md5[0]}[3] .= '#REMrm "'.$fullPath ."\"\n";
					$duplicateMD52{$md5[0]}[3] .= "#REMrm \"$directory/.$item.$md5[0]\"\n";
				}
			}

		}else{
			$errCount++;
			#unhandled
			print STDERR "unhandled = " . $fullPath . "\n";
		}

	}


	#scan dirs
	foreach my $item (@dirContents){
		my $fullPath = $directory . '/' . $item;
		#ignore . and ..
		if (-l $fullPath){

		}elsif (-d $fullPath and ($item eq '.' or $item eq '..') ){

		#item is a directory
		}elsif (-d $fullPath and ($item ne '.' and $item ne '..') ){
			scanDir2($fullPath);

		}

	}
	closedir(IMD);

}
