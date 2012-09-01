require 'mechanize'
require 'json'
require 'colorize'
require 'yaml'

class Reciept
  attr_accessor :url

  def initialize(reciept)
    @reciept = reciept
    self.url = reciept['image']
  end
  
  def to_s
    "%{date}: %{merchant} - %{total}" % {
      :date => @reciept['date'],
      :merchant => @reciept['merchant'],
      :total => @reciept['total']
    }
  end
end

config = YAML.load_file('config.yml')
if config['username'].empty? or config['password'].empty?
  puts 'Missing username or password'
  exit(1)
end

agent = Mechanize.new

page = agent.get('https://dashboard.lemon.com/login/')

login_form = page.form

login_form.username = config['username']
login_form.password = config['password']
puts 'Logging in...'.green
login_form.submit

params = {
  :action => 'getReceipts',
  :count => 0,
  :page => 0,
  :pageSize => 100,
  :month => '2012-08-01'
}

puts "Requesting purchases...\n\n".green
res = agent.post('https://dashboard.lemon.com/purchases/process.php', params)
reciepts = JSON.parse(res.body)
if !reciepts['success']
  puts "Error retriving reciept list: #{reciepts['error']}"
  exit(1)
end

total = reciepts['data']['currencies'].first['total'].to_i +
        (reciepts['data']['currencies'].first['cents'].to_i / 100)

if reciepts['data']['count'].to_i > 100
  puts 'You have over 100 reciepts, we don\'t handle multiple pages yet'.red
  exit
end

puts "Found #{reciepts.length} reciepts for a total of $#{total}:".green
log = File.open('log.txt', 'w')
reciepts['purchases'].each do |purchase|
  reciept = Reciept.new(purchase)
  log.write(reciept.to_s + "\n")
  puts reciept.to_s.blue


  puts "  - Downloading reciept..."
  `wget -nv -P reciepts #{reciept.url}`
end

log.close

puts "Zipping reciepts folder".green
`zip -r reciepts reciepts`
`open reciepts`

print "Delete reciepts folder? [Y/n]: ".green
case gets.strip
  when 'Y', 'y', ''
    FileUtils.rm_rf("reciepts", :secure => true)
    puts 'Removed reciepts folder.'.green
end
