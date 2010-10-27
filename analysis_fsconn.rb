# Author: Ben Nagy
# Copyright: Copyright (c) Ben Nagy, 2006-2010.
# License: The MIT License
# (See README.TXT or http://www.opensource.org/licenses/mit-license.php for details.)
 
# This module acts as a client to the FuzzServer code, it connects in and sends a
# db_ready singal, then waits for results. For crashes that needs to be traced, it
# has hooks to connect to a TraceServer via a reference to the parent class, by putting
# data directly onto the queues or firing callbacks.
#
# That part isn't implemented, yet.
#
# To be honest, if you don't understand this part, (which is completely fair) 
# you're better off reading the EventMachine documentation, not mine.

require 'zlib'
require 'digest/md5'

class FuzzServerConnection < HarnessComponent

    VERSION="3.5.0"
    COMPONENT="DB:FSConn"
    DEFAULT_CONFIG={
        'poll_interval'=>60,
        'debug'=>false,
        'server_ip'=>'127.0.0.1',
        'server_port'=>10001,
        'work_dir'=>File.expand_path('~/analysisserver')
    }

    def self.setup( *args )
        super
        @dummy_db_counter=0
        @salt=(0..4).map {|e| (rand(26)+0x41).chr }.join
        meta_def :dummy_db_counter do @dummy_db_counter end
        meta_def :salt do @salt end
    end

    def post_init
        # We share the template cache and the trace message queue
        # with the AnalysisServer. All we do from here is keep the
        # template cache up to date and write onto the trace_msg_q.
        @trace_msg_q=self.class.parent_klass.queue[:trace_msgs]
        @template_cache=self.class.parent_klass.lookup[:template_cache]
        @db=self.class.db
        @counter=self.class.dummy_db_counter
        @salt=self.class.salt
        start_idle_loop( 'verb'=>'db_ready' )
    end

    def add_to_trace_queue( encoded_crashfile, template_hash, db_id, crc32 )
        return # until this is fully implemented
        msg_hsh={
            'verb'=>'trace',
            'template_hash'=>template_hash,
            'crashfile'=>encoded_crashfile,
            'crc32'=>crc32,
            'db_id'=>db_id
        }
        unless @trace_msg_q.any? {|hsh| hsh['db_id']==db_id}
            @trace_msg_q << msg_hash
        end
    end

    def write_crash_details( crashfile, crashdetail, counter, tag )
        crash_uuid=tag.match(/^FUZZBOT_CRASH_UUID:(.*)$/)[1]
        raise RuntimeError unless crash_uuid
        crashdetail_path=File.join( self.class.work_dir, "#{crash_uuid}.txt")
        crashfile_path=File.join( self.class.work_dir, "#{crash_uuid}.raw")
        crashtag_path=File.join( self.class.work_dir, "#{crash_uuid}.tag")
        if File.exists?( crashdetail_path) || File.exists?( crashfile_path ) || File.exists?( crashtag_path )
            File.open("analysisfsconn_error.log", "wb+") {|io| io.puts tag; io.puts crashdetail_path }
            raise RuntimeError, "#{COMPONENT}: Error - was about to clobber an existing file!!"
        end
        tag << "ANALYSIS_MD5:#{Digest::MD5.hexdigest(crashfile)}\n"
        tag << "ANALYSIS_TIMESTAMP:#{Time.now}\n"
        # Here is where you would also connect to a DB, if you want to
        # do DB pushes as part of the workflow (instead of doing it later)
        File.open(crashdetail_path, 'wb+') {|fh| fh.write crashdetail}
        File.open(crashfile_path, 'wb+') {|fh| fh.write crashfile}
        File.open(crashtag_path, 'wb+') {|fh| fh.write tag}
        tag
    end

    def handle_test_result( msg )
        cancel_idle_loop
        if msg.result=='crash'
            if Zlib.crc32(msg.crashfile)==msg.crc32
                @counter+=1
                if msg.tag =~ /REPRO/
                    # check tags with old msg, bin appropriately.
                    # NOT IMPLEMENTED
                else
                    add_to_trace_queue( msg.crashfile, @counter, msg.crc32, msg.tag)
                    tag=write_crash_details( msg.crashfile, msg.crashdetail, @counter, msg.tag )
                    send_ack( msg.ack_id, 'db_id'=>@counter, 'tag'=>tag )
                    # send to repro client
                    # NOT IMPLEMENTED
                end
            else
                raise RuntimeError, "#{COMPONENT}: CRC32 mismatch in crashfile!"
            end
        else
            @counter+=1 # Stands in for the real DB id
            send_ack( msg.ack_id, 'db_id'=>@counter, 'tag'=>msg.tag )
        end
        start_idle_loop( 'verb'=>'db_ready' )
    end

    def receive_data( data )
        cancel_idle_loop
        super
    end
end

