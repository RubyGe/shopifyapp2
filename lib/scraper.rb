require 'open-uri'
require 'nokogiri'

module ScraperHelpers
  SLEEP = {low: 0.5, high: 1.5}

  def pause(scale)
    low = SLEEP[:low] * scale
    high = SLEEP[:high] * scale
    puts "Sleeping..."
    sleep(rand(low..high))
  end
end

class ShopifyAppScraper
  ROOT_URL = "https://apps.shopify.com"
  
  include DatabaseHelpers
  include ScraperHelpers
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
