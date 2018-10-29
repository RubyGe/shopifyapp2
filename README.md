# Shopify app marketplace scrapper for the new marketplace

DB structure:

TABLE: categories
id serial PRIMARY KEY,
name text,
url text

TABLE: sub_categories
id serial PRIMARY KEY,
category_id int REFERENCES categories,
name varchar(255),
url_slug text

TABLE: app_listings
id serial PRIMARY KEY,
category_id

