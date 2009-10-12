require 'main'

ARGV.replace %w( x y argument )

Main {
  argument 'argument'
  option 'option'

  def run() puts 'run' end

  mode 'a' do
    option 'a-option'
    def run() puts 'a-run' end
  end

  mode 'x' do
    option 'x-option'

    def run() puts 'x-run' end

      mode 'y' do
        option 'y-option'

        def run() puts 'y-run' end
      end
  end
}
