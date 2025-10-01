# elastic-stack

**elastic-stack** is a dockerized enviroment to ingest logs in **elasticsearch** from different projects using **filebeat** via **logstash** and analyze them in **kibana**

## Setup 
```
mkdir -p config/{elasticsearch,kibana,logstash,filebeat}
mkdir -p data/{elasticsearch,kibana}
```
create logs folders for evert project, ie.
```
mkdir -p mkdir -p logs/project1
```

Copy ```.env.sample``` to ```.env``` and set values of keys, then set keys and for the 1st fime start ONLY elasticsearch container
```
docker compose up elasticsearch
```
then generate che token to allow access elasticsearch from kibana by calling 
```
docker exec elasticsearch /usr/share/elasticsearch/bin/elasticsearch-service-tokens create elastic/kibana kibana-token
```
and set the row in  ```.env``` like this
```
KIBANA_SERVICE_TOKEN=[generated token from the previous command]
```

## Run the stack
Spin the stack with docker
```
docker compose up
```
Setup as a system service
TBD

OPTIONALLY, but highly suggested  
Use nginx reserve proxy or a service like cloudflare to protect the traffic to your kibana exposed dashboard on port `9200` by default.

## Set cron tasks for log ingestion

Setup scripts that sync logs from remote in local folders by copying `sync.sample.sh` 
Add script to cron 
```
crontab -e
# every 15 minutes
*/15 * * * * cd /path/to/elastic-stack && ./sync-logs.sh
# every hour
0 * * * * cd /path/to/elastic-stack && ./sync-logs.sh
```

## Useful commands
docker
```
docker compose up -d
docker compose ps
docker compose logs -f
docker compose logs -f filebeat
docker-compose restart filebeat
docker exec -it filebeat bash
```
get info from elasticsearch via curl
```
curl http://localhost:9200/_cluster/health?pretty
curl http://localhost:9200/_cat/indices?v
curl http://localhost:9200/apache-project1-*/_count?pretty 
```
test log ingestion
```
echo '192.168.1.100 - - [29/Sep/2025:12:00:00 +0000] "GET /index.html HTTP/1.1" 200 1234 "-" "Mozilla/5.0"' > logs/project1/access_log
echo '[Sun Sep 29 12:00:00 2025] [error] [client 192.168.1.1] File does not exist: /var/www/html/test' > logs/project2/error_log
sleep 15
curl http://localhost:9200/apache-*/_search?pretty&size=3
```
