# Author: Ben Nagy
# Copyright: Copyright (c) Ben Nagy, 2006-2010.
# License: The MIT License
# (See README.TXT or http://www.opensource.org/licenses/mit-license.php for details.)

require 'fileutils'
require 'trollop'
require File.dirname(__FILE__) + '/../bm2-core/detail_parser'


OPTS = Trollop::options do 
    opt :source_dir, "Source Dir", :type => :string
end

SOURCE_PATH=OPTS[:source_dir]

# A caveat... because this works by !exploitable hash, you really
# cannot trust the classification - you have to look at the faulting
# code yourself, and if it looks dangerous, check the rest of the files
# in that bucket to assess register control. One file might be a null
# deref, but the whole set might display control of eax etc.

def dump(results, summary)
    hack=Hash.new {|h,k| h[k]=0}
    puts "=========SUMMARY==============="
    summary.each {|k,v| puts "#{k}: #{v}"}
    puts "#{results.keys.size} Buckets."
    results.sort.each {|k,v|
        hack[v[2]]+=1
    }
    hack.each {|k,v| puts "#{k}: #{v}"}
    puts "==============================="
    results.each {|k,v|
        puts "--- #{k}  ---"
        puts v[:instructions]
        puts "Descriptions:"
        v[:descs].each {|k,v|
            puts "#{k} -> #{v}"
        }
        puts "Register Control:"
        v[:affected_regs].each {|k,v|
            puts "#{k} -> #{v}"
        }
        puts "Sample registers"
        puts v[:sample_registers]
        puts v[:stack]
    }
end

# get all detail files in the SOURCE_PATH
pattern=File.join(SOURCE_PATH, "*.txt")
results=Hash.new {|hsh, k| hsh[k]=Hash.new {|h,k| h[k]=Hash.new {|h,k| h[k]=0}}}
summary=Hash.new {|hsh, k| hsh[k]=0}

Dir.glob(pattern, File::FNM_DOTMATCH).each {|fn|
    contents=File.open(fn, "rb") {|ios| ios.read}.split(/frobozz/).last
    exception=Detail.new( contents )
    
    if not (hsh=exception.major_hash).empty?
        if File.exists? fn.sub('.txt','.chain.zip')
            file=fn.sub('.txt','.chain.zip')
        elsif File.exists? fn.sub('.txt','.doc')
            file=fn.sub('.txt','.doc')
        elsif File.exists? fn.sub('.txt','.raw')
            file=fn.sub('.txt','.raw')
        else
            file="<missing?>"
        end
        results[hsh][:descs]["#{exception.short_desc} - #{exception.classification}"]+=1
        instructions=exception.disassembly
        fault=instructions[0][1]
        affected_registers=fault.scan(/e../)
        reg_hsh=Hash[*(exception.registers.flatten)]
        affected_registers=affected_registers.map {|reg| "#{reg}=#{reg_hsh[reg]}"}.join(',')
        results[hsh][:affected_regs][affected_registers]+=1
        results[hsh][:instructions]=instructions.map {|a| a[1]}.join("\n")
        summary[exception.classification]+=1
        summary["total"]+=1
        results[hsh][:sample_registers]=exception.registers.map {|a| a.join('=')}.join(' ')
        stack=exception.stack_trace[0..3].map {|a| a[1]}.join("\n")
        results[hsh][:stack]="-----STACK-------\n" << stack << "\n--------------------"
    end
}
dump results, summary
