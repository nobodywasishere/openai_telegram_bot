require "tourmaline"
require "openai"
require "option_parser"
require "json"

puts "Starting openai_telegram_bot..."

config_file = "config.json"

OptionParser.parse do |parser|
  parser.on("-c config.json", "--config=config.json", "Specifies the config file") { |name| config_file = name }
end

keys = Hash(String, String).from_json(File.read(config_file))

class EchoBot < Tourmaline::Client
  setter allowed_users : Array(String) = [] of String
  setter openai : OpenAI::Client | Nil

  private def user_allowed?(user : User) : Bool
    unless @allowed_users.size == 0
      return @allowed_users.includes?(user.id.to_s)
    else
      return true
    end
  end

  private def get_ai_resp(message : String | Nil) : String
    resp = @openai.try &.completions(prompt: message).choices.first.text
    return resp unless resp.nil?
    return "OpenAI is not working."
  end

  @[On(:message)]
  def on_message(update)
    return unless message = update.message

    puts "#{message.message_id}: Message recieved: #{message.text}"

    from = message.from
    if from.nil?
      puts "#{message.message_id}: No user id"
      return
    elsif message.text.nil?
      puts "#{message.message_id}: Empty message"
      return
    elsif !user_allowed?(from)
      puts "#{message.message_id}: User not allowed: #{from.first_name} (#{from.id})"
      return
    end

    ai_response = get_ai_resp(message.text)
    puts "#{message.message_id}: Message reply: #{ai_response}"
    message.reply(ai_response, parse_mode: ParseMode::HTML)
  end
end

bot = EchoBot.new(bot_token: keys["TELEGRAM_BOT_KEY"])
bot.allowed_users = keys["ALLOWED_USERS"].split(",") if keys.keys.includes? "ALLOWED_USERS"
bot.openai = OpenAI::Client.new(api_key: keys["OPENAI_API_KEY"], default_engine: "gpt-3.5-turbo")
bot.poll
