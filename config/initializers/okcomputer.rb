require 'honeybadger'

class SmtpCheck < OkComputer::Check
  def check
    smtp = Net::SMTP.new ENV['ACTION_MAILER_SMTP_ADDRESS'], ENV['ACTION_MAILER_PORT']
    smtp.enable_starttls
    smtp.start('aws.emory.edu', ENV['ACTION_MAILER_USER_NAME'], ENV['ACTION_MAILER_PASSWORD'], :plain) do |s|
      mark_message "SMTP connection working"
    end
  rescue => exception
    Honeybadger.notify(exception)
    mark_failure
    mark_message "Cannot connect to SMTP"
  end
end

OkComputer::Registry.register "smtp", SmtpCheck.new