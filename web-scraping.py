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
        if ratio(headline, existing_headline) >= 0.5:
            return False
    return True

# Function to fetch news for a given date range
def fetch_news_for_date_range(company_name, single_date, interval_days):
    next_day = single_date + timedelta(days=interval_days)
    encoded_company_name = quote(company_name)
    query = f'{encoded_company_name}%20after:{single_date.strftime("%Y-%m-%d")}%20before:{next_day.strftime("%Y-%m-%d")}'
    rss_url = f'https://news.google.com/rss/search?q={query}&hl=en-US&gl=US&ceid=US:en'
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
        if company_name:  # Ensure it's not empty
            company_names.append(company_name)

# Process news for each company
for company in company_names:
    print(f"Processing news for {company}")
    
    current_date = start_date
    unique_headlines_data = []

    while current_date <= end_date:
        # Fetch news for this interval
        entries = fetch_news_for_date_range(company, current_date, interval_days)
        batch_headlines = []

        for entry in entries:
            headline = entry['title']
            published_date = entry['published']
            url = entry['link']
            batch_headlines.append({'headline': headline, 'published_date': published_date, 'url': url})

        # Sort headlines by published date
        sorted_headlines = sorted(batch_headlines, key=lambda x: datetime.strptime(x['published_date'], '%a, %d %b %Y %H:%M:%S %Z'))

        # Check for uniqueness within the fetched batch of news entries
        for headline_data in sorted_headlines:
            if is_unique(headline_data['headline'], [item['headline'] for item in unique_headlines_data]):
                # Append unique headlines within the batch to the overall unique_headlines_data
                unique_headlines_data.append(headline_data)

        # Move to the next interval
        current_date += timedelta(days=interval_days)

    # Write unique headlines to a CSV file for the company
    csv_file = f'path/to/folder{company.replace(" ", "_")}_headlines.csv'
    with open(csv_file, 'w', newline='', encoding='utf-8') as file:
        writer = csv.writer(file)
        writer.writerow(['Headline', 'Published Date', 'URL'])
        for entry in unique_headlines_data:
            writer.writerow([entry['headline'], entry['published_date'], entry['url']])

    print(f"Finished processing news for {company}")

print("All companies processed.")



