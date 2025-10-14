import boto3

# Initialize the S3 client
s3_client = boto3.client('s3')

response = s3_client.list_buckets()
print("Existing buckets:")
for bucket in response['Buckets']:
    print(f"  {bucket['Name']}")