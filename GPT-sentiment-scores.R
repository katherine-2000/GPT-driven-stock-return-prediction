#########################################
# Get sentiment scores from GPT for headlines
#########################################

# Load necessary libraries
library(openai)
library(readr)
library(dplyr)
library(stringr)
library(lubridate)
library(plm)
library(lmtest)
library(sandwich)
library(fixest)

# Set OpenAI API key 
Sys.setenv(OPENAI_API_KEY = 'insert-your-api-key-here')

# Define the directory containing the CSV files (adjust accordingly when using)
directory <- "path/to/your/directory"

# List all CSV files in the directory
files <- list.files(directory, pattern = "\\.csv$", full.names = TRUE)

# Process the first file (for demonstration, loop through all files if needed)
file = files[1] 

# Extract company name by removing underscores and ".csv" from filename
company_name <- gsub(" headlines$", "", gsub("_", " ", 
                                             tools::file_path_sans_ext(basename(file))), ignore.case = TRUE)

# Read the CSV file containing headlines
headlines_df <- read_csv(file)


# Create an empty dataframe to store the API responses
responses_df <- data.frame(headline = character(),
                           date = character(),
                           response = character(),
                           stringsAsFactors = FALSE)

# Define the system message once
system_message <- list(
  "role" = "system",
  "content" = paste("Forget all your previous instructions. Pretend you are a financial expert with stock recommendation experience.",
                    "Answer YES if good news, NO if bad news, or UNKNOWN if uncertain in the first line",
                    sprintf("Is this headline good or bad for the stock price of %s in the short term: ", company_name))
)


# Loop through each headline and fetch sentiment using GPT-4o
for (i in 1:nrow(headlines_df)) {
  headline <- headlines_df[i, 1]  # Get the headline from the first column
  date <- headlines_df[i, 2]      # Get the publication date from the second column
  
  # Define the user message for each iteration
  user_message <- list(
    "role" = "user",
    "content" = headline[[1]]
  )
  
  # API call to generate sentiment response
  response <- create_chat_completion(
    temperature = 0.3, 
    max_tokens = 2,
    model = "gpt-4o", 
    messages = list(system_message, user_message),
    
  )
  
  # Access the generated text using $ operator
  generated_text <- response$choices["message.content"]
  
  # Add to the responses dataframe
  responses_df <- rbind(responses_df, data.frame(headline = headline,
                                                 date = date,
                                                 response = generated_text,
                                                 stringsAsFactors = FALSE))
}

# Save a CSV file
write.csv(responses_df, "path/to/save/responses.csv", row.names = FALSE)


#########################################
# Process sentiment scores from GPT responses
#########################################


# Define the folder containing sentiment CSV files (adjust path if needed)
folder_path <- "path/to/sentiment/files"

# List all CSV files in the folder
file_list <- list.files(path = folder_path, full.names = TRUE)

# Function to process each file
process_file <- function(file_path) {
  
  # Read the CSV file
  df <- read.csv(file_path)
  
  # Trim whitespace from 'message.content' column
  df$message.content <- str_trim(df$message.content)
  
  # Convert sentiment values to numeric (UNKNOWN = 0, YES = 1, NO = -1)
  df <- df %>%
    mutate(message.content = case_when(
      message.content == "UNKNOWN" ~ 0,
      message.content == "YES" ~ 1,
      message.content == "NO" ~ -1
    ))
  
  
  # Convert 'Published.Date' column to Date format
  df <- df %>%
    mutate(Published.Date = dmy_hms(Published.Date, tz = "GMT"))
  
  
  # Create the new file name by replacing 'responses_df_' with 'responses_'
  new_file_path <- sub("responses_df_", "responses_", file_path)
  
  
  # Save the modified data back to a new CSV
  write.csv(df, new_file_path, row.names = FALSE)
  
  # Print the file being processed
  print(paste("Processed file:", file_path))
}


# Loop through each sentiment file and process it 
lapply(file_list, process_file) 


#########################################
# Do Predictive Regressions
#########################################


# Define paths to sentiment and returns data directories
sentiment_path_g <- "path/to/processed/sentiment/files/growing_companies"
returns_path_g <- "path/to/return/files/growing_companies"  # (e.g. from Finance Yahoo)

sentiment_path_v <- "path/to/processed/sentiment/files/value_companies"
returns_path_v <- "path/to/return/files/value_companies" #  (e.g. from Finance Yahoo)

# List all sentiment and returns files
sentiment_files_g <- list.files(path = sentiment_path_g, full.names = TRUE)
returns_files_g <- list.files(path = returns_path_g, full.names = TRUE)

sentiment_files_v <- list.files(path = sentiment_path_v, full.names = TRUE)
returns_files_v <- list.files(path = returns_path_v, full.names = TRUE)


# Function to process each pair of sentiment and returns files
process_files <- function(sentiment_file, returns_file) {
  
  # Read sentiment and returns data
  sentiment_df <- read_csv(sentiment_file)
  returns_df <- read_csv(returns_file)
  
  # Convert Published.Date to Date format, ignoring time
  sentiment_df <- sentiment_df %>%
    mutate(Date = as.Date(Published.Date, format = "%Y-%m-%d %H:%M:%S"))
  
  # Aggregate sentiment scores by date
  aggregated_sentiment <- sentiment_df %>%
    group_by(Date) %>%
    summarise(Aggregated.Sentiment = mean(message.content, na.rm = TRUE))
  
  # Convert returns Date to Date format
  returns_df <- returns_df %>%
    mutate(Date = as.Date(Date))
  
  # Merge the aggregated sentiment with returns data
  merged_df <- returns_df %>%
    left_join(aggregated_sentiment, by = "Date")
  
  # Extract company name from file names and clean it - adjust as needed
  company_name <- sub("responses_|\\.csv", "", basename(sentiment_file))
  
  # Add a column for company name
  merged_df <- merged_df %>%
    mutate(Company = company_name)
  
  # Select relevant columns
  merged_df <- merged_df %>%
    select(Date, Daily.Return, Company, Aggregated.Sentiment, Close, Open)
  
  return(merged_df)
}


# Apply the function to each pair of files
all_data_g <- mapply(process_files, sentiment_files_g, returns_files_g, SIMPLIFY = FALSE) %>%
  bind_rows()

all_data_v <- mapply(process_files, sentiment_files_v, returns_files_v, SIMPLIFY = FALSE) %>%
  bind_rows()


# Convert data frames to panel data
pdata_g <- pdata.frame(all_data_g, index = c("Company", "Date"))
pdata_v <- pdata.frame(all_data_v, index = c("Company", "Date"))


# Perform panel regression (Fixed Effects Model) with firm and time fixed effects
model_g <- plm(Daily.Return ~ Aggregated.Sentiment + factor(Date) + factor(Company), data = pdata_g, model = "within")
model_v <- plm(Daily.Return ~ Aggregated.Sentiment + factor(Date) + factor(Company), data = pdata_v, model = "within")


# Alternatively, use fixest library
model_g = feols(Daily.Return ~ Aggregated.Sentiment | Company + Date, data = pdata_g)
model_v = feols(Daily.Return ~ Aggregated.Sentiment | Company + Date, data = pdata_v)

summary_g <- summary(model_g, cluster ~ Company + Date)
summary_v <- summary(model_v, cluster ~ Company + Date)


