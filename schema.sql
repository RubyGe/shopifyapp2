CREATE TABLE categories (
  id serial PRIMARY KEY,
  name varchar(255) NOT NULL,
  description text,
  url varchar(255) NOT NULL,
  updated_at timestamp NOT NULL DEFAULT NOW()
);

CREATE TABLE subcategories(
  id serial PRIMARY KEY,
  category_id int REFERENCES categories(id) NOT NULL,
  name varchar(255) NOT NULL,
  url varchar(255) NOT NULL,
  updated_at timestamp NOT NULL DEFAULT NOW()
);

CREATE TABLE developers(
  id serial PRIMARY KEY,
  name varchar(255),
  url varchar(255),
  updated_at timestamp DEFAULT NOW()
);

CREATE TABLE apps(
  id serial PRIMARY KEY,
  name varchar(255) NOT NULL,
  detail_scraped boolean NOT NULL DEFAULT false, -- whether the scraper has scrapped the app listing details
  url varchar(255) NOT NULL,
  developer_id int REFERENCES developers(id),
  support_email varchar(255),
  updated_at timestamp DEFAULT NOW()
);


CREATE TABLE review_summary(
  id serial PRIMARY KEY,
  app_id int REFERENCES apps(id),
  review_count_total int DEFAULT 0,
  review_ratings numeric (2, 1) DEFAULT 0 CHECK (review_ratings BETWEEN 0 AND 5),
  review_count_5_stars int DEFAULT 0,
  review_count_4_stars int DEFAULT 0,
  review_count_3_stars int DEFAULT 0,
  review_count_2_stars int DEFAULT 0,
  review_count_1_stars int DEFAULT 0,
  updated_at timestamp DEFAULT NOW()
);

CREATE TABLE pricing_plans(
  id serial PRIMARY KEY,
  app_id int REFERENCES apps(id),
  title varchar(255),
  price varchar(255),
  bullets text,
  updated_at timestamp DEFAULT NOW()
);

CREATE TABLE descriptions(
  id serial PRIMARY KEY,
  app_id int REFERENCES apps(id),
  key_benefits_1_header varchar(255),
  key_benefits_1_content text,
  key_benefits_2_header varchar(255),
  key_benefits_2_content text,
  key_benefits_3_header varchar(255),
  key_benefits_3_content text,
  content text NOT NULL,
  updated_at timestamp DEFAULT NOW()
);

CREATE TABLE apps_subcategories(
  id serial PRIMARY KEY,
  subcategory_id int REFERENCES subcategories(id),
  app_id int REFERENCES apps(id),
  ranking int NOT NULL DEFAULT 0,
  updated_at timestamp DEFAULT NOW()
);

CREATE TABLE apps_categories(
  id serial PRIMARY KEY,
  category_id int REFERENCES categories(id),
  app_id int REFERENCES apps(id),
  ranking int NOT NULL DEFAULT 0,
  updated_at timestamp NOT NULL DEFAULT NOW()
);

CREATE TABLE reviews (
  id serial PRIMARY KEY,
  app_id int REFERENCES apps(id),
  posted date NOT NULL,
  rating int NOT NULL CHECK (rating BETWEEN 0 AND 5),
  content text NOT NULL DEFAULT '',
  user_name varchar(255) NOT NULL,
  updated_at timestamp NOT NULL DEFAULT NOW()
);