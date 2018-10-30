require 'pg'

module DatabaseHelpers
  CONNECTION = PG.connect(dbname: "shopifyapp2")

  def write_categories(categories)
    categories.each do |name, sub_categories|
      category_link = sub_categories.last[:link]
      sub_categories.pop
      sql = "INSERT INTO categories (name, url, updated_at) VALUES ($1, $2, $3);"
      # sql = "INSERT INTO categories (name, url, updated_at) VALUES ('#{name}', '#{category_link}', '#{timestamp}');"
      params = [name, category_link, @timestamp]
      CONNECTION.exec_params(sql, params)

      sql = "SELECT id FROM categories WHERE name = $1 AND updated_at = $2;"
      params = [name, @timestamp]

      category_id = CONNECTION.exec_params(sql, params)
      category_id = category_id.values.flatten[0].to_i

      sub_categories.each do |item|
        sql = "INSERT INTO subcategories (category_id, name, url, updated_at) VALUES
               (#{category_id}, '#{item[:name]}', '#{item[:link]}', '#{timestamp}');"
        sql = "INSERT INTO subcategories (category_id, name, url, updated_at) VALUES
               ($1, $2, $3, $4);"
        params = [category_id, item[:name], item[:link], @timestap]
        CONNECTION.exec_params(sql, params)
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
    sql = "SELECT id FROM developers WHERE name = $1 AND url = $2"
    params = [developers[0], developers[1]]
    result = CONNECTION.exec_params(sql, params)

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
    sql = "UPDATE apps SET support_email = $1 WHERE id = $2"
    params = [email, app_id]
    CONNECTION.exec_params(sql, params)
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
      categories << [category["id"], category["name"], ShopifyAppScraper::ROOT_URL + category["url"]]
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