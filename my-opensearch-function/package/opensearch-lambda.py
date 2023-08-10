import boto3
import json
import requests
from requests_aws4auth import AWS4Auth

region = "us-east-1"
service = "es"
credentials = boto3.Session().get_credentials()
awsauth = AWS4Auth(
    credentials.access_key,
    credentials.secret_key,
    region,
    service,
    session_token=credentials.token,
)

host = "your-opensearch-domain-endpoint"
index = "movies"
uri = f"{host}/{index}/_search"


def lambda_handler(event, context):
    query = {
        "size": 25,
        "query": {
            "multi_match": {
                "query": event["queryStringParameters"]["q"],
                "fields": ["title^4", "plot^2", "actors", "directors"],
            }
        },
    }

    headers = {"Content-Type": "application/json"}

    r = requests.get(uri, auth=awsauth, headers=headers, data=json.dumps(query))

    response = {
        "statusCode": 200,
        "headers": {
            "Access-Control-Allow-Origin": "*",
            "Content-Type": "application/json",
        },
        "isBase64Encoded": False,
    }

    response["body"] = r.text
    return response
