require 'camping'
require 'less'
require 'i18n'

Camping.goes :Minimal

class Time
	def to_s
		strftime("%H:%M %d %B %Y")
	end
end
class Hash
	def deep_merge!(other)
		merge!(other) { |key, v1, v2|
			if v1.class == Hash and v2.class == Hash
				v1.deep_merge v2
			else
				v2
			end
		}
	end
	
	def deep_merge(other)
		merge(other) { |key, v1, v2|
			if v1.class == Hash and v2.class == Hash
				v1.deep_merge v2
			else
				v2
			end
		}
	end
end

CONFIG_FILE = 'minimal.yaml'

$conf = {
	:language => :en,
	:database => {
		:adapter => 'sqlite3',
		:database => 'minimal.db'
	},
	:directories => {
		:articles => 'articles',
		:deleted => 'articles/deleted'
	}
}
$conf.deep_merge!( YAML.load_file(CONFIG_FILE) ) if File.file? CONFIG_FILE
$dirs = $conf[:directories]
# puts $conf.inspect

I18n.backend.store_translations :en, {
	:less_than_x_minutes => {
		:one => 'less than a minute',
		:other => 'less than {{count}} minutes'
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
module Minimal
	module Base
		def r404(p)
			@p = p
			@code = 404
			render :error
		end
	end
	
	module Helpers
		def pluralize(count, singular, plural = nil)
			"#{count || 0} " + ((count == 1 || count == '1') ? singular : (plural || singular.pluralize))
		end
	
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

	module Models
		class Article < Base
			validates_presence_of :title
			def changed_since_creation
				created_at != updated_at
			end
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

	module Controllers
		class Index < R '/'
			def get
				@articles = Article.all(:order => 'updated_at DESC')
				@title = "List of articles"
				render :list
			end
		end
	
		class Nisse < R '/orly'
			def get
				@env.inspect.to_s
			end
		end
	
		class ArticleX
			def get(title)
				@article = Article.find_by_title(title)
				unless @article.nil?
					@title = @article.title
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
	
		class Favoicon < R '/favicon.ico'
			def get
				File.read("favicon.ico") if File.file?("favicon.ico")
			end
		end
	
		class Stylesheet < R '/default.css'
			def get
				@headers['Content-Type'] = 'text/css'
				Less.parse File.read("default.less")
			end
		end

	end

	module Views
		def content_for(name,&block)
			eval("@content_for_#{name} = (@content_for_#{name} || '') + capture(&block)")
		end
		def yield_to(name)
			eval("@content_for_#{name.to_s}")
		end

		def layout
			html do
				head do
					title @title
					link :href => R(Stylesheet), :rel => 'stylesheet', :type => 'text/css'
					script :type => "text/javascript" do
						text "function pad_body() {"
						text "	var height = document.getElementById('footer').offsetHeight;"
						text "	document.getElementById('footer_padding').style.height = height;"
						text "}"
					end
				end
				body :onload => "pad_body()" do
					div.body! do
						self << yield
					end
					div.footer_padding! {}
					div.footer! do
						div.content do
							self << yield_to(:footer)
							div :class => 'anchor'
						end
					end
				end
			end
		end
	
		def list
			h1 @title
			strong :style => "margin-bottom: 5px;" do
				div 'tags', :class => 'right'
				div 'Title'
			end					
			@articles.each do |article|
				div do
					div :class => 'right' do
						article.tags.split(/ *, */).collect do |t|
							a( t, :href => R(TagX,t) ).to_s
						end.join(', ')
					end
					a article.title, :href => R(ArticleX, article.title)
				end
			end
			content_for("footer") do
				a( 'Index', :href => R(Index), :class => 'left' ) unless @env.PATH_INFO == R(Index)
				div "#{pluralize(@articles.count,'article','articles')}", :class => 'right'
				div @title
				div :class => 'anchor'
			end
		end
	
		def article
			h1 @article.title
			div do
				self << @article.content
			end
			
			# Another template
			content_for("footer") do
				a.left 'Index', :href => R(Index)
				if @article.changed_since_creation
					div.right("updated #{time_ago_in_words(@article.updated_at)} ago")
				end
				div.right "created #{time_ago_in_words(@article.created_at)} ago", :style => "clear: right;"
				div @article.title
				div do
					@article.tags.split(/ *, */).collect do |t|
						a( t, :href => R(TagX,t) ).to_s
					end.join(', ')
				end
			end
		end

		def error
			h1 "FAIL!"
			div "I CAN HAS #{@p.inspect}?"
			div "O NOES! I eated it!"
			div "KTHXBYE"

			content_for("footer") do
				a.left 'Index', :href => R(Index)
				div "Error #{@code}"
			end
		end
	end
end
def Minimal.create
	I18n.default_locale = $conf[:language]
	Minimal::Models::Base.establish_connection($conf[:database])
	Minimal::Models.create_schema
end