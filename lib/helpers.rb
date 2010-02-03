include Nanoc3::Helpers::Rendering
include Nanoc3::Helpers::Blogging
include Nanoc3::Helpers::XMLSitemap
require 'builder'
require 'fileutils'
require 'time'

# Hyphens are converted to sub-directories in the output folder.
#
# If a file has two extensions like Rails naming conventions, then the first 
# extension is used as part of the output file.
#
#   sitemap.xml.erb # => sitemap.xml
#
# If the output file does not end with an .html extension, item[:layout] is 
# set to 'none' bypassing the use of layouts.
# 
def route_path(item)
  # in-memory items have no file
  return item.identifier + "index.html" if item[:file].nil?
  
  url = item[:file].path.gsub(/^content/, '')
  
  # if 2 extensions, use first extension as the output file
  if url.match(/(\.[a-zA-Z0-9]+){2}$/)
    url.gsub!(item[:extension], '')
  else
    url.gsub!(item[:extension], '.html')
  end

  # Strip leading date
  url.gsub!(/[0-9]{4}-[01][0-9]-[0-3][0-9]-/, '')
  
  #if url.include?('-')
    #url = url.split('-').join('/')                # /2010/01/01-some_title.html -> /2010/01/01/some_title.html
  #end

  # used in Rules to bypass layout
  if File.extname(url) != ".html"
    item[:layout] = "none"
  end

  url
end

# Creates in-memory tag pages from partial: layouts/_tag_page.haml
def create_tag_pages
  tag_set(items).each do |tag|
    items << Nanoc3::Item.new(
      "= render('_tag_page', :tag => '#{tag}')", # use locals to pass data
      { :title => "Category: #{tag}"},      # attributes
      "/tags/#{tag}/"                        # identifier
    )
  end
end

# Dates may be encoded in the filename instead of the meta section at the top 
# of each file.
def add_missing_info
  items.each do |item|
    if item[:file]
      # nanoc3 >= 3.1 will have this feature, add for older versions
      item[:extension] ||= File.extname(item[:file].path)
    end
    next if item[:kind] != "article"
    item[:created_at] ||= derive_created_at(item)
    # sometimes nanoc3 stores created_at as Date instead of String causing a bunch of issues
    item[:created_at] = item[:created_at].to_s if item[:created_at].is_a?(Date)
  end
end

#=> { 2010 => { 12 => [item0, item1], 3 => [item0, item2]}, 2009 => {12 => [...]}}
def articles_by_year_month
  result = {}
  current_year = current_month = year_h = month_a = nil

  sorted_articles.each do |item|
    d = Date.parse(item[:created_at])
    if current_year != d.year
      current_month = nil
      current_year = d.year
      year_h = result[current_year] = {}
    end

    if current_month != d.month
      current_month = d.month
      month_a = year_h[current_month] = [] 
    end

    month_a << item
  end

  result
end

# Checks whether the current page is the front page
def is_front_page?
    @item.identifier == '/'
end

# Prettifies a time given as a parseable string for UI display
def pretty_time(time)
  Time.parse(time).strftime("%B %d, %Y") if !time.nil?
end

private

# Determines when an article was created given its filename. This relies on 
# articles being in the format 'yyyy-mm-dd-some-article-name.xxx'.
def derive_created_at(item)
  File.basename(item.identifier).gsub('-', '/').split('/')[0,3].join('/')
end

