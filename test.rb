# frozen_string_literal: true

require 'csv'
require 'digest'
require 'json'
require 'net/http'
require 'uri'

PLAYER_EMOJI = '😺'
PLAYER_NAME = 'SimonMiaou'
CELL_TO_EMOJI = {
  'cb' => '🔵',
  'cg' => '🟢',
  'cr' => '🔴',
  'ub' => '🟦',
  'ug' => '🟩',
  'ur' => '🟥',
  'ux' => '⬛️'
}.freeze
TEAM_TO_STRING = {
  'cb' => '🔵 Blue',
  'cg' => '🟢 Green',
  'cr' => '🔴 Red'
}.freeze

system('rubocop -a')

@map = CSV.parse(File.read('gitland/map'))
@team = File.read("gitland/players/#{PLAYER_NAME}/team")
@current_position = { x: File.read("gitland/players/#{PLAYER_NAME}/x").to_i,
                      y: File.read("gitland/players/#{PLAYER_NAME}/y").to_i }

@map.each_with_index do |row, y|
  row.each_with_index do |cell, x|
    if x == @current_position[:x] && y == @current_position[:y]
      print PLAYER_EMOJI
      next
    end
    print CELL_TO_EMOJI[cell]
  end
  print "\n"
end

targets = %w[ub ug ur]
targets.delete(targets.find { |t| t[1] == @team[1] })
target = @counters.select { |k, _v| targets.include?(k) }.max_by { |_k, v| v }.first

frontier = [@current_position]
came_from = {}
uncontrolled = %w[ub ug ur ux]
uncontrolled.delete(uncontrolled.find { |t| t[1] == @team[1] })

position = nil

until frontier.empty?
  position = frontier.shift
  puts "/ #{position}"

  get_neighbors(position).each do |next_position|
    next unless uncontrolled.include?(@map[next_position[:y]][next_position[:x]])

    unless came_from.keys.include?(next_position)
      frontier << next_position
      came_from[next_position] = position
    end
  end
end

return 'idle' if position.nil?

puts "// #{position}"

puts came_from
