#!/usr/bin/env ruby

require 'rubygems'
require 'active_support'
require 'net/http'
require 'uri'
require 'rexml/document'
begin
  require 'id3lib'
rescue
  puts "This script requires id3lib:\n\tsudo port install id3lib\n\tsudo gem install id3lib-ruby"
end

MusicDirectory = Dir.home + "/Music/iTunes/iTunes Music/Music"
LastFM_API_Url = "http://ws.audioscrobbler.com/2.0"
LastFM_API_Key = "42f57b3d61e894f5411ec4d42d8bf4d3"
LastFM_Secret_Key = "4dba2047475efa0e03d5e99824af37f9"

MinimumTagCount = 2
MaxTags = 5

throw "iTunes music directory not found!" unless File::exists?(MusicDirectory)

class Last_fm

  class Artist
    @name
    
    def initialize _name
      @name = _name
    end
    
    def top_tags _max=5
      request_uri = "#{LastFM_API_Url}/?method=artist.gettoptags&artist=#{@name}&api_key=#{LastFM_API_Key}" # TODO url encode
      uri = URI.parse(URI.escape(request_uri)) or raise "invalid API url."
      tags = []
      
      puts "Searching Last.FM for: #{@name}:"
      request = Net::HTTP.get_response(uri.host, uri.request_uri) or raise "Network error accessing last.fm api."
      request.body
      xml = request.body
      doc = REXML::Document.new(xml)
      
      if doc.root.elements['toptags'].nil? then
        puts "Error parsing xml:"
        puts doc.root
      else
        doc.root.elements['toptags'].each_with_index do |tag, index|
          break if index == MaxTags * 2
          if tag.respond_to?(:elements) then
            tags << tag.elements['name'].text.capitalize
          end
        end
      end
      tags.join(', ')
    end
    
  end
  
end

class Mp3Tagger
  def self.tag_files_in(_artist)
    _directory = "#{MusicDirectory}/#{_artist}"
    files_tagged_count = 0
    files_found_count = 0
    puts "Processing: [#{_directory}]"
    lastfm_connection = Last_fm::Artist.new(_artist)
    top_tags = nil
    
    
    Dir.chdir(_directory)
    musicfiles = File.join("**", "*.mp3")
    Dir.glob(musicfiles).each do |file|
      file_to_tag = ID3Lib::Tag.new(file)
      if file_to_tag.grouping.nil? then
        top_tags ||= lastfm_connection.top_tags # fill the tag cache if it is empty
        file_to_tag.grouping = top_tags
        file_to_tag.update!
        files_tagged_count += 1
      end  
      files_found_count += 1
    end
    puts "\t#{files_tagged_count}/#{files_found_count} files tagged."
  end
end

Dir.chdir(MusicDirectory)
Dir.glob('*') do |artist|
  Mp3Tagger.tag_files_in(artist)
end
