# encoding: utf-8
require File.expand_path(File.dirname(__FILE__)) + '/../test_helper'

# This file is generated by the Ruby Holiday gem.
#
# Definitions loaded: data/de.yaml
class DeDefinitionTests < Test::Unit::TestCase  # :nodoc:

  def test_de
{Date.civil(2009,1,1) => 'Neujahrstag', 
 Date.civil(2009,4,10) => 'Karfreitag',
 Date.civil(2009,4,13) => 'Ostermontag',
 Date.civil(2009,5,1) => 'Tag der Arbeit',
 Date.civil(2009,5,21) => 'Christi Himmelfahrt',
 Date.civil(2009,6,1) => 'Pfingstmontag',
 Date.civil(2009,10,3) => 'Tag der Deutschen Einheit',
 Date.civil(2009,12,25) => '1. Weihnachtstag',
 Date.civil(2009,12,26) => '2. Weihnachtstag'}.each do |date, name|
  assert_equal name, (Holidays.on(date, :de, :informal)[0] || {})[:name]
end

[:de_bw, :de_by, :de_st, :de_].each do |r|
  assert_equal 'Heilige Drei Könige', Date.civil(2009,1,6).holidays(r)[0][:name]
end

[:de_bw, :de_by, :de_he, :de_nw, :de_rp, :de_sl, :de_].each do |r|
  assert_equal 'Fronleichnam', Date.civil(2009,6,11).holidays(r)[0][:name]
end

[:de_by, :de_sl, :de_].each do |r|
  assert_equal 'Mariä Himmelfahrt', Date.civil(2009,8,15).holidays(r)[0][:name]
end

[:de_bb, :de_mv, :de_sn, :de_st, :de_th, :de_].each do |r|
  assert_equal 'Reformationstag', Date.civil(2009,10,31).holidays(r)[0][:name]
end

[:de_bw, :de_by, :de_nw, :de_rp, :de_sl, :de_].each do |r|
  assert_equal 'Allerheiligen', Date.civil(2009,11,1).holidays(r)[0][:name]
end

[:de_be, :de_bb, :de_hb, :de_hh, :de_ni, :de_sh].each do |r|
  assert_equal 'Tag der Deutschen Einheit', Date.civil(2009,10,3).holidays(r)[0][:name]
end

[:de_be, :de_hb, :de_hh, :de_ni, :de_sh].each do |r| 
  assert !Date.civil(2009,1,6).holiday?(r), "Heilige Drei Könige is not a holiday in #{r}"
end

[:de_be, :de_hb, :de_hh, :de_ni, :de_sh].each do |r| 
  assert !Date.civil(2009,6,11).holiday?(r), "Fronleichnam is not a holiday in #{r}"
end

[:de_be, :de_hb, :de_hh, :de_ni, :de_sh].each do |r| 
  assert !Date.civil(2009,8,15).holiday?(r), "Mariä Himmelfahrt is not a holiday in #{r}"
end

[:de_be, :de_hb, :de_hh, :de_ni, :de_sh].each do |r| 
  assert !Date.civil(2009,10,31).holiday?(r), 'Reformationstag is not a holiday in #{r}'
end

[:de_be, :de_bb, :de_hb, :de_hh, :de_ni, :de_sh].each do |r| 
  assert !Date.civil(2009,11,1).holiday?(r), "Allerheiligen is not a holiday in #{r}"
end

assert !Date.civil(2010,5,8).holiday?(:de), '2010-05-08 is not a holiday in Germany'

# Repentance Day
assert_equal 'Buß- und Bettag', Date.civil(2004,11,17).holidays(:de_sn)[0][:name]
assert_equal 'Buß- und Bettag', Date.civil(2005,11,16).holidays(:de_sn)[0][:name]
assert_equal 'Buß- und Bettag', Date.civil(2006,11,22).holidays(:de_sn)[0][:name]
assert_equal 'Buß- und Bettag', Date.civil(2009,11,18).holidays(:de_sn)[0][:name]

  end
end