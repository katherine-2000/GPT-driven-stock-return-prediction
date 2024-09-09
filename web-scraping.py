# Load libraries
import csv
from datetime import datetime, timedelta
import feedparser
from Levenshtein import ratio
from urllib.parse import quote

# Define the time period
start_date = datetime(2023, 11, 1).date()
end_date = datetime(2024, 5, 28).date()

# Define the interval for fetching news (e.g., 5 days)
interval_days = 5

# Function to check if a headline is unique based on Levenshtein ratio
def is_unique(headline, existing_headlines):
    
    for existing_headline in existing_headlines:
        
        # If the similarity is 50% or more, consider the headline as not unique
        if ratio(headline, existing_headline) >= 0.5:
            
            return False
            
    return True

# Function to fetch news for a given date range using Google News RSS feeds
def fetch_news_for_date_range(company_name, single_date, interval_days):
    
    # Calculate the end date of the interval
    next_day = single_date + timedelta(days=interval_days)
    
    # URL encode the company name
    encoded_company_name = quote(company_name)
    
    # Create a query string with the company name and the date range (after:start_date, before:end_date)
    query = f'{encoded_company_name}%20after:{single_date.strftime("%Y-%m-%d")}%20before:{next_day.strftime("%Y-%m-%d")}'
    
    # Create the RSS feed URL for Google News
    rss_url = f'https://news.google.com/rss/search?q={query}&hl=en-US&gl=US&ceid=US:en'
    
    # Parse the RSS feed and return the entries (news articles)
    feed = feedparser.parse(rss_url)
    
    return feed.entries

# Read company names from CSV file
company_names = []

with open('path/to/file', 'r') as csvfile:
    
    csvreader = csv.reader(csvfile)
    
    next(csvreader)  # Skip the header
    
    for row in csvreader:
        
        # Split the row by ';' and get the first column (company name)
        company_name = row[0].split(';')[0].strip()
        
        if company_name:  # Add the company name to the list if it's not empty
            company_names.append(company_name)

# Process news for each company
for company in company_names:
    print(f"Processing news for {company}")
    
    current_date = start_date
    
    # List to store unique headlines and their metadata (date, URL)
    unique_headlines_data = []

    # Loop over the date range, fetching news in intervals
    while current_date <= end_date:
        
        # Fetch news for this interval
        entries = fetch_news_for_date_range(company, current_date, interval_days)
        batch_headlines = []

        # Loop through each news entry (article)
        for entry in entries:
            headline = entry['title'] # Extract the headline
            published_date = entry['published'] # Extract the publication date
            url = entry['link'] # Extract the article's URL
            batch_headlines.append({'headline': headline, 'published_date': published_date, 'url': url})

        # Sort headlines by their published date to ensure chronological order
        sorted_headlines = sorted(batch_headlines, key=lambda x: datetime.strptime(x['published_date'], '%a, %d %b %Y %H:%M:%S %Z'))

        # Check for uniqueness within the current batch of headlines
        for headline_data in sorted_headlines:

            # Use the is_unique function to ensure headlines aren't too similar to already processed headlines
            if is_unique(headline_data['headline'], [item['headline'] for item in unique_headlines_data]):
                
                # Append unique headlines within the batch to the overall unique_headlines_data
                unique_headlines_data.append(headline_data)

        # Move to the next interval (i.e., next batch of days)
        current_date += timedelta(days=interval_days)

    # Write unique headlines to a CSV file for the company
    csv_file = f'path/to/folder{company.replace(" ", "_")}_headlines.csv'
    
    with open(csv_file, 'w', newline='', encoding='utf-8') as file:
        
        writer = csv.writer(file)
        
        writer.writerow(['Headline', 'Published Date', 'URL'])
        
        for entry in unique_headlines_data:
            
            # Write each unique headline, along with its published date and URL
            writer.writerow([entry['headline'], entry['published_date'], entry['url']])

    print(f"Finished processing news for {company}")

print("All companies processed.")
