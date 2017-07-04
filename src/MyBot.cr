require "./MyBot/*"
require "slack"
require "rss_feed_emitter"
require "option_parser"

debug = false
OptionParser.parse! do |parser|
  parser.on("-d", "--debug", "debug") { debug = true }
end

feeder = RSSFeedEmitter::Feeder.new

if ARGV.size == 0
  feeder.add "http://rss.cnn.com/rss/cnn_latest.rss", refresh: 10
else
  ARGV.each do |arg|
    puts "addeding #{arg}"
    feeder.add arg, refresh: 60
  end
end
items = Channel(Hash(String,String)).new

# listening new items
feeder.new_item do |item|
    items.send(item)
end

slack = Slack.new(token: ENV["SLACK_MYBOT"])

channel = slack.channels[ENV["SLACK_CHANNEL"] || "general"].id

puts slack.channels
slack.on(Slack::Event::Ready) do |session, event|
  puts "Ready"
end

slack.on(Slack::Event::UserTyping) do |session, event|
  puts "someone is typing"
end



spawn do
  sleep 1 # dont like this sleep here...
  slack.send "ready...", to: channel
  while item = items.receive
    puts item.to_s if debug
    slack.send item["guid"] || item["link"], to: channel
  end
end

spawn do
  feeder.start
end

slack.run
