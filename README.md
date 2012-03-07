Virginia Tech Hacks
===================
This is a collection of small scripts I've made while at Virginia Tech. Enjoy the scripts and feel free to modify them and redistribute.

Request Stalk (request-stalk.pl)
--------------------------------
A script which stalks the Virginia Tech classes time table and when a course becomes available it automatically registers you for that class. Use at your own discretion.

Scholar Grades (scholar-grades.rb)
----------------------------------
A prompt-menu type CLI for getting your grades from Scholar. 

Blacksburg Transit (blacksburg-transit.rb)
------------------------------------------
Gets the next bus stop for the Blacksburg transit given a list of pre-determined stops. 

Essentially this just scrapes the bt4u.org service. This is a nice script to throw in a pipe menu or a status bar. (or just use standalone!)

Usage:
    > ruby blackburg-transit.rb home
Stops used can be changed by editing the script directly by modifying the **stops** variable. For my own personal use I've specified the stops I've listed under campus to be used when VT_WLAN or VT_Wireless is not present otherwise the home stops are used.
    

Generate Classes JSON (generate-classes-json.rb)
------------------------------------------------
Scrapes the entire timetable of classes and feeds into a JSON file. If you're looking to work directly with the timetable data this is your best bet. Produces about a ~2MB file. 
