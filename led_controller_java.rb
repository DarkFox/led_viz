require 'rubygems'
require 'json'

require 'java'
require 'RXTXcomm.jar'
java_import('gnu.io.CommPortIdentifier')
java_import('gnu.io.SerialPort') { 'JSerialPort' }


class LedController
  # Maximum stable rate of commands seems to be around 55.6 Hz (Or 18 ms between each command) in direct serial mode.

  @port = nil
  attr_accessor :port, :read_timeout

  NONE = JSerialPort::PARITY_NONE

  def initialize(port_str)
    baud_rate = 9600
    data_bits = 8
    stop_bits = 1
    parity = NONE

    port_id = CommPortIdentifier.get_port_identifier port_str
    data    = JSerialPort.const_get "DATABITS_#{data_bits}"
    stop    = JSerialPort.const_get "STOPBITS_#{stop_bits}"

    @port = port_id.open 'JRuby', 500
    @port.set_serial_port_params baud_rate, data_bits, stop_bits, parity
    read_timeout = 1000

    @in  = @port.input_stream
    @out = @port.output_stream
  end

  def close
    @port.close
  end

  def putc(char)
    @out.write char[0, 1].to_java_bytes
  end

  def getc
    if @read_timeout
      deadline = Time.now + @read_timeout / 1000.0
      sleep 0.1 until @in.available > 0 || Time.now > deadline
    end

    @in.to_io.read(@in.available)[-1, 1] || ''
  end

  def current_state
    # Flush buffer first
    @in.to_io.read(@in.available)
    send_cmd "STATE"
    state = @in.to_io.read(@in.available)
    JSON.parse(state)
  end

  def set_mode(mode)
    send_cmd "MODE #{mode.to_i}"
  end

  def set_h(h)
    send_cmd "HUE #{h.to_i}"
  end

  def set_s(s)
    send_cmd "SAT #{s.to_i}"
  end

  def set_l(l)
    send_cmd "LUM #{l.to_i}"
  end

  def write_hsl
    send_cmd "WRITEHSL"
  end

  def set_hsl(h, s, l)
    send_cmd "SETHSL #{h.to_i} #{s.to_i} #{l.to_i}"
  end

  def set_interval(interval)
    send_cmd "INTERVAL #{interval.to_i}"
  end

  def set_red(pwr)
    send_cmd "RED #{pwr.to_i}"
  end

  def set_grn(pwr)
    send_cmd "GRN #{pwr.to_i}"
  end

  def set_blu(pwr)
    send_cmd "BLU #{pwr.to_i}"
  end

  def write_rgb
    send_cmd "WRITERGB"
  end

  def set_rgb(r, g, b)
    send_cmd "SETRGB #{r.to_i} #{g.to_i} #{b.to_i}"
  end

  def save
    send_cmd "SAVE"
  end

  private

  def send_cmd(command)
    bytes = (command+"\n").to_java_bytes
    @out.write bytes
  end
end