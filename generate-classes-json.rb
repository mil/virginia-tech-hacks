#!/usr/bin/ruby
# Fetches all Virginia Tech classes from the timetable and spits them out into a nice JSON object
# Can be run with option of which file to save output to or will save to classes.json by default
require 'rubygems'
require 'mechanize'
require 'nokogiri'
require 'json'

#Create Mechanize Browser and Class Data hash to load data into
agent = Mechanize.new
classData = Hash.new

#Get Subjects from Timetable page
page = agent.get("https://banweb.banner.vt.edu/ssb/prod/HZSKVTSC.P_ProcRequest")
subjects = page.forms.first.field_with(:name => 'SUBJ_CODE').options

#Loop subjects
subjects.each do |subject|

	#Get the Timetable Request page & Form
	timetableSearch = agent.get("https://banweb.banner.vt.edu/ssb/prod/HZSKVTSC.P_ProcRequest")
	searchDetails = page.forms.first

	#Submit with specific subject 
	searchDetails.set_fields({
		:SUBJ_CODE => subject,
		:TERMYEAR => '201201',
		:CAMPUS => 0
	})

	#Submit the form and store results into courseListings
	courseListings = Nokogiri::HTML(
		searchDetails.submit(searchDetails.buttons[0]).body
	)

	#Create Array in Hash to store all classes for subjects
	classData[subject] = [] 
	
	#For every Class
	courseListings.css('table.dataentrytable/tr').collect do |course|

		subjectClassesDetails = Hash.new
	  
	  	#Map Table Cells for each course to appropriate values
	  	[
			[ :crn, 'td[1]/p/a/b/text()'],
			[ :course, 'td[2]/font/text()'],
			[ :title, 'td[3]/text()'],
			[ :type, 'td[4]/p/text()'],
			[ :hrs, 'td[5]/p/text()'],
			[ :seats, 'td[6]/text()'],
			[ :instructor, 'td[7]/text()'],
			[ :days, 'td[8]/text()'],
			[ :begin, 'td[9]/text()'],
			[ :end, 'td[10]/text()'],
			[ :location, 'td[11]/text()'],
		#	[ :exam, 'td[12]/text()']
	  	].collect do |name, xpath|
		  	#Not an additional time session (2nd row)
		  	if (course.at_xpath('td[1]/p/a/b/text()').to_s.strip.length > 2)
		    	subjectClassesDetails[name] = course.at_xpath(xpath).to_s.strip
		    end
	  	end
		
		#Add class to Array for Subject!
		classData[subject].push(subjectClassesDetails)
	end
end

#Write Data to JSON file
open(ARGV[0] || "classes.json", 'w') do |file| 
	file.print JSON.pretty_generate(classData)
end
