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

`/load`
Reply to a message with `/load` to load an image for processing. You can alternatively use `/load [url]` to load an image from a URL.

`/cancel`
Unload the currently loaded image.

`/info`
Return information about the loaded image.

`/resize [w] [h]? [aspect_ignore]?`
Resize the loaded image. If `aspect_ignore` is true, the image will be resized using exactly the supplied dimensions. Defaults to false.

`/finish [ext]`
Get the completed image in the given format. For example `/finish png` to get a PNG.
MARKDOWN

IMAGES = {} of Int64 => Pixie::ImageSet

class PixieBot < Tourmaline::Client
  @[Command("start")]
  def start_command(ctx)
    ctx.reply(START_TEXT, parse_mode: :markdown)
  end

  @[Command("help")]
  def help_command(ctx)
    ctx.reply(HELP_TEXT, parse_mode: :markdown)
  end

  @[Command("load")]
  def load_command(ctx)
    return ctx.respond("You already have an image loaded. Please /cancel " +
                       "that one before loading a new one.",
                       parse_mode: :markdown) if IMAGES.has_key?(ctx.message.from.not_nil!.id)
    buffer = message_photo_to_buffer(ctx)
    return ctx.respond("Please reply to a message with the image you want to load.") unless buffer
    set = Pixie::ImageSet.new(buffer)
    IMAGES[ctx.message.from.not_nil!.id] = set
    ctx.respond("Image loaded successfully. Use /finish to download your completed image when you're done.")
  rescue e
    ctx.respond(e.message)
  end

  @[Command("cancel")]
  def cancel_command(ctx)
    return unless assert_loaded(ctx)
    IMAGES.delete(ctx.message.from.not_nil!.id)
    ctx.respond("Operation canceled.")
  end

  @[Command("info")]
  def info_command(ctx)
    return unless assert_loaded(ctx)
    set = IMAGES[ctx.message.from.not_nil!.id]
    info = String.build do |str|
      str.puts "```"
      str.puts "- Signature: " + set.image_signature
      str.puts "- Format: " + set.image_format
      str.puts "- Width: " + set.image_width.to_s
      str.puts "- Height: " + set.image_height.to_s
      str.puts "- Colors: " + set.image_colors.to_s
      str.puts "- Compression Quality: " + set.image_compression_quality.to_s
      str.puts "- Delay: " + set.image_delay.to_s
      str.puts "- Depth: " + set.image_depth.to_s
      str.puts "- Iterations: " + set.image_iterations.to_s
      str.puts "- Scene: " + set.image_scene.to_s
      str.puts "- Ticks Per Second: " + set.image_ticks_per_second.to_s
      str.puts "- Image Count: " + set.n_images.to_s
      str.puts "- Compression: " + set.image_compression.to_s
      str.puts "- Type: " + set.image_type.to_s
      str.puts "```"
    end
    ctx.respond(info, parse_mode: :markdown)
  end

  @[Command("resize")]
  def resize_command(ctx)
    return unless assert_loaded(ctx)
    params = ctx.text.strip.split(/\s+/)

    if params.empty?
      return ctx.respond("I at least need a width to resize to.")
    end

    width = params[0]
    height = params[1]? || width
    keep_aspect = params[2]? || "false"

    begin
      width = width.to_u32
      height = height.to_u32
    rescue
      return ctx.respond("Width and height parameters must be positive integers.")
    end

    if aspect = keep_aspect
      if aspect.downcase.match(/t(rue)?|y(es)?/)
        keep_aspect = true
      elsif aspect.downcase.match(/f(alse)?|no?/)
        keep_aspect = false
      else
        ctx.respond("Unrecognized value for `aspect_ignore` parameter. Defaulting to false.")
        keep_aspect = false
      end
    end

    set = IMAGES[ctx.message.from.not_nil!.id]

    if keep_aspect
      set.scale_image(width, height)
    else
      set.resize_image(width, height, :cubic)
    end

    ctx.reply("Resized to #{set.image_width} x #{set.image_height}")
  end

  @[Command("finish")]
  def finish_command(ctx)
    return unless assert_loaded(ctx)
    format = ctx.text.strip.split(/\s+/, 2).first.downcase
    if format.empty?
      return ctx.respond("Please use the format `/finish ext` where `ext` is the format you want to save the image as.")
    end

    set = IMAGES[ctx.message.from.not_nil!.id]
    set.image_format = format.upcase
    blob = set.image_blob

    file = ::File.tempfile(nil, ".#{format}")
    file.write(blob)
    file.rewind

    ctx.chat.send_chat_action(:upload_document)
    ctx.respond_with_document(file)
    file.delete
    IMAGES.delete(ctx.message.from.not_nil!.id)
  end

  def assert_loaded(ctx)
    unless IMAGES.has_key?(ctx.message.from.not_nil!.id)
      ctx.respond("No image loaded. Please reply to an image with /load to get started.")
      return false
    end
    true
  end

  private def message_photo_to_buffer(ctx)
    if message = ctx.message.reply_message
      if message.photo.size > 0
        photo = message.photo.max_by(&.file_size)
      elsif document = message.document
        photo = document
      elsif sticker = message.sticker
        photo = sticker
      else
        raise "Please respond to a message with a photo."
      end

      if file = ctx.get_file(photo.file_id)
        if (file_path = file.file_path) && file_path.ends_with?(".tgs")
          raise "Animated stickers are not supported at this time."
        end
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
        raise "Failed to download file from Telegram"
      end
      buffer = response.body.to_slice
      return buffer if buffer.size > 0
    end

    raise "Something went wrong. This is a bug. Please report it to @watzon."
  end
end

bot = PixieBot.new(ENV["API_KEY"])
bot.poll
