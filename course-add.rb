#!/usr/bin/ruby
require 'mechanize'
require 'nokogiri'
require 'stringio'
require 'highline/import'

#Change based on Semester
$term = '09'
$year = '2012'

$agent = Mechanize.new
$agent.redirect_ok = true 
$agent.user_agent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_6_8) AppleWebKit/535.19 (KHTML, like Gecko) Chrome/18.0.1025.11 Safari/535.19"
$agent.verify_mode = OpenSSL::SSL::VERIFY_NONE

#Uber simway to colorize outputin
class String
	def color(c)
		colors = { 
			:black   => 30, 
			:red     => 31, 
			:green   => 32, 
			:yellow  => 33, 
			:blue    => 34, 
			:magenta => 35, 
			:cyan    => 36, 
			:white   => 37 
		}
		return "\e[#{colors[c] || c}m#{self}\e[0m"
	end
end

#Logins, Gets the Courses, Returns Courses Obj with Name/URL/Tools for each
def login(username, password)

	#Login to the system!
	page = $agent.get("https://auth.vt.edu/login?service=https://webapps.banner.vt.edu/banner-cas-prod/authorized/banner/SelfService")
	login = page.forms.first
	login.set_fields({
		:username => username, 
		:password => password
	})
	if (login.submit().body.match(/Invalid username or password/)) then
		return false
	else
		return true
	end
end

#Gets Course Information
def getCourse(crn)	
	courseDetails = Nokogiri::HTML( $agent.get(
		"https://banweb.banner.vt.edu/ssb/prod/HZSKVTSC.P_ProcComments?CRN=#{crn}&TERM=#{$term}&YEAR=#{$year}"
	).body)

	#Flatten table to make it easier to work with
	course = {}
	dataSet = false

	course[:title] = courseDetails.css('td.title').last.text.gsub(/-\ +/, '')
	course[:crn] = crn

	courseDetails.css('table table tr').each_with_index do |row|
		#If we have a dataSet
		case dataSet
			when :rowA
				[ :i, :days, :end, :begin, :end, :exam].each_with_index do |el, i|
					if row.css('td')[i] then
						course[el] = row.css('td')[i].text
					end
				end
			when :rowB
				[ :instructor, :type, :status, :seats, :capacity ].each_with_index do |el, i|
					course[el] = row.css('td')[i].text
				end
		end

		dataSet = false
		#Is there a dataset?
		row.css('td').each do |cell|
			case cell.text
				when "Days"
					dataSet = :rowA
				when "Instructor"
					dataSet = :rowB
			end
		end
	end

	return course
end

#Registers you for the given CRN, returns true if successful, false if not
def registerCrn(crn)
	#Follow Path
	$agent.get("https://banweb.banner.vt.edu/ssb/prod/twbkwbis.P_GenMenu?name=bmenu.P_MainMnu")
	reg = $agent.get("https://banweb.banner.vt.edu/ssb/prod/hzskstat.P_DispRegStatPage")
	dropAdd = reg.link_with(:href => "/ssb/prod/bwskfreg.P_AddDropCrse?term_in=#{year}#{term}").click

	#Fill in CRN Box and Submit
	crnEntry = dropAdd.form_with(:action => '/ssb/prod/bwckcoms.P_Regs')
	crnEntry.fields_with(:id => 'crn_id1').first.value = crn
	crnEntry['CRN_IN'] = crn
	add = crnEntry.submit(crnEntry.button_with(:value => 'Submit Changes')).body

	if add =~ /#{crn}/ && !(add =~ /Registration Errors/) then
		return true
	else
		return false
	end
end

#Main loop that checks the availaibility of each courses and fires to registerCrn on availaibility
def checkCourses(courses)
	
	loop do
		system("clear")

		puts "Checking Availaibility of CRNs\n".color(:yellow)

		courses.each_with_index do |c, i|

			puts "#{c[:crn]} - #{c[:title]}".color(:blue) 
			course = getCourse(c[:crn])	
			puts "Availaibility: #{course[:seats]} / #{course[:capacity]}".color(:red)

			if (course[:seats] =~ /Full/) then
			else 
				if (registerCrn(c[:crn])) then
					puts "CRN #{c[:crn]} Registration Sucessfull"
					courses.slice!(i)

				else
					puts "Couldn't Register"
				end

			end

			print "\n"
		end

		sleep 4
	end
end

#Add courses to be checked
def addCourses 
	crns = []

	loop do 
		system("clear")
		puts "Your CRNs:".color(:red)
		crns.each do |crn|
			puts "  -> #{crn[:title]} (CRN: #{crn[:crn]})".color(:magenta)
		end

		#Prompt for CRN
		alt = (crns.length > 0)  ? " (or just type 'start') " : " "
		input = ask("\nEnter a CRN to add it#{alt}".color(:green) + ":: ") { |q| q.echo = true }

		#Validate CRN to be 5 Digits 
		if (input =~ /^\d{5}$/) then
		
			#Display CRN Info
			c = getCourse(input.to_s)
			puts "\nCourse: #{c[:title]} - #{c[:crn]}".color(:red)
			puts "--> Time: #{c[:begin]}-#{c[:end]} on #{c[:days]}".color(:cyan)
			puts "--> Teacher: #{c[:instructor]}".color(:cyan)
			puts "--> Type: #{c[:type]} || Status: #{c[:status]}".color(:cyan)
			puts "--> Availability: #{c[:seats]} / #{c[:capacity]}\n".color(:cyan)

			#Add Class Prompt
			add = ask("Add This Class? (yes/no)".color(:yellow) + ":: ") { |q| q.echo = true }
			crns.push(c) if (add =~ /yes/)

		elsif (input == "start") then
			checkCourses(crns)
		end 
	end
end


def main
	system("clear")
	puts "Welcome to CourseAdd by mil".color(:blue)

	username = ask("PID ".color(:green) + ":: ") { |q| q.echo = true }
	password = ask("Password ".color(:green) + ":: " ) { |q| q.echo = "*" }

	system("clear")
	if login(username, password) then
		addCourses
	else
		puts "Invalid PID/Password"
		exit
	end
end

main
