require "tourmaline"
require "pixie"

require "http/client"

START_TEXT = <<-MARKDOWN
Welcome to Pixie. I'm a completely free, open source photo editing bot built \
with Crystal by @watzon. Feel free to check out my source code \
[on GitHub](https://github.com/watzon/pixiebot).

To see what I can do, use the /help command.
MARKDOWN

HELP_TEXT = <<-MARKDOWN
*Commands:*
    `/convert format [url]`:
        Converts the replied to image/sticker to the given format. For a list of supported formats,\
        see [the ImageMagick documentation](https://imagemagick.org/script/formats.php). Some \
        formats may not work as they require additional arguments.
MARKDOWN

class PixieBot < Tourmaline::Client
  @[Command("start")]
  def start_command(ctx)
    ctx.reply(START_TEXT, parse_mode: :markdown)
  end

  @[Command("help")]
  def help_command(ctx)
    ctx.reply(HELP_TEXT, parse_mode: :markdown)
  end

  @[Command("convert")]
  def convert_command(ctx)
    format = ctx.text.strip.split(/\s+/, 2).first.downcase

    # TODO: Check format against list from ImageMagick
    # unless FORMATS.includes?(format)
    #   return ctx.reply("Invalid format! Format must be one of:\n" + FORMATS.join("\n"))
    # end

    if buffer = message_photo_to_buffer(ctx)
      set = Pixie::ImageSet.new(buffer)
      set.image_format = format.upcase
      blob = set.image_blob

      file = ::File.tempfile(nil, ".#{format}")
      file.write(blob)
      file.rewind

      ctx.chat.send_chat_action(:upload_document)
      ctx.reply_with_document(file)
      file.delete
    else
      ctx.reply("Couldn't find a photo to fetch.")
    end
  end

  def message_photo_to_buffer(ctx)
    if message = ctx.message.reply_message
      if message.photo.size > 0
        photo = message.photo.max_by(&.file_size)
      elsif document = message.document
        photo = document
      elsif sticker = message.sticker
        photo = sticker
      else
        return
      end

      if file = ctx.get_file(photo.file_id)
        file_link = ctx.get_file_link(file).not_nil!
        response = HTTP::Client.get(file_link)
        return response.body.to_slice
      end
    end

    parts = ctx.text.to_s.split(/\s+/, 2)
    puts parts
    if (url = parts[1]?) && (url.match(/^(ftp|https?):\/\//))
      puts url
      response = HTTP::Client.get(url)
      if response.status_code > 299
        puts "Status code: #{response.status_code}"
        return
      end
      buffer = response.body.to_slice
      return buffer if buffer.size > 0
    end
  end
end

bot = PixieBot.new(ENV["API_KEY"])
bot.poll
