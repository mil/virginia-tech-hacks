#!/usr/bin/ruby
require 'mechanize'
require 'nokogiri'
require 'json'
require 'stringio'
require 'highline/import'

#Create the agent
@agent = Mechanize.new
@agent.redirect_ok = true 
@agent.user_agent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_6_8) AppleWebKit/535.19 (KHTML, like Gecko) Chrome/18.0.1025.11 Safari/535.19"


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


def main

	#Prompt and Store User/Pass
	username = ask("Username".color(:green) + ": ") { |q| q.echo = true }
	password = ask("Password".color(:green) + ": " ) { |q| q.echo = "*" }

	#Login
	cookieJar = login(username,password)
	courses = getCourses(cookieJar)

	#Show Available Courses
	print "\n"
	courses.each_with_index do |course, index|
		puts "#{index.to_s.color(:red)} #{course["name"].color(:blue)}"
	end

	#Prompt to Pick a Course
	print "\nCourse Name or #: ".color(:green)
	courseSelector = gets.chomp!

	#Fetch the gRadebook
	course, gradebook = getGrades(courses, cookieJar, courseSelector) 

	#Course Name
	puts "\n#{course.color(:magenta)}\n"

	#Loop through Grades in Gradbook
	gradebook.each do |category, grades|

		puts "#{category}".color(:red).color(4)

		grades.each_with_index do |grade, index|
			print "#{grade[:assignment].color(:blue)}\t"
			print "[#{grade[:pointsScored].color(:green).color(4)}/"
			print "#{grade[:pointsAvailable].color(:blue)}]\t"
			print "#{grade[:weight].color(:yellow)}\n"
		end
		print "\n"
	end	

end

def loadCookies(cookieJar)
	@agent.cookie_jar.load_cookiestxt(cookieJar)
end

#Unload's cookies to a variable returned
def unloadCookies
	#Store the Coories 
	cookieJar = StringIO.new
	@agent.cookie_jar.dump_cookiestxt(cookieJar)
	@agent.cookie_jar.clear!

	return cookieJar.string
end


#Logins, Gets the Courses, Returns Courses Obj with Name/URL/Tools for each
def login(username, password)

	#Login to the system!
	page = @agent.get("https://scholar.vt.edu/portal/login")
	login = page.forms.first

	login.set_fields({
		:username => username, 
		:password => password 
	})
	login.submit().body

	return unloadCookies
end

#Get courses given a cookiejar
def getCourses(cookieJar)
	loadCookies(cookieJar)

	#Get Scholar Site
	scholar = Nokogiri::HTML(@agent.get("https://scholar.vt.edu/portal/site").body)
	courses = []

	#Store Courses URLs
	scholar.css('#siteLinkList a').collect do |course|
		courses.push({
			"name" => course.text,
			"url" => course.get_attribute("href"),
			"tools" => {}
		}) unless course.text == "My Workspace"
	end

	#Store Tool URLS
	courses.each do |course|
		Nokogiri::HTML(
			@agent.get(course["url"]).body
		).css("#toolMenu a").each do |tool|
			course["tools"][tool.text] = tool.get_attribute("href")
		end
	end

	unloadCookies
	return courses
end

#Get grades for a specific class given a cookie jar
def getGrades(courses, cookieJar, classSelector)

	loadCookies(cookieJar)

	#Figure out what Class were getting grades for
	course = false	

	#Course Number was passed 
	if classSelector.match(/^[0-9]+$/) then 
		course = courses[classSelector.to_i]
	else 
		course = courses.select do |c| 
			c["name"].match(classSelector) 
		end
	end


	#Setup Return Grades Hash
	returnGrades = {}

	#Get URL base of gradebook based on iframe and format to REST JSON Path
	gradebookFrame = Nokogiri::HTML(@agent.get(course["tools"]["Gradebook"]).body)
	gradebook = gradebookFrame.css('iframe')[0].get_attribute("src")
	gradebook.gsub!(/\?.+$/, "/gradebook/rest/application/")

	#Get Grades JSON and parse, get User Grades Json as well
	gradesJson = JSON.parse(@agent.get(gradebook).body)
	userGrades = gradesJson["A_GB_MODELS"][0]["M_USER"]

	#Loop through each category and enter each grade into returnGrades
	gradesJson["A_GB_MODELS"][0]["M_GB_ITM"]["A_CHILDREN"].each do |category|
		#If Cateogry is single object
		if (!category["A_CHILDREN"]) then category["A_CHILDREN"] = [category] end

		#Category name create and create entry in return grades
		categoryName = category["A_CHILDREN"][0]["S_PARENT"]
		returnGrades[categoryName] = []

		#The actual assignment
		category["A_CHILDREN"].each do |entry|
			returnGrades[categoryName].push({
				:assignment      => entry["S_NM"].to_s,
				:pointsScored    => (userGrades[entry["S_ID"]] || "N/A").to_s,
				:pointsAvailable => entry["D_PNTS"].to_s,
				:weight          => entry["D_WGHT"].to_s
			})
		end
	end

	unloadCookies
	return course["name"], returnGrades
end

#Run
main
