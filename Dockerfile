# Start generating the build image
FROM crystallang/crystal:0.33.0

# Install the dependencies
ADD shard.yml .
ADD shard.lock .
RUN shards install

RUN apt-get update -y
RUN apt install libmagickwand-dev -y

# Add app and build it for production
ADD . .
RUN crystal build src/pixie_bot.cr

# Create a new image
FROM crystallang/crystal:0.33.0

# Copy over the executable
COPY --from=0 pixie_bot .

# Copy over shared object files
COPY --from=0 /usr/lib/x86_64-linux-gnu/* /usr/lib/x86_64-linux-gnu/

# Run it!
ENTRYPOINT ./pixie_bot
