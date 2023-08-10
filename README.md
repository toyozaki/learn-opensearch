# learn-opensearch

## Usage

```shell
// main.tfの<your ip>を変更する。
$ terraform apply

// opensearch-lambda.pyのhostを更新する。
$ terraform apply

$ curl -O https://docs.aws.amazon.com/ja_jp/opensearch-service/latest/developerguide/samples/sample-movies.zip
$ unzip sample-movies.zip
// sample-movies.bulkの最終行を改行する
$ curl -XPOST "<your opensearch endpoint>" --data-binary @sample-movies.bulk -H 'Content-Type: application/x-ndjson'

$ curl -O https://docs.aws.amazon.com/ja_jp/opensearch-service/latest/developerguide/samples/sample-site.zip
$ unzip sample-site.zip
// sample-site.zipのscripts/search.jsのapigatewayendpointを更新する。
// index.htmlを開き、挙動を確認する。

$ terraform destroy
```

## References

- https://docs.aws.amazon.com/ja_jp/opensearch-service/latest/developerguide/search-example.html
