require "tourmaline"
require "openai"
require "json"

puts "Starting openai_telegram_bot..."

keys = Hash(String, String).from_json(File.read("config.json"))

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
    resp = @openai.try &.completions(prompt: message, max_tokens: 100).choices.first.text
    return resp unless resp.nil?
    return "OpenAI is not working."
  end

  @[On(:message)]
  def on_message(update)
    return unless message = update.message

    puts "Message recieved: #{message.text}"

    from = message.from
    if from.nil?
      puts "No user id"
      return
    elsif message.text.nil?
      puts "Empty message"
      return
    elsif !user_allowed?(from)
      puts "User not allowed: #{from.first_name} (#{from.id})"
      return
    end

    message.reply(get_ai_resp(message.text))
  end
end

bot = EchoBot.new(bot_token: keys["TELEGRAM_BOT_KEY"])
bot.allowed_users = keys["ALLOWED_USERS"].split(",") if keys.keys.includes? "ALLOWED_USERS"
bot.openai = OpenAI::Client.new(api_key: keys["OPENAI_API_KEY"], default_engine: "ada")
bot.poll
