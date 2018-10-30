# Shopify app marketplace scrapper for the new marketplace

Database schema can be found in schema.sql file.

If you're running the scraper for the first time, make sure you first create the database and the tables:

```
createdb shopifyapp2
psql shopifyapp2 < schema.sql
```

## To start a new scraper, run 

```
ruby start.rb
```

ShopifyAppScraper.new(update_categories: true/false, scrape_reviews: true/false)

- Since Shopify app marketplace doesn't update categories so often, you can choose not to update the category data in your database. Your database will use the most up-to-date category information to start.

- Since reviews have a lot of content, you can opt out of review scraping to save time.

## #fetch_categories

The function will fetch categories and subcategories as well as their urls. 

## #fetch_app_listing_urls

The function will traverse each category (NOT subcategory) and find app listings and their urls under those categories

## to-dos
[ ] Add sub_category tags
[ ] Add review detail scraping



