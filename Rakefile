require 'yaml'
require 'rdiscount'

CONFIG_FILE = 'minimal.yaml'

$conf = {}
$conf.merge!( YAML.load_file(CONFIG_FILE) ) { |key, v1, v2|
	if v1.class == Hash and v2.class == Hash
		v1.merge v2
	else
		v2
	end
}
$conf['dirs'] = $conf['directories']
# puts $conf.inspect

db = $conf['database']['database']

$conf['dirs'].values.each do |dir|
	directory dir
end

task :generate => "minimal:generate"
task :server => "camping:server"
task :environment => "camping:environment"

namespace :minimal do
	desc "Read files into database"
	task :generate => [:environment,db] + $conf['dirs'].values do
		FileList["#{$conf['dirs']['articles']}/*"].each do |filename|
			if File.file? filename
				basename = File.basename(filename)
				updated = File.mtime filename
				article = Minimal::Models::Article.find_or_initialize_by_filename(basename)
				if article.new_record?
					print "#{basename}:\tNew"
					article.created_at = updated
					article.updated_at = updated
					parse_markdown_article(filename, article)
				elsif article.updated_at < updated
					print "#{basename}:\tUpdated"
					parse_markdown_article(filename, article)
				end
				if article.changed?
					unless article.save
						puts "\t#{article.errors.count}\terrors"
						article.errors.each_full { |msg| puts "\t#{msg}" }
					else puts
					end
				end
			end
		end
		FileList["#{$conf['dirs']['deleted']}/*"].each do |filename|
			if File.file? filename
				basename = File.basename(filename)
				article = Minimal::Models::Article.find_by_filename(basename)
				unless article.nil?
					article.destroy
					puts "#{basename}:\tRemoved"
				end
			end
		end
	end
	
	def parse_markdown_article(filename, article)
		tag_re = /^tags: *(.*)/
		title_re = /^# *([^#].*)/
		content = IO.readlines(filename).select do |l|
			if tag_re =~ l
				article.tags = Regexp.last_match(1).split(/ *, */).join(', ')
				false
			elsif title_re =~ l
				article.title = Regexp.last_match(1)
				false
			else
				true
			end
		end.join
		article.content = RDiscount.new(content).to_html
	end
end
namespace :camping do

	desc "Start the webrick server"
	task :server => db do
		sh "camping -s webrick -d #{db} minimal.rb"
	end
	
	desc "Establish the camping environment"
	task :environment do
		require 'minimal'
		Minimal::Models::Base.establish_connection($conf['database'])
	end
	
	file db => :environment do
		Minimal::Models.create_schema
	end
end