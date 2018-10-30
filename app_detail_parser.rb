module AppPageParser

  def parse_description(page) # => [ headers_array, content_array, content ]
    begin
      key_benefits = page.xpath("//div[@class='key-benefits-section']")
      key_benefits_headers = key_benefits.css("h3").map(&:text)
      key_benefits_contents = key_benefits.css('p.text-major').map(&:text)
      description_area = page.xpath("//div[contains(@class, 'app-listing-description')]")
      content = description_area.css("div.ui-expandable-content__inner").text.strip
    rescue StandardError => e
      puts "Error: #{e}"
    else
      [key_benefits_headers, key_benefits_contents, content]
    end
  end

  def parse_support(page)
    @support_info = {}
    begin
      support_section = page.xpath("//ul[@class='app-support-list']")
      email = support_section.xpath("//span[contains(text(), '@')]").text.strip
    rescue StandardError=>e
      puts "Error: #{e}"
    else
      email
    end
  end

  def parse_pricing(page)
    begin
      pricing_area = page.xpath("//div[@class='app-listing__pricing-plans']")
      cards = pricing_area.css("div.pricing-plan-card")
      titles = cards.css("h5.pricing-plan-card__title-kicker").map { |node| node.text.strip }
      prices = cards.css("h3.pricing-plan-card__title-header").map { |node| node.text.strip}
      bullets = cards.css("ul.pricing-plan-card__details-list").map { |node| node.text}
    rescue StandardError => e
      puts "Error: #{e}"
    else
      [ titles, prices, bullets ]
    end
  end

  def parse_developer(page)
    #   attr_reader :name, :url, :app_listings, :support_info
    begin
      link = page.css("div.ui-app-store-hero__header span.ui-app-store-hero__header__subscript a")[0]
      name = link.text
      url = link['href']
    rescue StandardError => e
      puts "Error: #{e}"
    else
      [ name, url ]
    end
  end

  def parse_reviews_summary(page)

    begin
      review_section = page.css("div.reviews-summary")
      review_count = review_section.css("span.reviews-summary__count").text.match(/Based on (.+) reviews/)[1]
      review_rating = review_section.css("span.reviews-summary__overall-rating span.ui-star-rating__rating").text.gsub(" of 5 stars", '')
      break_down = review_section.css("ul.reviews-summary__rating-list li.reviews-summary__rating-breakdown")
      review_stars = []
      break_down.each do |item|
        review_stars << item.css("div.reviews-summary__review-count").text.match(/\((.+)\)/)[1]
      end
    rescue StandardError => e
      puts "Error: #{e}"
    else
      [ review_count, review_rating, review_stars ]
    end 
  end
end