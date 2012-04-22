#!/usr/bin/ruby
require 'mechanize'
require 'nokogiri'
require 'stringio'
require 'highline/import'

#Start of the Semester
$term = '09'
$year = '2012'

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

#Creating Mechanize
@agent = Mechanize.new
@agent.redirect_ok = true 
@agent.user_agent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_6_8) AppleWebKit/535.19 (KHTML, like Gecko) Chrome/18.0.1025.11 Safari/535.19"


#Logins, Gets the Courses, Returns Courses Obj with Name/URL/Tools for each
def login(username, password)

	#Login to the system!
	page = @agent.get("https://auth.vt.edu/login?service=https://webapps.banner.vt.edu/banner-cas-prod/authorized/banner/SelfService")
	login = page.forms.first
	login.set_fields({
		:username => username, 
		:password => password
	})
	if (login.submit().body.match(/Invalid username or password/)) then
		return false
	else 
		return unloadCookies
	end
end

def loadCookies(cookieJar)
	@agent.cookie_jar.load_cookiestxt(cookieJar)
end


def unloadCookies
	#Store the Coories 
	cookieJar = StringIO.new
	@agent.cookie_jar.dump_cookiestxt(cookieJar)
	@agent.cookie_jar.clear!

	return cookieJar.string
end


def getCourse(crn, cookies)
	loadCookies(cookies)
		
	courseDetails = Nokogiri::HTML(
		@agent.get(
			"https://banweb.banner.vt.edu/ssb/prod/HZSKVTSC.P_ProcComments?CRN=#{crn}&TERM=#{$term}&YEAR=#{$year}"
		).body
	)


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

def registerCrn(crn, cookies)
	loadCookies(cookies)


	@agent.get("https://banweb.banner.vt.edu/ssb/prod/twbkwbis.P_GenMenu?name=bmenu.P_MainMnu")
	registrationPage = "https://banweb.banner.vt.edu/ssb/prod/hzskstat.P_DispRegStatPage"
	reg = @agent.get(registrationPage)	

	dropAdd = reg.link_with(:href => "/ssb/prod/bwskfreg.P_AddDropCrse?term_in=201209").click
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

def unRegisterCrn(crn, cookies)

end

#Main loop
def courseAdd(courses, cookies)
	
	loop do
		system("clear")

		puts "Checking Availaibility of CRNs\n".color(:yellow)

		courses.each_with_index do |c, i|

			puts "#{c[:crn]} - #{c[:title]}".color(:blue) 
			course = getCourse(c[:crn], cookies)	
			puts "Availaibility: #{course[:seats]} / #{course[:capacity]}".color(:red)

			if (course[:seats] =~ /Full/) then
			else 
				unloadCookies

				if (registerCrn(c[:crn],cookies)) then
					puts "CRN #{c[:crn]} Registration Sucessfull"
					courses.slice!(i)

				else
					puts "Couldn't Register"
				end

			end

			print "\n"
		end

		sleep 2
	end
end


def main
	system("clear")
	puts "Welcome to CourseAdd by mil".color(:blue)

	username = ask("PID ".color(:green) + ":: ") { |q| q.echo = true }
	password = ask("Password ".color(:green) + ":: " ) { |q| q.echo = "*" }

	cookies = login(username, password)

	system("clear")
	if cookies then
		puts "Login Successful\n--------------\n".color(:yellow)
	else
		puts "Invalid PID/Password"
		exit
	end
	

	crns = []


	loop do 

		system("clear")
		puts "Your CRNs:".color(:red)
		crns.each do |crn|
			puts "  -> #{crn[:title]} (CRN: #{crn[:crn]})"
		end

		if (crns.length > 0) then
			alt = " (or just type 'start') "
		else
			alt = " "
		end

		
		input = ask("\nEnter a CRN to add it#{alt}".color(:green) + ":: ") { |q| q.echo = true }

		if (input =~ /^\d{5}$/) then
			

			c = getCourse(input.to_s, cookies)


			print "\n"
			puts "Course: #{c[:title]} - #{c[:crn]}".color(:red)
			puts "--> Time: #{c[:begin]}-#{c[:end]} on #{c[:days]}".color(:cyan)
			puts "--> Teacher: #{c[:instructor]}".color(:cyan)
			puts "--> Type: #{c[:type]} || Status: #{c[:status]}".color(:cyan)
			puts "--> Availability: #{c[:seats]} / #{c[:capacity]}".color(:cyan)
			print "\n"

			add = ask("Add This Class? (yes/no)".color(:yellow) + ":: ") { |q| q.echo = true }
			if (add =~ /yes/) then 
				crns.push(c)
			end

		elsif (input == "start") then
			courseAdd(crns,cookies)
		else 
			puts "Invalid CRN, This is a 5 Digit Course Request Number"
			
		end
	end


end

main
