# Author: Ben Nagy
# Copyright: Copyright (c) Ben Nagy, 2006-2010.
# License: The MIT License
# (See README.TXT or http://www.opensource.org/licenses/mit-license.php for details.)

require 'rubygems'
require 'eventmachine'
require 'socket'
require File.dirname(__FILE__) + '/../bm2-core/fuzzprotocol'
require File.dirname(__FILE__) + '/../bm2-core/metafuzz_db'
require File.dirname(__FILE__) + '/analysis_fsconn'
require File.dirname(__FILE__) + '/../bm2-core/objhax'

# This class is a combination DB / analysis server. It connects out to a fuzzserver, to
# receive results and put them in the result database, and then also acts as a server for
# a group of trace clients that will do extra runtracing and analysis on any crashes.
# (that bit isn't fully implemented)
#
# To be honest, if you don't understand this part, (which is completely fair) 
# you're better off reading the EventMachine documentation, not mine.

# Handle connections from the tracebots in this class, as a server.
# the connection out to the FuzzServer as a client is handled in the 
# FuzzServerConnection class, but is set up with the same config, so
# it can access callback queues, the DB object and so on.
class AnalysisServer < HarnessComponent

    VERSION="3.0.0"
    COMPONENT="AnalysisServer"
    DEFAULT_CONFIG={
        'listen_ip'=>"0.0.0.0",
        'listen_port'=>10002,
        'poll_interval'=>20,
        'debug'=>false,
        'work_dir'=>File.expand_path('~/analysisserver'),
        'result_db_url'=>'postgres://becks/metafuzz_resultdb',
        'result_db_username'=>'postgres',
        'result_db_password'=>'db@dm1n',
        'trace_db_url'=>'postgres://becks/metafuzz_tracedb',
        'trace_db_username'=>'postgres',
        'trace_db_password'=>'db@dm1n',
        'server_ip'=>'127.0.0.1',
        'server_port'=>10001
    }

    def self.setup( config_hsh )
        super
        begin
            puts "Connecting to Result DB at #{result_db_url}..."
            @result_db=MetafuzzDB::ResultDB.new( result_db_url, result_db_username, result_db_password )
            meta_def :result_db do @result_db end
            #puts "Connecting to Trace DB at #{trace_db_url}..."
            #@trace_db=MetafuzzDB::TraceDB.new( trace_db_url, trace_db_username, trace_db_password )
            #meta_def :trace_db do @trace_db end
            fsconn_config={
                'server_ip'=>server_ip,
                'server_port'=>server_port,
                'poll_interval'=>poll_interval,
                'debug'=>debug,
                'work_dir'=>work_dir,
                'db'=>@result_db,
                'parent_klass'=>self
            }
            puts "Connecting out to FuzzServer at #{server_ip}..."
            FuzzServerConnection.setup( fsconn_config )
            EM::connect( server_ip, server_port, FuzzServerConnection )
        rescue
            puts $!
            EM::stop_event_loop
        end

    end

    def post_init
        # We share the trace_msg_q, the result_db and the template_cache
        # with the FuzzServerConnection, so those get written
        # there and read here.
        @ready_tracebots=self.class.lookup[:tracebots]
        @tb_conn_queue=self.class.queue[:tb_conns]
        @trace_msg_q=self.class.queue[:trace_msgs]
        @template_cache=self.class.lookup[:template_cache]
        @result_db=self.class.result_db
    end

    def handle_ack_msg
        stored_msg_hsh=super
    end

    def handle_template_request( msg )
        template_hash=msg.template_hash
        if template=@template_cache[template_hash]
            # good
        else
            template=@result_db.get_template( template_hash )
            @template_cache[template_hash]=template
        end
        send_ack(msg.ack_id, 'template'=>template)
    end

    # The trace_msg_q is populated in the FuzzServerConnection class.
    def handle_client_ready( msg )
        port, ip=Socket.unpack_sockaddr_in( get_peername )
        if @ready_tracebots[ip+':'+port.to_s] and @trace_msg_q.empty?
            if self.class.debug
                puts "(tracebot already ready, no messages in queue, ignoring.)"
            end
        else
            clientconn=EventMachine::DefaultDeferrable.new
            clientconn.callback do |msg_hash|
                send_message msg_hash, @trace_msg_q
                @ready_tracebots[ip+':'+port.to_s]=false
            end
            if @trace_msg_q.empty?
                @ready_tracebots[ip+':'+port.to_s]=true
                @tb_conn_queue << clientconn
            else
                clientconn.succeed @trace_msg_q.shift
            end
        end
    end

end
