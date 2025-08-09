FROM docker.elastic.co/elasticsearch/elasticsearch:9.1.1

# Install S3 repository plugin for R2 compatibility
RUN bin/elasticsearch-plugin install --batch repository-s3

# Switch back to elasticsearch user
USER elasticsearch

# Expose standard ports
EXPOSE 9200 9300