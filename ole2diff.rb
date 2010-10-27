# Author: Ben Nagy
# Copyright: Copyright (c) Ben Nagy, 2006-2010.
# License: The MIT License
# (See README.TXT or http://www.opensource.org/licenses/mit-license.php for details.)

require 'rubygems'
require 'diff/lcs'
require 'trollop'
require File.dirname(__FILE__) + '/streamdiff'

opts = Trollop::options do 
    opt :old_file, "Original file", :type => :string
    version "ole2diff 0.0.5 (c) Ben Nagy, 2010"
    banner <<-EOS
ole2diff will diff a list of files against a template file
and output the differences as hexdumps, sorted by stream. 
It IGNORES the CompObj stream, because that stream changes
virtually every time the file is opened and closed.

Usage:
       ruby ole2diff.rb --old-file <filename> [file1, file2, file3 ...]
EOS
end

begin
    old_ole=Ole::Storage.open(opts[:old_file])
    old_streams=Hash[*(old_ole.dirents.map {|dirent| 
        next if dirent.dir?;[dirent.name,dirent.read]
    }).compact.flatten]
rescue
    raise RuntimeError, "Couldn't open #{opts[:old_file]} as OLE2: #{$!}, Aborting."
ensure 
    old_ole.close
end

# Whatever is left in ARGV is the file list
ARGV.each {|filename|
    puts "Diffing #{filename} against #{opts[:old_file]}"

    begin
        new_ole=Ole::Storage.open( filename )
        new_streams=Hash[*(new_ole.dirents.map {|dirent| 
            next if dirent.dir?;[dirent.name,dirent.read]
        }).compact.flatten]
    rescue
        puts "Couldn't open #{filename} as OLE2: #{$!}, Skipping."
        next
    ensure 
        new_ole.close rescue nil
    end

    old={}
    new={}

    old_streams.each {|dirent,contents|
        # The compobj table changes virtually every time an OLE2 file is unpacked and repacked.
        # So don't check it for differences.
        next if dirent=~/compobj/i
        next if new_streams[dirent]==contents
        old[dirent],new[dirent]=StreamDiff::diff_and_markup(contents, new_streams[dirent])
    }

    old.each {|dirent, chunk_array|
        puts "Diffs in stream #{dirent}"
        new_diffs=new[dirent].reject {|chunk| chunk.chunk_type==:unchanged}
        old_diffs=chunk_array.reject {|chunk| chunk.chunk_type==:unchanged}
        zipped=old_diffs.zip( new_diffs )
        zipped.each {|pair|
            print "Old: +0x%-8x : " % [pair[0].offset]
            puts "#{StreamDiff::hexdump( pair[0].join )}"
            print "New: +0x%-8x : " % [pair[1].offset]
            puts "#{StreamDiff::hexdump( pair[1].join )}"
        }
    }
}
