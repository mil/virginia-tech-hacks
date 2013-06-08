#!/usr/bin/env ruby
require 'rubygems'
require 'mechanize'
require 'nokogiri'

#Change these
stops = {
  "home"   => [ ["PRG", "1333"],  ["UCB", "1323"], ["TC",  "1313"] ],
  "campus" => [ ["TC",  "1100"],  ["UCB", "1101"], ["PRG", "1101"] ]
}
location = ARGV[0] || ((%x[sudo iwlist scan 2>&1].match(/(VT_WLAN|VT-Wireless)/)) ? "campus" : "home")

def startMatch(input, list)
  list.each do |item|
    if item.match(/^#{input}/) then
      return item
    end
  end
end

#Get next stop time for given route and stop
def getNextTime(route, stop)
  agent = Mechanize.new
  agent.redirect_ok = false

  begin
    #Send Route
    page = agent.get("http://www.bt4u.org/Mobile.aspx")

    routeName = startMatch(
      route,
      page.forms.first.field_with(:id => "routeListBox").options.map { |o| o.value }
    )
    page.forms.first.set_fields({ "routeListBox" => routeName })
    page = page.forms.first.submit(page.forms.first.buttons[0])

    #Send Stop Id
    stopName = startMatch(
      stop,
      page.forms.first.field_with(:id => "stopListBox").options.map { |o| o.value }
    )
    page.forms.first.set_fields({ "stopListBox" => stopName})
    page = page.forms.first.submit(page.forms.first.buttons[0])

    #Parse and Return Next Bus
    return Nokogiri::HTML(page.body).css('#repeaterItems_DepartureTime_0').text().split(': ').last

  rescue Exception => e
    return false
  end
end

#Run get next time until we find a stop
yourStop = "N/A", stopTime = "N/A"
catch :busStopFound do

  stops[location].each do |stop|
    yourStop = stop
    stopTime = getNextTime(stop[0], stop[1]) || "N/A"
    throw :busStopFound unless stopTime == "N/A" 
  end

end

puts "#{yourStop.join} at #{stopTime}"
