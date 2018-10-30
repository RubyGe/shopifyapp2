require 'nokogiri'
require 'pg'
require 'open-uri'
require 'pry'

require_relative 'app_detail_parser'

ROOT_URL = "https://apps.shopify.com"
CATEGORY_PATH = "/browse"

module ScrapeHelpers
  SLEEP = {low: 0.5, high: 1.5}

  def pause(scale)
    low = SLEEP[:low] * scale
    high = SLEEP[:high] * scale
    puts "Sleeping..."
    sleep(rand(low..high))
  end
end

module DatabaseHelpers
  CONNECTION = PG.connect(dbname: "shopifyapp2")

  def write_categories(categories)
    categories.each do |name, sub_categories|
      category_link = sub_categories.last[:link]
      sub_categories.pop

      sql = "INSERT INTO categories (name, url, updated_at) VALUES ('#{name}', '#{category_link}', '#{timestamp}');"
      CONNECTION.exec sql

      sql = "SELECT id FROM categories WHERE name = '#{name}' AND updated_at = '#{timestamp}';"
      category_id = CONNECTION.exec sql
      category_id = category_id.values.flatten[0].to_i

      sub_categories.each do |item|
        sql = "INSERT INTO subcategories (category_id, name, url, updated_at) VALUES
               (#{category_id}, '#{item[:name]}', '#{item[:link]}', '#{timestamp}');"
        CONNECTION.exec sql
      end
    end
  end

  def find_existing_app_id(name, url)
    sql = "SELECT id FROM apps WHERE name = $1 AND url = $2 AND updated_at = $3;"
    result = CONNECTION.exec_params(sql, [name, url, @timestamp])

    id = nil

    if result.ntuples == 1
      id = result.values.flatten[0]
    elsif  result.ntuples > 1
      id = result.values.flatten[0]
      "Find multiple duplication of the same app. App ids: #{result.values}. Append to id: #{id}"
    end
    id
  end

  def fetch_last_item_id(table)
    sql = "SELECT id FROM #{table} ORDER BY id DESC LIMIT 1"
    result = CONNECTION.exec sql
    result.values.flatten[0].to_i
  end

  def insert_app(name, url)
    sql = "INSERT INTO apps (name, url, updated_at) VALUES ($1, $2, $3)"
    CONNECTION.exec_params(sql, [name, url, @timestamp])
  end

  def insert_app_category_relationship(app_id, category_id, ranking)
    sql = "INSERT INTO apps_categories (app_id, category_id, updated_at, ranking) VALUES ($1, $2, $3, $4)"
    CONNECTION.exec_params(sql, [app_id, category_id, @timestamp, ranking])
  end

  def  write_apps_categories(category_id, apps)
    ranking_counter = 0
    apps.each do |listing|
      name = listing[0]
      url = listing[1]
      ranking_counter += 1

      # determine if an app already existing in the database during the same scrapping session
      app_id = find_existing_app_id(name, url)

      if app_id.nil?
        insert_app(name, url)
        app_id = fetch_last_item_id("apps")
        insert_app_category_relationship(app_id, category_id, ranking_counter)
      else
        insert_app_category_relationship(app_id, category_id, ranking_counter)
      end
    end
  end

  def write_descriptions(app_id, descriptions)
    sql = "INSERT INTO descriptions (app_id, key_benefits_1_header, 
           key_benefits_2_header, key_benefits_3_header,
           key_benefits_1_content, key_benefits_2_content,
           key_benefits_3_content, content) 
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8)"

    params = [app_id] + descriptions[0] + descriptions[1] + [descriptions[2]]

    CONNECTION.exec_params(sql, params)
  end

  def write_developer(app_id, developers)
    sql = "SELECT id FROM developers WHERE url = '#{developers[1]}' AND name = '#{developers[0]}'"
    result = CONNECTION.exec sql

    if result.ntuples > 0
      developer_id = result.values.flatten[0]
    else
      sql = "INSERT INTO developers (name, url) VALUES
             ($1, $2)"
      params = [ developers[0], developers[1] ]
      CONNECTION.exec_params(sql, params)

      developer_id = fetch_last_item_id("developers")
    end

    sql = "UPDATE apps SET developer_id = #{developer_id} WHERE id = #{app_id}"
    CONNECTION.exec sql
  end

  def write_reviews_summary(app_id, reviews_summary)
    sql = "INSERT INTO review_summary (app_id, review_count_total, review_ratings,
           review_count_5_stars, review_count_4_stars, review_count_3_stars,
           review_count_2_stars, review_count_1_stars)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8)"
    params = [app_id, reviews_summary[0], reviews_summary[1]] + reviews_summary[2]
    CONNECTION.exec_params(sql, params)
  end

  def write_pricing(app_id, pricing)
    sql = "INSERT INTO pricing_plans (app_id, title, price, bullets)
           VALUES ($1, $2, $3, $4)"
    pricing_count = pricing[1].size
    (0...pricing_count).each do |idx|
      params = [ app_id, pricing[0][idx], pricing[1][idx], pricing[2][idx] ]
      CONNECTION.exec_params(sql, params)
    end
  end

  def write_support(app_id, email)
    sql = "UPDATE apps SET support_email = '#{email}' WHERE id = #{app_id}"
    CONNECTION.exec sql
  end

  def scraped?(id)
    sql = "SELECT detail_scraped FROM apps WHERE id = #{id}"
    result = CONNECTION.exec sql
    result.values.flatten[0] == 't' ? true : false
  end

  def mark_scrapped(id)
    sql = "UPDATE apps SET detail_scraped = true WHERE id = #{id}"
    CONNECTION.exec sql
  end

  def write_app_details(app_id, descriptions, email, pricing, developer, reviews_summary)
    # test if the app listing has already been scraped
    write_descriptions(app_id, descriptions)
    write_developer(app_id, developer)
    write_reviews_summary(app_id, reviews_summary)
    write_pricing(app_id, pricing)
    write_support(app_id, email)

    mark_scrapped(app_id)
  end
  
  def get_most_recent_update_timestamp(table_name)
    sql = "SELECT updated_at FROM #{table_name} ORDER BY updated_at DESC LIMIT 1;"
    timestamp = CONNECTION.exec sql
    timestamp.values.flatten[0]
  end

  def read_categories
    recent_update_timestamp = get_most_recent_update_timestamp("categories")
    sql = "SELECT id, name, url FROM categories WHERE updated_at = '#{recent_update_timestamp}'"
    result = CONNECTION.exec sql

    categories = []

    result.each do |category|
      categories << [category["id"], category["name"], ROOT_URL + category["url"]]
    end

    categories
  end

  def read_apps
    recent_update_timestamp = get_most_recent_update_timestamp("apps")
    timestamp = Time.parse(recent_update_timestamp)
    sql = "SELECT id, name, url FROM apps WHERE updated_at = '#{recent_update_timestamp}' ORDER BY id"
    result = CONNECTION.exec sql
    apps = []

    result.each do |app|
      apps << [app["id"], app["name"], app["url"]]
    end
    [apps, timestamp]
  end
