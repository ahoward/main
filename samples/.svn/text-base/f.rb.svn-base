require 'main'

Main {
  argument('directory'){ description 'the directory to operate on' }

  option('force'){ description 'use a bigger hammer' }

  def run
    puts 'this is how we run when no mode is specified'
  end

  mode 'compress' do
    option('bzip'){ description 'use bzip compression' }

    def run
      puts 'this is how we run in compress mode' 
    end
  end

  mode 'uncompress' do
    option('delete-after'){ description 'delete orginal file after uncompressing' }

    def run
      puts 'this is how we run in un-compress mode' 
    end
  end
}
