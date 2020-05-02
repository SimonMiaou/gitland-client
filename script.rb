# frozen_string_literal: true

# CODE
#=====

require 'csv'
require 'json'
require 'net/http'
require 'uri'

system('rubocop -a')

# CONFIG
# ======

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
  'cb' => '🔵',
  'cg' => '🟢',
  'cr' => '🔴'
}.freeze

def compute_counters
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
end

def find_best_move
  next_move = 'idle'
  next_move = find_most_offensive_move if next_move == 'idle'
  next_move = find_fastest_capture if next_move == 'idle'
  next_move
end

def find_fastest_capture
  frontier = [@current_position]
  came_from = {}
  targets = %w[ub ug ur ux]
  targets.delete(targets.find { |t| t[1] == @team[1] })

  position = nil

  until frontier.empty?
    position = frontier.shift

    break if targets.include?(@map[position[:y]][position[:x]])

    get_neighbors(position).each do |next_position|
      next if @map[next_position[:y]][next_position[:x]][0] == 'c'

      unless came_from.keys.include?(next_position)
        frontier << next_position
        came_from[next_position] = position
      end
    end
  end

  return 'idle' if position.nil?
  return 'idle' if position == @current_position

  position = came_from[position] while came_from[position] != @current_position

  position_to_move(position)
end

def find_most_offensive_move
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

    break if @map[position[:y]][position[:x]] == target

    get_neighbors(position).each do |next_position|
      next unless uncontrolled.include?(@map[next_position[:y]][next_position[:x]])

      unless came_from.keys.include?(next_position)
        frontier << next_position
        came_from[next_position] = position
      end
    end
  end

  return 'idle' if position.nil?
  return 'idle' if position == @current_position

  position = came_from[position] while came_from[position] != @current_position

  position_to_move(position)
end

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

  # Ordering:
  # 1. enemies' cells with high decay first
  # 2. empty cells
  # 3. our cells with low decay first
  neighbors.sort_by do |n|
    if @map[n[:y]][n[:x]] == @team
      @decay[n[:y]][n[:x]].to_i
    elsif @map[n[:y]][n[:x]] == 'ux'
      0
    else
      -@decay[n[:y]][n[:x]].to_i
    end
  end
end

def position_to_move(position)
  if position[:x] == @current_position[:x] && position[:y] > @current_position[:y]
    'down'
  elsif position[:x] == @current_position[:x] && position[:y] < @current_position[:y]
    'up'
  elsif position[:x] > @current_position[:x] && position[:y] == @current_position[:y]
    'right'
  elsif position[:x] < @current_position[:x] && position[:y] == @current_position[:y]
    'left'
  else
    'idle'
  end
end

def print_map
  @map.each_with_index do |row, y|
    print '| '
    row.each_with_index do |cell, x|
      if x == @current_position[:x] && y == @current_position[:y]
        print PLAYER_EMOJI
        next
      end
      print CELL_TO_EMOJI[cell]
    end
    print " |\n"
  end
end

def print_stats
  @counters.each do |k, v|
    next if v.zero?

    print "| #{CELL_TO_EMOJI[k]} #{v} "
  end
  print "|\n"
end

def print_players
  players = Dir.entries('gitland/players')
               .reject { |player| ['.', '..'].include?(player) }
               .select { |player| File.directory?("gitland/players/#{player}") }
               .sort

  players.each do |player|
    team = File.read("gitland/players/#{player}/team")
    x = File.read("gitland/players/#{player}/x")
    y = File.read("gitland/players/#{player}/y")
    timestamp = File.read("gitland/players/#{player}/timestamp").to_i
    puts "#{TEAM_TO_STRING[team]} #{player} (#{x}, #{y}) #{time_ago(timestamp)}"
  end
end

def time_ago(timestamp)
  delta = Time.now.to_i - timestamp
  case delta
  when 0..30         then 'just now'
  when 31..119       then 'about a minute ago'
  when 120..3599     then "#{delta / 60} minutes ago"
  else "#{(delta / 3600).round} hours ago"
  end
end

# MAIN LOOP
# =========

loop do
  puts "### #{Time.now.strftime("%k:%M")} Pulling latest gitland changes"
  system('cd gitland && git pull')

  @map = CSV.parse(File.read('gitland/map'))
  @decay = CSV.parse(File.read('gitland/decay'))
  @team = File.read("gitland/players/#{PLAYER_NAME}/team")
  @current_position = { x: File.read("gitland/players/#{PLAYER_NAME}/x").to_i,
                        y: File.read("gitland/players/#{PLAYER_NAME}/y").to_i }

  compute_counters

  next_move = find_best_move

  puts '=================================================='
  puts "| Player:    #{PLAYER_NAME}"
  puts "| Team:      #{TEAM_TO_STRING[@team]}"
  puts "| Position:  #{@current_position[:x]}, #{@current_position[:y]}"
  puts "| Next move: #{next_move}"
  puts '=================================================='
  print_map
  puts '=================================================='
  print_stats
  puts '=================================================='
  # print_players
  # puts '=================================================='

  File.open('act', 'w') { |file| file.write(next_move) }

  system('git add -A')
  system("git commit -m \"Update #{Time.now}\"")
  system('git push')

  sleep 30
end
