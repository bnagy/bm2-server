# Author: Ben Nagy
# Copyright: Copyright (c) Ben Nagy, 2006-2010.
# License: The MIT License
# (See README.TXT or http://www.opensource.org/licenses/mit-license.php for details.)

require File.dirname(__FILE__) + '/../bm2-core/fuzz_server_new'

# Used for testing. Passes the 'dummy' option to the FuzzServer class.
# See that class for details, but basically it doesn't deliver to the
# fuzzbots and just returns 'success'
#
# Equivalent DUMMY components exist for everything, so that you can isolate
# performance issues, do speed testing etc.
#
# It would probably be easier to just add a command line option to the
# real word_fuzzserver.rb code, now, but this file completes a set.

class WordFuzzServer < FuzzServer
end

# Anything not set up here gets the default value.
WordFuzzServer.setup 'debug'=>false, 'poll_interval'=>60, 'dbq_max'=>200, 'dummy'=>true

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
