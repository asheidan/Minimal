require 'camping'

Camping.goes :Minimal

module Minimal::Models
	class Article < Base
		validates_precense_of :title
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
end
