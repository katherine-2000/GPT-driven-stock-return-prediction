#########################################
# Get sentiment scores from GPT for headlines
#########################################

# Load necessary libraries
library(openai)
library(readr)
library(dplyr)
library(stringr)
library(lubridate)


# Set OpenAI API key 
Sys.setenv(OPENAI_API_KEY = 'insert-your-api-key-here')

# Define the directory containing the CSV files (adjust accordingly when using)
directory <- "path/to/your/directory"

# List all CSV files in the directory (here it is assumed that file names contain company names)
files <- list.files(directory, pattern = "\\.csv$", full.names = TRUE)

# Process the first file (for demonstration, loop through all files if needed)
file = files[1] 

# Extract company name by removing underscores and ".csv" from filename
company_name <- gsub(" headlines$", "", gsub("_", " ", 
                                             tools::file_path_sans_ext(basename(file))), ignore.case = TRUE)

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
process_sentiment_file <- function(file_path) {
  
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

  # save the files in a new folder (if needed)
  new_file_path <- "path/to/processed/sentiment/files" 
  
  # Save the modified data back to a new CSV
  write.csv(df, new_file_path, row.names = FALSE)
  
  # Print the file being processed
  print(paste("Processed file:", file_path))
}


# Loop through each sentiment file and process it 
lapply(file_list, process_sentiment_file) 
