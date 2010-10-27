# Author: Ben Nagy
# Copyright: Copyright (c) Ben Nagy, 2006-2010.
# License: The MIT License
# (See README.TXT or http://www.opensource.org/licenses/mit-license.php for details.)

require File.dirname(__FILE__) + '/../bm2-core/fuzz_server_new'
require 'rubygems'
require 'trollop'

OPTS = Trollop::options do 
    opt :debug, "Turn on debug mode", :type => :boolean
    opt :poll_interval, "Poll Interval (default 60)", :type=>:integer, :default=>60
    opt :dbq_max, "Max depth of outgoing queue to DB (default 200)", :type=>:integer, :default=>200
end

class WordFuzzServer < FuzzServer
    # Nothing overloaded here, currently.
end

# Anything not set up here gets the default value.
WordFuzzServer.setup 'debug'=>OPTS[:debug], 'poll_interval'=>OPTS[:poll_interval], 'dbq_max'=>OPTS[:dbq_max]

EM.epoll
EM.set_max_timers(1000000)
EventMachine::run {

    # Dump some status info every now and then using leet \r style.
    EM.add_periodic_timer(20) do 
        @summary=WordFuzzServer.lookup[:summary]
        @old_time||=Time.now
        @old_total||=@summary['total']
        @total=@summary['total']
        #print "\rconns: #{EventMachine.connection_count}, "
        print "\rDBQ: #{WordFuzzServer.queue[:db_messages].size}, "
        print "Done: #{@total} ("
        print "S/F/C: #{@summary['success']} / "
        print "#{@summary['fail']} / "
        print "#{@summary['crash']}), "
        print "Speed: #{"%.2f" % ((@total-@old_total)/(Time.now-@old_time).to_f)}  "
        print "Timers #{EM.instance_variable_get(:@timers).size}"
        @old_total=@summary['total']
        @old_time=Time.now
    end

    EventMachine::start_server(WordFuzzServer.listen_ip, WordFuzzServer.listen_port, WordFuzzServer)
}
