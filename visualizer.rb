require 'led_controller_java.rb'
CONTROLLER = LedController.new("/dev/tty.usbmodemfd121")
sleep 2
CONTROLLER.set_mode(99)

# Visualizer
class Visualizer < Processing::App
   # Load minim and import the packages we'll be using
  load_library "minim"
  import "ddf.minim"
  import "ddf.minim.analysis"

  def setup
    smooth  # smoother == prettier
    size(100,100)  # let's pick a more interesting size
    background 10  # ...and a darker background color

    setup_sound
  end

  def draw
    update_sound
    #animate_sound
    animate_leds
  end

  def setup_sound
    # Creates a Minim object
    @minim = Minim.new(self)
    # Lets Minim grab sound data from mic/soundflower

    @input = @minim.get_line_in

    # Gets FFT values from sound data
    @fft = FFT.new(@input.left.size, 44100)
    # Our beat detector object

    @beat = BeatDetect.new

    # Set an array of frequencies we'd like to get FFT data for
    #   -- I grabbed these numbers from VLC's equalizer
    @freqs = [60, 170, 310, 600, 1000, 3000, 6000, 12000, 14000, 16000]

    # Create arrays to store the current FFT values,

    #   previous FFT values, highest FFT values we've seen,
    #   and scaled/normalized FFT values (which are easier to work with)
    @current_ffts   = Array.new(@freqs.size, 0.001)
    @previous_ffts  = Array.new(@freqs.size, 0.001)
    @max_ffts       = Array.new(@freqs.size, 0.001)
    @scaled_ffts    = Array.new(@freqs.size, 0.001)

    # We'll use this value to adjust the "smoothness" factor

    #   of our sound responsiveness
    @fft_smoothing = 0.8
  end

  def update_sound
    @fft.forward(@input.left)

    @previous_ffts = @current_ffts

    # Iterate over the frequencies of interest and get FFT values
    @freqs.each_with_index do |freq, i|
      # The FFT value for this frequency
      new_fft = @fft.get_freq(freq)

      # Set it as the frequncy max if it's larger than the previous max

      @max_ffts[i] = new_fft if new_fft > @max_ffts[i]

      # Use our "smoothness" factor and the previous FFT to set a current FFT value
      @current_ffts[i] = ((1 - @fft_smoothing) * new_fft) + (@fft_smoothing * @previous_ffts[i])

      # Set a scaled/normalized FFT value that will be

      #   easier to work with for this frequency
      @scaled_ffts[i] = (@current_ffts[i]/@max_ffts[i])
    end

    # Check if there's a beat, will be stored in @beat.is_onset
    @beat.detect(@input.left)
  end

  def animate_sound
    # Create a circle animated with sound:
    # Horizontal position will be controlled by the FFT of 60hz (normalized against width)

    # Vertical position - 170hz (normalized against height)
    # red, green, blue - 310hz, 600hz, 1khz (normalized against 255)
    # Size - 170hz (normalized against height), quadrupled on beat

    @size = @scaled_ffts[1]*height
    @size *= 4 if @beat.is_onset

    @x1  = @scaled_ffts[0]*width + width/2

    @y1  = @scaled_ffts[1]*height + height/2
    @red1    = @scaled_ffts[2]*255

    @green1  = @scaled_ffts[3]*255
    @blue1   = @scaled_ffts[4]*255

    fill @red1, @green1, @blue1
    stroke @red1+20, @green1+20, @blue1+20

    ellipse(@x1, @y1, @size, @size)

    # Add another circle using different controlling frequencies

    @x2  = width/2 - @scaled_ffts[5]*width
    @y2  = height/2 - @scaled_ffts[6]*height

    @red2    = @scaled_ffts[7]*255
    @green2  = @scaled_ffts[8]*255

    @blue2   = @scaled_ffts[9]*255

    fill @red2, @green2, @blue2

    stroke @red2+20, @green2+20, @blue2+20
    ellipse(@x2, @y2, @size, @size)
  end

  def animate_leds
    @red_led    = @scaled_ffts[2]*255
    @green_led  = @scaled_ffts[3]*255
    @blue_led   = @scaled_ffts[4]*255

    cut_red = @green_led/2
    cut_green = @blue_led/2
    cut_blue = @green_led/2

    @red_led   -= cut_red
    @green_led -= cut_green
    @blue_led  -= cut_blue

    #@red_led    *= (@beat.is_onset ? 1 : 0.8)
    #@green_led  *= (@beat.is_onset ? 1 : 0.8)
    #@blue_led   *= (@beat.is_onset ? 1 : 0.8)

    @red_led    = 0 if @red_led < 0
    @green_led  = 0 if @green_led < 0
    @blue_led   = 0 if @blue_led < 0

    @red_led    = 255 if @red_led > 255
    @green_led  = 255 if @green_led > 255
    @blue_led   = 255 if @blue_led > 255


    CONTROLLER.set_rgb(@red_led, @green_led, @blue_led)
  end

end

Visualizer.new :title => "Visualizer"