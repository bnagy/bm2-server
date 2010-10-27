# Author: Ben Nagy
# Copyright: Copyright (c) Ben Nagy, 2006-2010.
# License: The MIT License
# (See README.TXT or http://www.opensource.org/licenses/mit-license.php for details.)

require File.dirname(__FILE__) + '/../bm2-core/production_client'
require 'trollop'

OPTS = Trollop::options do 
    opt :producer, "File with .rb code implementing a Producer generator", :type => :string, :required=>true
    opt :debug, "Turn on debug mode", :type => :boolean
    opt :timeout, "Timeout before resending cases", :type=>:integer, :default=>60
    opt :memprofile, "Basic memory profiling at each status tick", :type=>:boolean
    opt :clean, "Run clean (new process for each test)", :type=>:boolean
    opt :filechain, "Save file chains (only applies when not running clean)", :type=>:boolean
    opt :maxchain, "Maximum file chain length - process will be restarted after this many tests", :type=>:integer, :default=>15
    opt :ignore, "Filename containing regexps matching 1st chance exceptions to ignore, one per line", :type=>:string
    opt :servers, "Filename containing servers (name or ip) to connect to, one per line", :type => :string
    stop_on 'opts'
end

ARGV.shift # to clear the 'opts' string, what remains is for the Producer class

# Load the producer script, it MUST define a Producer class, which acts like a Generator
require OPTS[:producer]

# Instantiate the test case generator, passing opts from the prodclient command line
ProductionClient.production_generator=Producer.new( ARGV, ProductionClient )

# Basic options for the prodclient
ProductionClient.setup( 
    'debug'=>OPTS[:debug],
    'poll_interval'=>OPTS[:timeout],
    'queue_name'=>'word'
)

# Set the fuzzbot options that will be passed through, based on the command line
ProductionClient.fuzzbot_options={
        'clean'=>OPTS[:clean], 
        'filechain'=>OPTS[:filechain],
        'maxchain'=>OPTS[:maxchain],
        'ignore_exceptions'=(OPTS[:ignore] ? File.open(OPTS[:ignore], "rb") {|io| io.read}.split : [])
}

EM.epoll
EM.set_max_timers(5000000)
EventMachine::run {

    @producer=File.basename(OPTS[:producer])
    @args=ARGV.join(' ')

    EM.add_periodic_timer(20) do 
        if OPTS[:memprofile]
            puts ObjectSpace.count_objects
            ProductionClient.queue[:bugs].shift until ProductionClient.queue[:bugs].empty?
        else
            @old_time||=Time.now
            @old_total||=ProductionClient.case_id
            @total=ProductionClient.case_id
            @results=ProductionClient.lookup[:results].to_a.map {|a| a.join(': ')}.join(', ')
            @classifications=ProductionClient.lookup[:classifications].to_a.map {|a| a.join(': ')}.join(', ')
            puts "#{@producer} + #{@args} => #{@total} @ #{"%.2f" % ((@total-@old_total)/(Time.now-@old_time).to_f)} #{@results} (#{ProductionClient.lookup[:buckets].keys.size}) #{@classifications}"
            until ProductionClient.queue[:bugs].empty?
                bug=ProductionClient.queue[:bugs].shift
                if bug=~/EXPLOITABLE/i
                    puts "#{@producer} + #{@args} BOOF! #{bug}"
                end
            end
            @old_total=@total
            @old_time=Time.now
        end
    end

    if OPTS[:servers]
        # Connect to all the servers in the file
        File.read( OPTS[:servers] ).each_line {|l|
            EventMachine::connect( l.chomp, ProductionClient.server_port, ProductionClient )
        }
    else
        # Connect to localhost
        EventMachine::connect(ProductionClient.server_ip,ProductionClient.server_port, ProductionClient)
    end
}
puts "Event loop stopped. Shutting down."
