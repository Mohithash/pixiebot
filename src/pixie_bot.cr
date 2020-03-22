require "tourmaline"
require "pixie"

require "http/client"

# Acceptable formats for conversion
FORMATS = [
  "jpg",
  "jpeg",
  "png",
  "webp"
]

class PixieBot < Tourmaline::Client
  @[Command("start")]
  def start_command(ctx)
    ctx.reply("Welcome to Pixie")
  end

  @[Command("help")]
  def help_command(ctx)
    ctx.reply("This is a help message")
  end

  @[Command("convert")]
  def convert_command(ctx)
    if message = ctx.message.reply_message
      format = ctx.text.strip.downcase
      unless FORMATS.includes?(format)
        return ctx.reply("Invalid format! Format must be one of:\n" + FORMATS.join("\n"))
      end

      photos = message.photo
      unless photos.size > 0
        return ctx.reply("Please send a photo to convert along with the convert command.")
      end

      photo = photos.max_by(&.file_size)
      if file = ctx.get_file(photo.file_id)
        file_link = ctx.get_file_link(file).not_nil!
        response = HTTP::Client.get(file_link)
        buffer = response.body.to_slice

        set = Pixie::ImageSet.new(buffer)
        set.image_format = format.upcase
        blob = set.image_blob

        file = ::File.tempfile(nil, ".#{format}")
        file.write(blob)
        file.rewind

        ctx.reply_with_document(file)
        file.delete
      else
        return ctx.reply("Failed to get file for some reason :(")
      end
    else
      ctx.reply("Please reply to the image you want to convert.")
    end
  end
end

bot = PixieBot.new(ENV["API_KEY"])
bot.poll
