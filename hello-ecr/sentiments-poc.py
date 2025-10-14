import boto3

# Create a Comprehend client
comprehend_client = boto3.client('comprehend', region_name='eu-west-1') # e.g., 'us-east-1'

text = "This product is absolutely amazing! I love it."

# Detect sentiment
response = comprehend_client.detect_sentiment(Text=text, LanguageCode='en')

# Extract and print the sentiment and scores
sentiment = response['Sentiment']
sentiment_scores = response['SentimentScore']

print(f"Sentiment: {sentiment}")
print(f"Sentiment Scores: {sentiment_scores}")
# Example output:
# Sentiment: POSITIVE
# Sentiment Scores: {'Positive': 0.99, 'Negative': 0.005, 'Neutral': 0.003, 'Mixed': 0.002}