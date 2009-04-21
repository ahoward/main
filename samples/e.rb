require 'main'

Main {
  argument 'global-argument'
  option 'global-option'

  def run() puts 'global-run' end

  mode 'a' do
    option 'a-option'
  end

  mode 'b' do
    option 'b-option'

    def run() puts 'b-run' end
  end
}
