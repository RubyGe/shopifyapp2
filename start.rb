require_relative './lib/app_parser_module'
require_relative './lib/database_helpers_module'
require_relative './lib/scraper'

ShopifyAppScraper.new(update_categories: false, scrape_reviews: false).run