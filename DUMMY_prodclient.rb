# Author: Ben Nagy
# Copyright: Copyright (c) Ben Nagy, 2006-2010.
# License: The MIT License
# (See README.TXT or http://www.opensource.org/licenses/mit-license.php for details.)

require 'rubygems'
require 'trollop'

# Used for testing, when you want to send a certain file over and over.
# Equivalent DUMMY components exist for everything, so that you can isolate
# performance issues, do speed testing etc.
class Producer < Generators::NewGen

    def initialize( args, prodclient_klass )
        @opts=Trollop::options( args ) do
            opt :template, "Template filename", :type=>:string, :required=>true
        end
        @template=File.open( @opts[:template] ,"rb") {|io| io.read}
        our_tag=""
        our_tag << "DUMMY_TEMPLATE:#{@opts[:template]}\n"
        our_tag << "DUMMY_TEMPLATE_MD5:#{Digest::MD5.hexdigest(@template)}\n"
        prodclient_klass.base_tag=prodclient_klass.base_tag << our_tag
        @block=Fiber.new do
            loop do
                # This will just send the template over and over. 
                # To actually fuzz, make changes and yield at each step.
                Fiber.yield @template
            end
            false
        end
        super
    end

end
