require 'mechanize'
require 'json'
require 'colorize'
require 'yaml'
require 'trollop'
require 'date'

require_relative 'reciept'

opts = Trollop::options do
    opt :month, "Month (ex. 03/12)", :type => :string
  end

opts[:month] ||= Time.now.strftime('%m/%y')
date = Date.strptime opts[:month], '%m/%y'

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
  :month => date.strftime('%Y-%m-01')
}

puts "Requesting purchases for month #{date.strftime('%m/%y')}...\n\n".green
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


# Use specific directory for month
month_folder = "tmp/#{date}"
FileUtils.mkdir_p(month_folder)
FileUtils.cd(month_folder)


puts "Found #{reciepts.length} reciepts for a total of $#{total}:".green
log = File.open('purchases.txt', 'w')
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
