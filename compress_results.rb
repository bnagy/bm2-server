# Author: Ben Nagy
# Copyright: Copyright (c) Ben Nagy, 2006-2010.
# License: The MIT License
# (See README.TXT or http://www.opensource.org/licenses/mit-license.php for details.)

require 'fileutils'
path=ARGV[0]


# I wouldn't use this, if I were you. Because it deletes by !exploitable hash
# (which is just the callstack, essentially) it might delete good bugs that hash
# to the same value as crappy looking bugs, based on the !exploitable analysis.

# get all detail files in the path
pattern=File.join(path, "*.txt")
results=Hash.new {|hsh, k| hsh[k]=[0,[]]}
deleted_crashes=0
deleted_results=0

Dir.glob(pattern, File::FNM_DOTMATCH).tap {|a| puts "#{a.length} detail files total"}.each {|fn|
	contents=File.open(fn, "rb") {|ios| ios.read}
	if match=contents.match(/Hash=(.*)\)/)
		bucket=match[1]
		results[bucket][0]+=1
		if results[bucket][0] >= 1024
			FileUtils.rm_f(fn)
			deleted_results+=1
		end
		crashfile=fn.sub('.txt','.raw')
		if File.exists? crashfile
			if results[bucket][1].size < 1024
				results[bucket][1]<<crashfile
			else
				FileUtils.rm_f(crashfile)
				deleted_crashes+=1
			end
		end
	end
}
puts "Deleted #{deleted_results} detail files and #{deleted_crashes} crash files."
