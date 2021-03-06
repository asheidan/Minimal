require 'rubygems'
require 'yaml'
require 'rdiscount'
require 'minimal'
require 'git'

RakeFileUtils.verbose(!!CONF[:debug])

db = CONF[:database][:database]

$dirs.each do |key,dir|
	directory dir
end

task :new,[:title] do |t,args|
	Rake::Task["minimal:new"].invoke( args.title )
end
task :generate => "minimal:generate"
task :server => "camping:server"
task :environment => "camping:environment"
namespace :minimal do
	desc "Create new article"
	task :new, [:title] do |t,args|
		cleaned_title = args.title.gsub(/[^a-zA-Z ]/,'').gsub(' ','_').downcase
		filename = File.join($dirs[:articles],cleaned_title + '.markdown')
		File.open(filename,'w+') do |template|
			template.puts "# #{args.title}"
			template.puts
			template.puts "tags: "
			template.puts
		end
		sh "#{CONF[:editor]} #{filename}"
	end
	
	desc "Read files into database"
	task :generate => [:environment,db] + $dirs.values do
		FileList["#{$dirs[:articles]}/*"].each do |filename|
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
		FileList["#{$dirs[:deleted]}/*"].each do |filename|
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
	
	desc "Displays current configuration"
	task :config do
		puts YAML.dump( CONF )
	end
	namespace :config do
		desc "Write configuration to file"
		task :write do
			File.open( CONFIG_FILE, 'w' ) do |file|
				YAML.dump( CONF, file )
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
		Minimal::Models::Base.establish_connection(CONF[:database])
	end
	
	file db => :environment do
		Minimal::Models.create_schema
	end
end
namespace :remote do
	def parse_git_config
		#File.
	end
end
namespace :git do
	def add(path)
		if File.file?(path) or File.directory?(path)
			sh "git add -v #{path}"
		end
	end
	
	#directory ".git"
	file ".git" do
		puts "You should already have a repository"
		# sh "git init"
	end
	desc "Creates a git repository"
	task :create => ".git"
	
	desc "Makes sure we're on the articles branch"
	task :branch => ".git" do
		sh( "git checkout #{CONF[:git][:branch]}" )
		#sh( "git checkout pudding} > /dev/null" )
	end
	
	desc "Adds articles to git index"
	task :add => :branch do
		add($dirs[:articles])
		add($dirs[:deleted])
	end
	
	desc "Commits articles to repository"
	task :commit => [:add,:branch] do
		puts "Commit of articles"
	end
	
	desc "Pushes articles to remote"
	task :push => :branch do
		sh "git push"
	end
end