# Author: Ben Nagy
# Copyright: Copyright (c) Ben Nagy, 2006-2010.
# License: The MIT License
# (See README.TXT or http://www.opensource.org/licenses/mit-license.php for details.)

require File.dirname(__FILE__) + '/analysis_server'
require File.dirname(__FILE__) + '/analysis_fsconn'
require 'trollop'

OPTS = Trollop::options do 
    opt :crash_dir, "Directory to use for crash files and detail files", :type => :string, :required=>true
    opt :debug, "Turn on debug mode", :type => :boolean
end

EM.set_max_timers(1000000)
EM.epoll
EventMachine::run {
    # Anything not set up here gets the default value.
    AnalysisServer.setup( 'debug'=>OPTS[:debug] )
    FuzzServerConnection.setup( 'work_dir'=>OPTS[:crash_dir], 'debug'=>OPTS[:debug] )
    EventMachine::start_server(AnalysisServer.listen_ip, AnalysisServer.listen_port, AnalysisServer)
}
