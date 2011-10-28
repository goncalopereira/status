require 'rubygems'
require'sinatra'
require 'net/http'
require 'uri'
require 'faster_csv'

use Rack::Session::Pool

def get_request url, host_header
	uri = URI(url)
	http = Net::HTTP.new(uri.host, uri.port)
	path = uri.path.empty? ? "/" : uri.path
	query = uri.query.nil? ?  "" : "?" + uri.query	
	headers =  {"Host"  => host_header }
	puts "curl -v \"http://#{uri.host}#{path}#{query}\" -H \"Host: #{host_header}\""
	return http.get(path + query, headers)
end

FAILS = "fails"
TOTAL = "total"
AVERAGE_TIME = "average time"
AVERAGE_TIME_ATTEMPTS = "average time attempts"

def new_average_time server, latest_time
	total =	session[server + AVERAGE_TIME]
	if total.nil?
		total = 0
	end
	attempts = session[server + AVERAGE_TIME_ATTEMPTS]
	if attempts.nil?
		attempts = 0
	end
	
	total = total + latest_time
	attempts = attempts +1

	session[server + AVERAGE_TIME] = total
	session[server + AVERAGE_TIME_ATTEMPTS] = attempts

	total/attempts					
end

def get_total_hits server
	total = session[server + TOTAL]
	if total.nil?
		0
	else
		total
	end
end

def get_fails server
	fails = session[server + FAILS]
	if fails.nil?
		0
	else 
		fails
	end
end

def add_hit server
	total = get_total_hits server
	session[server + TOTAL] = total +1
end

def add_fail server
	fails = get_fails server
	session[server + FAILS] = fails+1
	add_hit server
end

get '/' do
	result = ""
	servers = []
	FasterCSV.foreach("status.txt", :quote_char => '"', :col_sep =>',', :row_sep =>:auto) do |row|
		servers << [row[0],[row[1],row[2]]]
	 end
	
	servers.each do |server|
		
		result = result + "<p>"
		begin
			
			time_before_request = Time.now	
			response = get_request(server[1][0],server[1][1])
			time_after_request = Time.now		
						
			if response.code == "200"		
				result = result + "#{server[0]}:"

 				time = time_after_request - time_before_request

	                        result = result + " Response Time: #{(time)}S"

        	                average_time = new_average_time(server[0],time)

                	        result = result + " Average Time: #{average_time}"
			
				add_hit server[0] 

			else
				result = result + "<b>#{server[0]}: Failed with code #{response.code}</b>"
				add_fail server[0]
			end
			
		rescue
	
			result = result + "<b>#{server[0]}: Couldn\'t reach server</b>"
			add_fail server[0]
		end

		total_hits = get_total_hits server[0]
		fails = get_fails server[0]

		uptime = ((total_hits.to_f-fails.to_f) / total_hits.to_f * 100).to_i
		puts "#{server[0]} total #{total_hits} fails #{fails}"
		result = result + " Uptime: #{uptime}%"
				
		result = result + "</p>"
	end
	
	
	result

end

