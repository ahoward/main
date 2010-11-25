#!/usr/bin/env ruby

require 'open-uri'

require 'main'
require 'digest/sha2'

# you have access to a sequel/amalgalite/sqlite db for free
#

Main {
  name :i_can_haz_db

  db {
    create_table(:mp3s) do
      primary_key :id
      String :url
      String :sha
    end unless table_exists?(:mp3s)
  }

  def run
    url = 'http://s3.amazonaws.com/drawohara.com.mp3/ween-voodoo_lady.mp3'
    mp3 = open(url){|fd| fd.read}
    sha = Digest::SHA2.hexdigest(mp3)

    db[:mp3s].insert(:url => url, :sha => sha)
    p db[:mp3s].all
    p db
  end
}
