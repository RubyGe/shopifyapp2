CREATE TABLE categories (
  id serial PRIMARY KEY,
  name varchar(255) NOT NULL,
  description text NOT NULL,
  url varchar(255) NOT NULL
);

CREATE TABLE subcategories(
  id serial PRIMARY KEY,
  category_id int REFERENCES categories(id) NOT NULL,
  url_slug varchar(255) NOT NULL
);

CREATE TABLE app_listings(
  id serial PRIMARY KEY,
  name varchar(255) NOT NULL,
  url varchar(255) NOT NULL,
  developer_name varchar(255) NOT NULL,
  developer_url varchar(255) NOT NULL,
  pricing text NOT NULL,
  support_email varchar(255) NOT NULL,
  description_selling_points text NOT NULL,
  description_content text NOT NULL,
  review_count_total int NOT NULL DEFAULT 0,
  review_ratings int NOT NULL DEFAULT 0 CHECK (review_ratings BETWEEN 0 AND 5),
  review_count_5_stars int NOT NULL DEFAULT 0,
  review_count_4_stars int NOT NULL DEFAULT 0,
  review_count_3_stars int NOT NULL DEFAULT 0,
  review_count_2_stars int NOT NULL DEFAULT 0,
  review_count_1_stars int NOT NULL DEFAULT 0
);

CREATE TABLE reviews (
  id serial PRIMARY KEY,
  app_listing_id int REFERENCES app_listings(id),
  posted date NOT NULL,
  rating int NOT NULL CHECK (rating BETWEEN 0 AND 5),
  content text NOT NULL DEFAULT '',
  user_name varchar(255) NOT NULL
);