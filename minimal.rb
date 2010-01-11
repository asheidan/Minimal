require 'camping'
require 'less'
require 'i18n'

Camping.goes :Minimal

class Time
	def to_s
		strftime("%H:%M %d %B %Y")
	end
end
I18n.backend.store_translations :en, {
	:less_than_x_minutes => {
		:one => 'less than a minute',
		:one => 'less than {{count}} minutes'
	},
	:x_minutes => {
		:one => 'a minute',
		:other => '{{count}} minutes'
	},
	:about_x_hours => {
		:one => 'about an hour',
		:other => 'about {{count}} hours'
	},
	:x_days => {
		:one => 'a day',
		:other => '{{count}} days'
	}
}

module Minimal::Helpers
	def locale
		I18n
	end
	def time_ago_in_words(from_time, include_seconds = false)
		distance_of_time_in_words(from_time, Time.now, include_seconds)
	end
	def distance_of_time_in_words(from_time, to_time = 0, include_seconds = false, options = {})
		from_time = from_time.to_time if from_time.respond_to?(:to_time)
		to_time = to_time.to_time if to_time.respond_to?(:to_time)
		distance_in_minutes = (((to_time - from_time).abs)/60).round
		distance_in_seconds = ((to_time - from_time).abs).round
		case distance_in_minutes
			when 0..1
				return distance_in_minutes == 0 ?
					locale.t(:less_than_x_minutes, :count => 1) :
					locale.t(:x_minutes, :count => distance_in_minutes) unless include_seconds

				case distance_in_seconds
					when 0..4   then locale.t :less_than_x_seconds, :count => 5
					when 5..9   then locale.t :less_than_x_seconds, :count => 10
					when 10..19 then locale.t :less_than_x_seconds, :count => 20
					when 20..39 then locale.t :half_a_minute
					when 40..59 then locale.t :less_than_x_minutes, :count => 1
					else             locale.t :x_minutes,           :count => 1
				end

			when 2..44           then locale.t :x_minutes,      :count => distance_in_minutes
			when 45..89          then locale.t :about_x_hours,  :count => 1
			when 90..1439        then locale.t :about_x_hours,  :count => (distance_in_minutes.to_f / 60.0).round
			when 1440..2879      then locale.t :x_days,         :count => 1
			when 2880..43199     then locale.t :x_days,         :count => (distance_in_minutes / 1440).round
			when 43200..86399    then locale.t :about_x_months, :count => 1
			when 86400..525599   then locale.t :x_months,       :count => (distance_in_minutes / 43200).round
			when 525600..1051199 then locale.t :about_x_years,  :count => 1
			else                      locale.t :over_x_years,   :count => (distance_in_minutes / 525600).round
		end
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
			unless @article.nil?
				render :article
			else
				redirect Index
			end
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
			div do
				a article.title, :href => R(ArticleX, article.title)
			end
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
				div "#{time_ago_in_words(@article.updated_at)} ago", :class => 'right'
				div :class => 'right',:style => "clear:right;" do
					@article.tags.split(/ *, */).collect do |t|
						a( t, :href => R(TagX,t) ).to_s
					end.join(', ')
				end
				div @article.title
				div :class => 'achor'
			end
		end
	end
end

def Minimal.create
	I18n.default_locale = :en
	Minimal::Models::Base.establish_connection(
		:adapter => 'sqlite3',
		:database => 'minimal.db'
	)
	Minimal::Models.create_schema
end