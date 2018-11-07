# Shopify app marketplace scraper for the new marketplace launched in Sep 2018.

Database schema can be found in schema.sql file.

If you're running the scraper for the first time through your command line, make sure you first create the database and tables:

```
createdb shopifyapp2
psql shopifyapp2 < schema.sql
```

## To start a new scraper, run 

```
ruby start.rb
```

## How it works
The scraper does 3 things in 3 steps:
1. It first fetches a list of app categories from the app marketplace homepage
2. It then traverses through each category to fetch app listing urls and the app's ranking under each category.
3. Once the urls of the app listings are collected, the scraper will visit each app listing and scrape data from there.

When you run start.rb, you can opt out of the 1st and 2nd steps if those steps have already been performed but the program got interrupted during step 3.

In the start.rb file, you can find:

ShopifyAppScraper.new(update_categories: true/false, update_apps: true/false, scrape_reviews: true/false)

- update_categories option: Since Shopify app marketplace doesn't update categories so often, you can choose not to update the category data in your database everytime you start the scraper. The scraper will use the category information it scraped last time to fetch app listings under those categories.

- update_apps option: If for some reason your scraping session got interrupted when the scraper was running step #3, you can set this option as false and the scraper will pick up from where it left in step 3.

- Since reviews have a lot of content, you can opt out of review scraping to save time.

*P.S. the review content scraping function hasn't been built yet so please always set this option as false for now.*

## #fetch_categories

This class method will fetch categories and subcategories as well as their urls as described in Step 1 above.

## #fetch_app_listing_urls

This method will traverse each category (NOT subcategory) and find app listings and their urls under those categories along with the app's category ranking, as described in Step 2 above.

## to-dos
- [ ] Add sub_category tags
- [ ] Add review detail content scraping



