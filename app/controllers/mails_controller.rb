class MailsController < ApplicationController
  before_action :set_session

  def index
    @messages = mailbox.messages
  end

  def show
    @message = mailbox.find(params[:id]) or
      return redirect_to(session_mails_path(@session), alert: "That email is no longer here")
  end

  def forward
    to = params[:to].to_s.strip
    return back("Enter a valid email address") unless to.match?(URI::MailTo::EMAIL_REGEXP)
    return back("Sending to a real inbox isn't set up on this factory yet") unless Mailbox.smtp_configured?

    mailbox.forward(params[:id], to)
    redirect_to session_mail_path(@session, params[:id]), notice: "Sent a copy to #{to}."
  rescue StandardError => e
    back("Couldn't send it: #{e.message}")
  end

  private

  def set_session
    @session = Factory.safe_name(params[:session_id]) or redirect_to(sessions_path)
  end

  def mailbox = Mailbox.new(@app, @session)

  def back(alert) = redirect_to(session_mail_path(@session, params[:id]), alert:)
end
