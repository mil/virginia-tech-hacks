#!/usr/bin/perl
use strict;
use WWW::Mechanize;
use Term::ReadKey;
use HTTP::Cookies;
use Crypt::SSLeay;
use HTML::TreeBuilder;
use HTML::TreeBuilder::XPath;
use Switch;

#This is Dependant on Semseter/Year
my $year = "2012"; #Semester Begins in Year
my $month = "01"; # Semester Begins in Month
my $termYear = $year . $month;

#Number of Seconds between each request
my $sleepDelay = 3;


&clearScreen();

#Intro
print <<INTRO;
---------------
Course Request Stalk
By mil- 
---------------
This Script leaves you logged into Hokie Spa(Banner System) to monitor a
desired CRN's availablity and then registers you for the class the instant
it becomes available.

Logging into Hokie Spa while this script is running will kill this script.
---------------
INTRO

#Username / Password
print "PID(w/o \@vt.edu):";
chomp(my $pid = <STDIN>);
print "Password:";
ReadMode('noecho');
chomp(my $password = <STDIN>);
ReadMode(0);
print "\n";

#Create Mechanize Object
my $mech = WWW::Mechanize->new();
$mech->cookie_jar(HTTP::Cookies->new);
$mech->default_header( Cache_Control => "no-cache" );
$mech->agent_alias( 'Windows IE 6' );


#Login to VT Bannerweb System
$mech->get('https://banweb.banner.vt.edu/ssb/prod/twbkwbis.p_wwwlogin');
$mech->submit_form(
	form_number => 2,
	fields => {
		pid   => $pid, 
		password    => $password
	}
); 

#Validate Username/password
if ($mech->text()) {
	print "Login Failed\nInvalid PID/Password Combo\n";
	exit;
} else {
	print "Successfull Login\n";
}

print "---------------\n";


#Query CRN
print "CRN:";
chomp(my $crn = <STDIN>);

print "---------------\n";

#Search for CRN
$mech->get('https://banweb.banner.vt.edu/ssb/prod/HZSKVTSC.P_DispRequest?term=' . $month . '&year=' . $year);

$mech->submit_form(
	form_number => 2,
	fields => {
		TERMYEAR   => $termYear, 
		crn    => $crn,
	}); 

#Avoid Javascript bs, Find link and parse out important parts
my $crnLink = $mech->find_link( text_regex => qr/$crn/ ) or die("Invalid CRN!");

#Request Info parsing
my $requestInfo = (split(
		/\&history=/,
		(split(
				/ProcComments\?/,
				$crnLink->url_abs()	
			))[1]
	))[0];

#Course Dpt/# parsed out of requestInfo
my ($courseDept, $courseNumber) = split(
	/\&CRSE=/, 
	(split(
			/SUBJ=/,
			$requestInfo
		))[1]
);


print "Course Dept:" . $courseDept . "\nCourse Number:" . $courseNumber . "\n";
my $courseId = $courseDept . "-" . $courseNumber;

#Check class / Show Info
&checkClass();

#Wait for Confirmation
print "Stalk Class - Press Any Key to Continue:";
<STDIN>;

#This fuction won't return until class is available
&stalkClass();

#Made it to this point, stalkClass passed, register for class
&registerClass();

sub stalkClass() {
	#And the Stalking Begins
	my $continue = 1;
	my $queryCount = 0;
	my $initDate = localtime time;
	my $currentDate = localtime time;

	#Main Loop to check for class until it becomes avail
	while ($continue) {

		$queryCount++;
		&clearScreen();
		$currentDate = localtime time;

		print <<STATUS;
Stalking CRN:$crn | Logged in as: $pid | Query: $queryCount
Started at $initDate | Current Request: $currentDate
---------------
STATUS

		$continue = &checkClass();
		sleep($sleepDelay);
	}

	return;
}



#Subroutine Checks CRN, if full return 1, if spots avail return 0
sub checkClass() {
	#Make Retrival of the status page non-fatal	
	eval {
		$mech->get('https://banweb.banner.vt.edu/ssb/prod/HZSKVTSC.P_ProcComments?' . $requestInfo);
	}; warn $@ if $@;

	my $courseTitle = (split(
			/\<\/TD\>/,
			(split(
					/$courseId/,
					$mech->content()
				))[1]
		))[0];

	$courseTitle =~ s/^\s+//ig;

	print "Course Name: " . $courseTitle . "\n";


	#Parsing HTML
	my $tree = HTML::TreeBuilder->new_from_content($mech->content());
	$tree->parse($tree);
	my @dataso = $tree->look_down(
		sub{ $_[0]-> tag() eq 'td' and ($_[0]->attr('class') =~ /mpdefault/)}
	);
	my $loopCount = 0;
	my $part = 1;
	my ($days, $startTime, $endTime, $location, $professor, $classType, $registration, $seatsCurrent, $seatsCapacity);
	foreach my $temp (@dataso) {
		$loopCount++;
		my $valueData = $temp->as_text;
		if ($valueData =~ /additional times/ig) {
			$loopCount = 1;
		}
		switch($loopCount) {
			case 2 { $days = $valueData; }
			case 3 { $startTime = $valueData; }
			case 4 { $endTime = $valueData; }
			case 5 { $location = $valueData; }
			case 8 { $professor = $valueData; }
			case 9 { $classType = $valueData; }
			case 10 { $registration = $valueData; }
			case 11 { $seatsCurrent = $valueData; }
			case 12 { $seatsCapacity = $valueData; }
			else { }
		}
	}

	print "Days: " . $days . "\n";
	print "Time: " . $startTime . "-" . $endTime . "\n";
	print "Location: " . $location . "\n";
	print "Professor: " . $professor . "\n";
	print "Type of Class " . $classType . "\n";
	print "Registration Status: " . $registration . "\n";
	print "Availability: $seatsCurrent / $seatsCapacity \n";

	print "---------------\n";
	$tree->delete();
	if ($seatsCurrent =~ /full/ig) {
		return 1;
	} else {
		return 0;
	}
}

sub registerClass() {

	#Course is Available, Request Drop/Add Page Set Form, Enter CRN and Submit
	$mech->get('https://banweb.banner.vt.edu/ssb/prod/bwskfreg.P_AddDropCrse?term_in=' . $termYear);
	$mech->form_number(2);
	$mech->set_visible([text => $crn]);
	$mech->click_button(value => 'Submit Changes');


	#Success
	if (!($mech->content() =~ /registration errors/ig)) {
		print "Congrats\nYou are now registered for CRN $crn - $courseId\n";
		<STDIN>;
	} else {
		print "Error: Unable to register for CRN $crn for some reason, try going through your browser, it should be available";
	}

}


sub clearScreen() {
	#Use cls for Win32, clear for Unix
	system $^O eq 'MSWin32' ? 'cls' : 'clear';
}
