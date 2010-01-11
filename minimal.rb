require 'camping'
require 'less'

Camping.goes :Minimal

class Time
	def to_s
		strftime("%H:%M %d %B %Y")
	end
end

module Minimal::Models
	class Article < Base
		validates_presence_of :title
		
		def self.find_by_tag(name,opts = {})
			s_opts = {:conditions => ["tags LIKE ?","%#{name}%"]}
			opts.merge! s_opts
			all(opts)
		end
	end
	
	class ArticleFields < V 1
		def self.up
			create_table Article.table_name do |t|
				t.string :title
				t.string :tags
				t.text :content
				t.timestamps
			end
		end
		def self.down
			drop_table Article.table_name
		end
	end
	
	class ArticleFilenameField < V 2
		def self.up
			add_column Article.table_name, :filename, :string
		end
		def self.down
			remove_column Article.table_name, :filename
		end
	end
end

module Minimal::Controllers
	class Index < R '/'
		def get
			@articles = Article.all(:order => 'updated_at DESC')
			@title = "List of articles"
			render :list
		end
	end
	
	class ArticleX
		def get(title)
			@article = Article.find_by_title(title)
			render :article
		end
	end

	class TagX
		def get(name)
			@articles = Article.find_by_tag(name)
			@title = "Articles tagged with #{name}"
			render :list
		end
	end
	
	class Static < R '/static'
		def get
			File.read("nisse.html")
		end
	end
	
	class Stylesheet < R '/default.css'
		def get
			@headers['Content-Type'] = 'text/css'
			Less.parse File.read("default.less")
		end
	end
end

module Minimal::Views
	def layout
		html do
			head do
				title @title
				link :href => R(Stylesheet), :rel => 'stylesheet', :type => 'text/css'
			end
			body do
				self << yield
			end
		end
	end
	
	def list
		h1 @title
		@articles.each do |article|
			a article.title, :href => R(ArticleX, article.title)
		end
	end
	
	def article
		h1 @article.title
		div do
			self << @article.content
		end
		div :class => 'footer' do
			div :class => 'content' do
				a 'Index', :href => R(Index), :class => 'left'
				div @article.updated_at, :class => 'right'
				div :class => 'right' do
					@article.tags.split(/ *, */).collect do |t|
						a( t, :href => R(TagX,t) ).to_s
					end.join(', ')
				end
				div @article.title
			end
		end
	end
end

def Minimal.create
	Minimal::Models::Base.establish_connection(
		:adapter => 'sqlite3',
		:database => 'minimal.db'
	)
	Minimal::Models.create_schema
end