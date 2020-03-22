# Start generating the build image
FROM crystallang/crystal:0.33.0

# We need wget to download the installer script
RUN apt update && apt install -y wget

# Install ImageMagick7
RUN wget https://gist.github.com/watzon/03e6148e70edc541cf6e7f15f1fcf00d/raw/0664814d3722891b16b0e3c63caac69cc2274f79/imgmagick7-install.sh
RUN chmod u+x ./imgmagick7-install.sh
RUN /bin/bash ./imgmagick7-install.sh

# Install the dependencies
ADD shard.yml .
ADD shard.lock .
RUN shards install

# Add app and build it for production
ADD . .
RUN crystal build src/pixie_bot.cr --release

# Run it!
ENTRYPOINT ./pixie_bot
