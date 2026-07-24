# A software microphone for the box. On a headless server claude's built-in
# /voice has no mic to open — so we present a PulseAudio "pipe source" (a FIFO
# that looks like a mic) and stream the browser's audio into it (see
# MicChannel + bin/mic-proof). claude's /voice then records from it and
# transcribes with Anthropic's model, exactly as if it were local hardware.
#
# ponytail: one shared virtual mic set as the default source — fine for a
# single user recording one session at a time. Per-session routing (a source
# each + PULSE_SOURCE) is the upgrade path if two people ever dictate at once.
module Mic
  FIFO = "/tmp/asm-mic".freeze
  SOURCE = "asmvirtmic".freeze

  module_function

  # Is a PulseAudio (or PipeWire-pulse) daemon reachable for this user?
  def available? = system("pactl", "info", out: File::NULL, err: File::NULL)
  def start! = system("pulseaudio", "--start", "--exit-idle-time=-1", out: File::NULL, err: File::NULL)

  # Idempotently create the virtual mic and make it the default input.
  # Returns false when there's no audio server (e.g. local dev on a Mac).
  def ensure!
    start! unless available?
    return false unless available?
    unless `pactl list short sources 2>/dev/null`.include?(SOURCE)
      system("pactl", "load-module", "module-pipe-source", "source_name=#{SOURCE}",
             "file=#{FIFO}", "format=s16le", "rate=16000", "channels=1",
             out: File::NULL, err: File::NULL)
    end
    system("pactl", "set-default-source", SOURCE, out: File::NULL, err: File::NULL)
    File.exist?(FIFO)
  end
end
