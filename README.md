# PERL-DiskIntegrityCheckerAndDeduplicator
A handy script that will scan a whole disk, store MD5 marker files for each file, then can compare files to identify duplication.  Can be used to check the integrity of a disk and compare two disks together.
usage: dicad.pl -s source_directory [-t source_directory] [-l logfile] [-X dbmfile] [-I dbmfile [-d destination_path]] [-i size] [-f] [-v]
	-f force checksum calculation and validate against pre-existing
	-v verbose
	-D check for duplicates
	-X create duplicate exclusion list based on MD5 dbm file
	-I create duplicate inclusion list based on MD5 dbm file
		-d destination path
	-i ignore size (ignore files < this size)
