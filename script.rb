File.open('act', 'w') { |file| file.write(['right', 'left', 'up', 'down'].sample) }

system('git add -A')
system('git commit -m "some message"')
system('git push orign master')