end

class ShopifyAppScraper
  include DatabaseHelpers
  include ScrapeHelpers
  include AppPageParser

  attr_accessor :timestamp, :categories, :developers, :apps

  def initialize(options = { update_categories: false, scrape_reviews: false})
    @timestamp = Time.now
    @categories = []
    @developers = {}
    @apps = []
    @update_categories = options[:update_categories]
    @scrape_reviews = options[:scrape_reviews]
  end

  def fetch_sub_categories(item)
    sub_categories = []
    item.css("a.as-nav__link").each do |sub_item|
      name = sub_item.text.strip
      link = sub_item['href']
      sub_categories << {name: name, link: link}
    end
    # if there is no sub_category, return the link to the current category
    sub_categories
  end

  def fetch_categories
    # categories = { cat1: [sub_cat1, sub_cat2], cat2: [sub_cat2, sub_cat3]}
    categories = Hash.new

    begin
      page = Nokogiri::HTML(open(ROOT_URL))
      nav_items = page.xpath("//div[@id='ASCategoryNav']/ul/li")
      nav_items.each do |item|
        name = item.xpath("span[@class='as-nav__link']").text.strip
        if name.empty?
          name = item.xpath("a[@class='as-nav__link']").text.strip
        end
        categories[name] = fetch_sub_categories(item)
      end
    rescue StandardError=>e
      puts "Encountered an error fetching categories: #{e}"
    else
      puts "Successfully fetched categories!"
    ensure
      pause(1)
    end

    if !categories.empty?
      write_categories(categories)
    end
  end

  def fetch_category_listings(page)
    names = nil
    urls = nil
    begin
      cards = page.xpath("//div[@class='grid__item grid__item--tablet-up-half grid-item--app-card-listing']")
      names = cards.xpath("//h4[@class='ui-app-card__name']").map(&:text)
      urls = cards.xpath('a[@class="ui-app-card"]/@href').map { |href| href.text.gsub(/\?.+/, '') }
    rescue StandardError => e
      puts "Error: #{e}"
    else
      puts "Successfully fetched apps.."
    end
    names.zip(urls)
  end

  def fetch_category_app_urls(categories)
    # category = [id, name, url]
    categories.each do |category|
      category_apps = []
      next_url = category[2]

      loop do
        begin 
          page = Nokogiri::HTML(open(next_url))
          pagination = page.xpath("//a[@class='search-pagination__next-page-text']/@href")[0]
        rescue StandardError=>e
          puts "Error: #{e}"
        else
          puts "Successfully fetched #{next_url}"
          category_apps += fetch_category_listings(page)
        ensure
          pause(1)
        end
        break if !pagination
        next_url = ROOT_URL + pagination.text
      end

      write_apps_categories(category[0], category_apps)
    end
  end

  def fetch_app_details
    @apps.each do |app|
      app_details = {}
      app_id = app[0]
      app_url = app[2]
      p [app_id, app_url]

      # if the app record details has been scraped, skip the session
      next if scraped?(app_id)
      begin
        page = Nokogiri::HTML(open(app_url))
      rescue StandardError=>e
        puts "Error: #{e}"
      else
        descriptions = parse_description(page) # [ key_benefits_headers, key_benefits_contents, content ]
        email = parse_support(page) # email
        pricing = parse_pricing(page) # [ titles, prices, bullets ]
        developer = parse_developer(page) # [ name, url ]
        reviews_summary = parse_reviews_summary(page) # [ review_count, review_rating, review_stars ] review_stars is an array with 5 numbers
        # reviews = parse_reviews if @scrape_reviews == true
      ensure
        pause(1)
      end
      write_app_details(app_id, descriptions, email, pricing, developer, reviews_summary)
    end
  end

  def run
    fetch_categories if @update_categories == true

    @categories = read_categories
    fetch_category_app_urls(@categories)

    @apps, @timestamp = read_apps
    fetch_app_details
  end
end

ShopifyAppScraper.new(update_categories: true, scrape_reviews: false).run
