#!/usr/bin/env ruby

require 'mechanize'
require 'csv'
require 'pry'

class ZillowFavorites
  attr_accessor :username, :password, :favorites

  def initialize(username, password)
    self.username = username
    self.password = password
  end

  def all
    @favorites ||= get_all
  end

  def generate_csv
    CSV.open("favorites.csv", "wb") do |csv|
      csv << ZillowHomeDetail.csv_header

      all.each{|fav| csv << fav.to_csv }
    end
  end

  private

  def get_all
    login

    page = agent.get('https://www.zillow.com/myzillow/Favorites.htm')
    page = page.meta_refresh.first.click

    @favorites = []
    process_favorites_page(page)
    page.links_with(:href => %r{/myzillow/Favorites.htm\?p=\d{1,3}}).each do |link|
      process_favorites_page(link.click)
    end

    @favorites
  end

  def process_favorites_page(page)
    page.links_with(:href => %r{/homedetails}, :text => '').each do |link|
      detail_page = link.click #agent.get(link.href + "?print=true")
      @favorites << ZillowHomeDetail.new(detail_page)
    end
  end

  def login
    return true if @logged_in

    page = agent.get('https://www.zillow.com/myzillow/Favorites.htm')

    form = page.form_with(:name => 'loginForm')
    form.emailAddr = username
    form.password = password

    page = form.submit

    @logged_in = true
  end

  def agent
    @agent ||= Mechanize.new
  end
end

class ZillowHomeDetail
  attr_accessor :page

  def self.csv_header
    [:address, :bedrooms, :bathrooms,
     :year_built, :heating_type, :square_footage,
     :lot_size, :price, :mls_number, :school_ratings,
     :zillow_url ]
  end
  def initialize(page)
    self.page = page
  end

  def address
    page.search('h1.prop-addr').text
  end

  def bedrooms
    find_prop_fact(/Bedrooms:/)
  end

  def bathrooms
    find_prop_fact(/Bathrooms/)
  end

  def year_built
    find_prop_fact(/Year Built/)
  end

  def heating_type
    find_prop_fact(/Heating Type/)
  end

  def square_footage
    find_prop_fact(/Single Family/)
  end

  def lot_size
    find_prop_fact(/Lot/)
  end

  def price
    page.search('h2.prop-value-price').text
  end

  def mls_number
    find_prop_facts_other(/MLS/)
  end

  def zillow_id
    find_prop_facts_other(/Zillow/)
  end

  def school_ratings
    schools_list.map{|s| "#{s[:grade]}: #{s[:rating]}" }.join('; ')
  end

  def zillow_url
    "http://www.zillow.com/homedetails/#{zillow_id}_zpid/"
  end

  def to_csv
    self.class.csv_header.map{|meth| send(meth) }
  end

  private

  def find_prop_fact(matcher)
    elem = prop_facts.find{|f| f.text =~ matcher}

    if elem
      elem.search('span').text
    else
      ''
    end
  end

  def find_prop_facts_other(matcher)
    elem = prop_facts_other.find{|f| f.text =~ matcher}

    if elem
      elem.search('span').text
    else
      ''
    end
  end

  def prop_facts
    @prop_facts ||= page.search('.prop-facts li')
  end

  def prop_facts_other
    @prop_facts_other ||= page.search('.prop-facts-other li')
  end

  def schools_list
    @schools_list ||= page.search('.nearby-schools-list li.nearby-school').map do |raw_school|
      {rating: raw_school.search('.gs-rating-number').text,
       grade:  raw_school.search('.nearby-schools-grades').text}
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  zillow = ZillowFavorites.new(ENV['ZILLOW_USERNAME'], ENV['ZILLOW_PASSWORD'])

  zillow.generate_csv
end
