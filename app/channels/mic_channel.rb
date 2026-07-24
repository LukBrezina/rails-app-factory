require "base64"

# Receives the browser microphone as 16 kHz mono s16le PCM (base64 frames) and
# writes it into the box's virtual mic FIFO, so claude's /voice hears it. The
# signed token is the capability, same as TerminalChannel — but here it only
# gates access to the shared mic, not a specific tmux session.
class MicChannel < ApplicationCable::Channel
  def subscribed
    Factory.verifier.verify(params[:token].to_s) # authorize; value unused (shared mic)
    reject and return unless Mic.ensure!

    # O_NONBLOCK: opening a FIFO for write blocks until a reader (the pulse
    # pipe-source) is attached — nonblock turns "no reader yet" into a quick
    # ENXIO we can retry rather than a hung thread.
    3.times do
      @io = File.open(Mic::FIFO, File::WRONLY | File::NONBLOCK)
      break
    rescue Errno::ENXIO, Errno::ENOENT
      sleep 0.05
    end
    reject unless @io
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    reject
  end

  def chunk(data)
    @io&.write_nonblock(Base64.decode64(data["data"].to_s))
  rescue IO::WaitWritable, Errno::EAGAIN
    # writing faster than real time — drop the frame rather than back up latency
  rescue IOError, Errno::EPIPE
    @io = nil
  end

  def unsubscribed
    @io&.close
  rescue IOError
  ensure
    @io = nil
  end
end
