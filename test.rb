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

def get_neighbors(position)
  min_x = 0
  min_y = 0
  max_x = @map.first.size - 1
  max_y = @map.size - 1

  neighbors = []

  neighbors << { x: position[:x] + 1, y: position[:y] }
  neighbors << { x: position[:x] - 1, y: position[:y] }
  neighbors << { x: position[:x], y: position[:y] + 1 }
  neighbors << { x: position[:x], y: position[:y] - 1 }

  neighbors.reject! do |n|
    n[:x] < min_x || n[:x] > max_x ||
      n[:y] < min_y || n[:y] > max_y
  end

  neighbors.sort_by { |n| Digest::MD5.hexdigest(n.to_json) }
end

# FETCH DATA

@map = CSV.parse(File.read('gitland/map'))
@team = File.read("gitland/players/#{PLAYER_NAME}/team")
@current_position = { x: File.read("gitland/players/#{PLAYER_NAME}/x").to_i,
                      y: File.read("gitland/players/#{PLAYER_NAME}/y").to_i }

# MAP
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

# COUNTERS

@counters = {
  'cb' => 0,
  'ub' => 0,
  'cg' => 0,
  'ug' => 0,
  'cr' => 0,
  'ur' => 0,
  'ux' => 0
}

@map.each do |row|
  row.each do |cell|
    @counters[cell] ||= 0
    @counters[cell] += 1
  end
end

# CODE

frontier = [@current_position]
came_from = {}
uncontrolled = %w[ub ug ur ux]

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

position = came_from[position] while came_from[position] != @current_position

puts "// #{position}"
