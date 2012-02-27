#!/usr/bin/env ruby

require 'getoptlong'


# Input: lines of format:
#<value1> <frequency1>
#<value2> <frequency2>
#...
#
#Output: various freq distributions

end

field_split_char = ','
format_each_line = :VALUE_COUNT
percentile_output_file = 'percentiles.txt'

opts = GetoptLong.new(
  [ '-p', '--percentiles_file_out', GetoptLong::OPTIONAL_ARGUMENT ],
  [ '-t', '--splitchar', GetoptLong::OPTIONAL_ARGUMENT ],
  [ '-v', '--value_per_line', GetoptLong::NO_ARGUMENT ]
)

opts.each do |opt, arg|
  case opt
  when '-t'
    field_split_char = arg
  when '-p'
    percentile_output_file = arg
  when '-v'
    format_each_line = :ID_VALUE
  end
end

#format_each_line = :ID_VALUE if each line is <id> <value> where <id> is to be thrown away
begin
  lineno = 0
  histo = Hash.new(0)
  tot = wt_tot = 0
  
  STDIN.each_line do |line|
    lineno += 1
    next if line =~ /^#/
    
    (v, f) = line.split(field_split_char)
    value = v.to_i
    freq = f.to_i
    if format_each_line == :ID_VALUE
      value = f.to_i
      freq = 1
    end
    histo[value] += freq
    tot += freq
    wt_tot += freq*value
    $stderr.puts "Read #{lineno} lines" if lineno % 1000000 == 0
  end
  
  percentiles = [50,75,90,95,99,99.9]
  hash_per = Hash.new{ |h,k| h[k] = {} }
  percentiles.each do |per|
    [:le,:wt_le].each do |sym|
      hash_per[sym][per] = -1
    end
  end
  le = wt_le = 0
  #convert to doubles
  tot *= 1.0
  wt_tot *= 1.0
  ge = tot
  wt_ge = wt_tot
  print "#val,freq,frac(freq),agg_freq_le,frac(agg_freq_le),|6|,"
  print "agg_freq_ge,frac(agg_freq_ge),|9|,weight=freq*val,agg_weight_le,frac(agg_weight_le),|13|,"
  print "agg_weight_ge,frac(agg_weight_ge),|16|,"
  puts "log(val),log(freq),log(agg_freq_le),log(agg_freq_ge),log(agg_weight_le),log(agg_weight_ge)"
  histo.sort.each do |k,v|
    wt = v * k
    le += v
    wt_le += wt
    percentiles.each do |per|
      { :le => le/tot, :wt_le => wt_le/wt_tot }.each do |sym,currval|
        hash_per[sym][per] = k if (100.0*currval >= per) && (hash_per[sym][per] == -1)
     end
    end
    print "#{k},#{v},#{v/tot},#{le},#{le/tot},|6|,"
    print "#{ge},#{ge/tot},|9|,#{wt},#{wt_le},#{wt_le/wt_tot},|13|,"
    print "#{wt_ge},#{wt_ge/wt_tot},|16|,"
    puts "#{safe_log(k)},#{safe_log(v)},#{safe_log(le)},#{safe_log(ge)},#{safe_log(wt_le)},#{safe_log(wt_ge)}"
    ge -= v
    wt_ge -= wt
  end
  
  perfile = File.open(percentile_output_file, 'w')
  perfile.puts "Average = #{wt_tot/tot}"
  perfile.puts "All percentiles:"
  percentiles.each do |p|
    perfile.puts "#{p}%ile values:"
    [:le, :wt_le].each do |sym|
      perfile.print sym, " ", hash_per[sym][p]
      perfile.puts
    end
  end
end
