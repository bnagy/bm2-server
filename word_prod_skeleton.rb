# Author: Ben Nagy
# Copyright: Copyright (c) Ben Nagy, 2006-2010.
# License: The MIT License
# (See README.TXT or http://www.opensource.org/licenses/mit-license.php for details.)

require 'rubygems'
require File.dirname(__FILE__) + '/../bm2-core/fuzzer'

# Skeleton for a Producer generator - this is the bit that actually does the case
# generation.
class Producer < Generators::NewGen

    def initialize( template_fname )
        @template=File.open( template_fname ,"rb") {|io| io.read}
        @duplicate_check=Hash.new(false)
        @block=Fiber.new do
            io=StringIO.new(@template.clone)
            @template.freeze
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
