# Predictive Power of ChatGPT in Equity Markets

This repositary provides a code used to scrape news and access GPT-4o model to compare the effectiveness of the Language Model in predicting stock returns for Blue Chips and Growing Companies.

## Web-scraping

The purpose is to identify the news headlines available for the pre-selected Blue Chips and Growing Companies during the observed period from November 2023 to May 2024. Scraping Google News is used to understand the media coverage and sentiment around these firms for further analysis in forecasting stock returns. 

## GPT Usage

GPT model is accessed through the OpenAI Chat Completion API, utilizing the R programming language for integration and data processing.

In R openai package enables to set a connection to OpenAI (Chat GPT) API for Chat Completion tasks. To begin, an API key must be generated from the user's OpenAI account. Subsequently, the system role is established by specifying a prompt, which serves as a context message and provides instructions to the model, detailing the user's requirements. User message should contain a request or a question, which in this case is a company news headline.
