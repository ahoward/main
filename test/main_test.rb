$:.unshift('.')
$:.unshift('./lib')
$:.unshift('..')
$:.unshift('../lib')

require('stringio')
require('test/unit')
require('main')
require('main/test')


class T < Test::Unit::TestCase
  fattr 'status'
  fattr 'logger'
  fattr 'error'

  def setup
    @status = nil 
    @logger = Logger.new StringIO.new
    @error = nil
  end

  def teardown
  end

  def main(argv=[], env={}, &block)
    options = {}
    options[:argv] = argv
    options[:env] = env
    options[:logger] = logger

    main = Main.test(options, &block)

    test = self
    begin
      main.run()
    ensure
      test.status = main.status
    end
    main
  end

 
# basic test
#
  def test_0000
    assert_nothing_raised{
      main{
        def run() end
      }
    }
  end
  def test_0010
    x = nil
    assert_nothing_raised{
      main{
        define_method(:run){ x = 42 }
      }
    }
    assert_equal 42, x 
  end
 
# exit status
#
  def test_0020
    assert_nothing_raised{
      main{
        def run() end
      }
    }
    assert_equal 0, status
  end
  def test_0030
    assert_nothing_raised{
      main{
        def run() exit 42 end
      }
    }
    assert_equal 42, status
  end
  def test_0040
    assert_nothing_raised{
      fork{
        main{
          def run() exit! 42 end
        }
      }
      Process.wait
      assert_equal 42, $?.exitstatus
    }
  end
  def test_0050
    assert_nothing_raised{
      main{
        def run() exit 42 end
      }
    }
    assert_equal 42, status
  end
  def test_0060
    assert_raises(RuntimeError){
      main{
        def run() exit_status 42; raise end
      }
    }
    assert_equal 42, status
  end
  def test_0070
    assert_raises(ArgumentError){
      main{
        def run() exit_status 42; raise ArgumentError end
      }
    }
    assert_equal 42, status
  end
 
# parameter parsing 
#
  def test_0080
    p = nil
    assert_raises(Main::Parameter::NotGiven){
      main(){
        argument 'foo'
        define_method('run'){ }
      }
    }
  end
  def test_0090
    p = nil
    m = nil
    argv = %w[ 42 ]
    given = nil
    assert_nothing_raised{
      main(argv.dup){
        argument 'foo'
        define_method('run'){ m = self; p = param['foo'] }
      }
    }
    assert p.value == argv.first 
    assert p.values == argv
    assert p.given?
    assert m.argv.empty? 
  end
  def test_0100
    p = nil
    argv = %w[]
    given = nil
    assert_nothing_raised{
      main(argv){
        p = argument('foo'){ optional }
        define_method('run'){ p = param['foo'] }
      }
    }
    assert p.optional?
    assert !p.required?
    assert p.value == nil 
    assert p.values == [] 
    assert !p.given?
  end
  def test_0101
    p = nil
    argv = %w[]
    given = nil
    assert_nothing_raised{
      main(argv){
        p = argument('foo'){ required false }
        define_method('run'){ p = param['foo'] }
      }
    }
    assert p.optional?
    assert !p.required?
    assert p.value == nil 
    assert p.values == [] 
    assert !p.given?
  end
  def test_0110
    p = nil
    argv = %w[ --foo ]
    assert_nothing_raised{
      main(argv){
        option('foo'){ required }
        define_method('run'){ p = param['foo'] }
      }
    }
    assert p.value == true 
    assert p.values ==[true] 
    assert p.given?
  end
  def test_0120
    p = nil
    argv = [] 
    assert_nothing_raised{
      main(argv){
        option 'foo'
        define_method('run'){ p = param['foo'] }
      }
    }
    assert p.value == nil 
    assert p.values == [] 
    assert !p.given?
  end
  def test_0130
    p = nil 
    assert_nothing_raised{
      main(%w[--foo=42]){
        option('foo'){ required; argument_required }
        define_method('run'){ p = param['foo']}
      }
    }
    assert p.required?
    assert p.argument_required?
    assert !p.optional?
  end
  def test_0131
    assert_raises(Main::Parameter::NotGiven){
      main(){
        option('foo'){ required; argument_required }
        define_method('run'){}
      }
    }
  end
  def test_0140
    assert_raises(Main::Parameter::MissingArgument){
      main(['--foo']){
        option('foo'){ required; argument_required }
        define_method('run'){}
      }
    }
  end
  def test_0150
    param = nil
    assert_nothing_raised{
      main(%w[--foo=42 --bar=42.0 --foobar=true --barfoo=false --uri=http://foo --x=s --y=a,b,c]){
        option('foo'){ 
          required
          argument_required
          cast :int
        }
        option('bar'){ 
          argument_required
          cast :float
        }
        option('foobar'){ 
          argument_required
          cast :bool
        }
        option('barfoo'){ 
          argument_required
          cast :string
        }
        option('uri'){ 
          argument_required
          cast :uri
        }
        option('x'){ 
          argument_required
          cast{|x| x.to_s.upcase}
        }
        option('y'){ 
          argument_required
          cast{|*values| values.join.split(',').map{|value| value.upcase}}
        }
        define_method('run'){ param = params }
      }
    }
    assert param['foo'].value == 42
    assert param['bar'].value == 42.0
    assert param['foobar'].value == true
    assert param['barfoo'].value == 'false'
    assert param['uri'].value == URI.parse('http://foo')
    assert param['x'].value == 'S'
    assert param['y'].value == 'A'
    assert param['y'].values == %w( A B C )
  end
  def test_0160
    p = nil 
    assert_nothing_raised{
      main(%w[--foo=42]){
        option('foo'){ 
          required
          argument_required
          cast :int
          validate{|x| x == 42}
        }
        define_method('run'){ p = param['foo']}
      }
    }
    assert p.value == 42
    assert p.required?
    assert p.argument_required?
    assert !p.optional?
  end
  def test_0170
    assert_raises(Main::Parameter::InValid){
      main(%w[--foo=40]){
        option('foo'){ 
          required
          argument_required
          cast :int
          validate{|x| x == 42}
        }
        define_method('run'){ }
      }
    }
  end
  def test_0180
    assert_nothing_raised{
      main(%w[--foo=42]){
        option('--foo=foo'){ 
          required
          # argument_required
          cast :int
          validate{|x| x == 42}
        }
        define_method('run'){ }
      }
    }
  end
  def test_0190
    assert_raises(Main::Parameter::MissingArgument){
      main(%w[--foo]){
        option('--foo=foo'){ }
        define_method('run'){ }
      }
    }
  end
  def test_0200
    p = nil
    assert_nothing_raised{
      main(%w[--foo]){
        option('--foo=[foo]'){ }
        define_method('run'){ p = param['foo'] }
      }
    }
    assert p.value == true
  end
  def test_0210
    p = nil
    assert_nothing_raised{
      main(%w[--foo=42]){
        option('--foo=[foo]'){
          cast :int
          validate{|x| x == 42}
        }
        define_method('run'){ p = param['foo'] }
      }
    }
    assert p.value == 42 
  end
  def test_0220
    p = nil
    assert_nothing_raised{
      main(%w[--foo=40 --foo=2]){
        option('--foo=foo'){
          arity 2
          cast :int
          validate{|x| x == 40 or x == 2}
        }
        define_method('run'){ p = param['foo'] }
      }
    }
    assert p.value == 40
    assert p.values == [40,2]
  end
  def test_0230
    p = nil
    assert_nothing_raised{
      main(%w[foo=42]){
        keyword('foo'){
          cast :int
          validate{|x| x == 42}
        }
        define_method('run'){ p = param['foo'] }
      }
    }
    assert p.value == 42
  end
  def test_0240
    foo = nil
    bar = nil
    assert_nothing_raised{
      main(%w[foo= bar]){
        keyword 'foo'
        keyword 'bar'
        define_method('run'){ 
          foo = param['foo'] 
          bar = param['bar'] 
        }
      }
    }
    assert foo.value == ''
    assert bar.value == nil 
  end
  def test_0250
    foo = nil
    bar = nil
    assert_nothing_raised{
      main(%w[foo=40 bar=2]){
        keyword('foo'){
          cast :int
        }
        keyword('bar'){
          cast :int
        }
        define_method('run'){ 
          foo = param['foo'] 
          bar = param['bar'] 
        }
      }
    }
    assert foo.value == 40 
    assert bar.value == 2 
  end
  def test_0260
    foo = nil
    bar = nil
    foobar = nil
    assert_nothing_raised{
      main(%w[foo=40 --bar=2 foobar foo=42]){
        keyword('foo'){ cast :int; arity 2 }
        option('bar='){ cast :int }
        argument 'foobar'

        define_method('run'){ 
          foo = param['foo'] 
          bar = param['bar'] 
          foobar = param['foobar'] 
        }
      }
    }
    assert foo.value == 40 
    assert foo.values == [40, 42]
    assert bar.value == 2 
    assert foobar.value == 'foobar' 
  end

  def test_0270
    foo = nil
    assert_nothing_raised{
      main([], 'foo' => '42'){
        environment('foo'){ cast :int }
        define_method('run'){ 
          foo = param['foo'] 
        }
      }
    }
    assert foo.value == 42 
  end

# parameter declaration 
#
  def test_0271
    assert_nothing_raised{
      main([]){
        option('--a-sorts-first', '-b')
        run{}
      }
    }
  end

# manual parmeter setting
#
  def test_0272
    assert_nothing_raised{
      h = {}

      main(){
        argument(:foo){ optional }
        run do
          o = param['foo']
          h[nil] = o.value

          o.set 'bar'
          h['bar'] = o.value

          o.set ['bar']
          h[['bar']] = o.value

          o.set 'foo', 'bar' 
          h['foo'] = o.value
          h[['foo', 'bar']] = o.values
        end
      }

      h.each do |expected, actual|
        assert_equal expected, actual
      end
    }
  end
 
# usage
#
  def test_0280
    assert_nothing_raised{
      u = Main::Usage.new
    }
  end
  def test_0290
    assert_nothing_raised{
      u = Main::Usage.default(Main.factory)
    }
  end
  def test_0300
    assert_nothing_raised{
      chunk = <<-txt
        a
        b
        c
      txt
      assert Main::Util.unindent(chunk) == "a\nb\nc"
      chunk = <<-txt
        a
          b
           c
      txt
      assert Main::Util.unindent(chunk) == "a\n  b\n   c"
    }
  end
  def test_0310
    assert_nothing_raised{
      u = Main::Usage.new
      u[:name] = 'foobar'
      assert u[:name] = 'foobar'
      assert u['name'] = 'foobar'
    }
  end
  def test_0320
    assert_nothing_raised{
      u = Main::Usage.new
      u[:name] = 'foobar'
        assert u[:name] == 'foobar'
        assert u['name'] == 'foobar'
      u[:name2] = 'barfoo'
        assert u[:name] == 'foobar'
        assert u['name'] == 'foobar'
        assert u[:name2] == 'barfoo'
        assert u['name2'] == 'barfoo'
      u.delete_at :name
        assert u[:name] == nil
        assert u['name'] == nil
        assert u[:name2] == 'barfoo'
        assert u['name2'] == 'barfoo'
      u.delete_at :name2
        assert u[:name] == nil
        assert u['name'] == nil
        assert u[:name2] == nil
        assert u['name2'] == nil
    }
  end
 
# io redirection
#
  class ::Object
    require 'tempfile'
    def infile buf
      t = Tempfile.new rand.to_s
      t << buf
      t.close
      open t.path, 'r+'
    end
    def outfile
      t = Tempfile.new rand.to_s
      t.close
      open t.path, 'w+'
    end
  end
  def test_0330
    s = "foo\nbar\n"
    sio = StringIO.new s 
    $buf = nil
    assert_nothing_raised{
      main{
        stdin sio
        def run
          $buf = STDIN.read
        end
      }
    }
    assert $buf == s
  end
  def test_0340
    s = "foo\nbar\n"
    $sio = StringIO.new s 
    $buf = nil
    assert_nothing_raised{
      main{
        def run
          self.stdin = $sio
          $buf = STDIN.read
        end
      }
    }
    assert $buf == s
  end
  def test_0350
    s = "foo\nbar\n"
    $buf = nil
    assert_nothing_raised{
      main{
        stdin infile(s) 
        def run
          $buf = STDIN.read
        end
      }
    }
    assert $buf == s
  end
  def test_0360
    sout = outfile
    assert_nothing_raised{
      main{
        stdout sout 
        def run
          puts 42
        end
      }
    }
    assert test(?e, sout.path), 'sout exists'
    assert IO.read(sout.path) == "42\n", 'sout has correct output'
  end
  def test_0370
    m = nil
    assert_nothing_raised{
      m = main{
        stdout StringIO.new 
        def run
          puts 42
        end
      }
    }
    assert m
    assert_nothing_raised{ m.stdout.rewind }
    assert m.stdout.read == "42\n" 
  end
 
# main ctor
#
  def test_0380
    argv = %w( a b c )
    $argv = nil
    assert_nothing_raised{
      main(argv){
        def run
          $argv = @argv
        end
      }
    }
    assert argv == $argv 
  end
  def test_0390
    argv = %w( a b c )
    env = {'key' => 'val', 'foo' => 'bar'}
    $argv = nil
    $env = nil
    assert_nothing_raised{
      main(argv, env){
        def run
          $argv = @argv
          $env = @env
        end
      }
    }
    assert argv == $argv 
  end

 
# negative/globbing arity
#
  def test_0400
    m = nil
    argv = %w( a b c )
    assert_nothing_raised{
      main(argv.dup) {
        argument('zero_or_more'){ arity(-1) }
        run{ m = self }
      }
    }
    assert m.param['zero_or_more'].values == argv
  end 
  def test_0401
    m = nil
    argv = %w( a b c )
    assert_nothing_raised{
      main(argv.dup) {
        argument('zero_or_more'){ arity(-1) }
        run{ m = self }
      }
    }
    assert m.param['zero_or_more'].values == argv
  end 
  def test_0410
    m = nil
    argv = %w( a b c )
    assert_nothing_raised{
      main(argv.dup) {
        argument('zero_or_more'){ arity('*') }
        run{ m = self }
      }
    }
    assert m.param['zero_or_more'].values == argv
  end 
  def test_0420
    m = nil
    argv = %w( a b c )
    assert_nothing_raised{
      main(argv.dup) {
        argument('one_or_more'){ arity(-2) }
        run{ m = self }
      }
    }
    assert m.param['one_or_more'].values == argv
  end 
  def test_0430
    m = nil
    argv = %w( a b c )
    assert_nothing_raised{
      main(argv.dup) {
        argument('two_or_more'){ arity(-3) }
        run{ m = self }
      }
    }
    assert m.param['two_or_more'].values == argv
  end 
  def test_0440
    m = nil
    argv = %w()
    assert_nothing_raised{
      main(argv.dup) {
        argument('zero_or_more'){ arity(-1) }
        run{ m = self }
      }
    }
    assert m.param['zero_or_more'].values == argv
  end 
  def test_0450
    m = nil
    argv = %w()
    assert_raises(Main::Parameter::NotGiven){
      main(argv.dup) {
        argument('one_or_more'){ arity(-2) }
        run{ m = self }
      }
    }
  end 
  def test_0460
    m = nil
    argv = %w( a )
    assert_raises(Main::Parameter::Arity){
      main(argv.dup) {
        argument('two_or_more'){ arity(-3) }
        run{ m = self }
      }
    }
  end 
  def test_0470
    m = nil
    argv = %w( a )
    assert_raises(Main::Parameter::Arity){
      main(argv.dup) {
        argument('two_or_more'){ arity(-4) }
        run{ m = self }
      }
    }
  end 
 
# sub-command/mode functionality
#
  def test_0480
    m = nil
    argv = %w( a b )
    assert_nothing_raised{
      main(argv.dup) {
        mode 'a' do
          argument 'b'
          run{ m = self }
        end
      }
    }
    assert m, 'm.nil!'
    assert m.param['b'].value == 'b'
  end 
  def test_0490
    m = nil
    argv = %w( a b c )
    assert_nothing_raised{
      main(argv.dup) {
        mode 'a' do
          mode 'b' do
            argument 'c'
            run{ m = self }
          end
        end
      }
    }
    assert m, 'm.nil!'
    assert m.param['c'].value == 'c'
  end 
  def test_0491
    m = nil
    argv = %w(a b c)
    count = Hash.new{|h,k| h[k] = 0}
    assert_nothing_raised{
      main(argv.dup) {
        %w(
          initialize
          pre_initialize
          before_initialize
          post_initialize
          after_initialize
        ).each do |method|
          define_method(method){ count[method] += 1 }
        end
        mode 'a' do
          mode 'b' do
            mode 'c' do
              run{ m = self }
            end
          end
        end
      }
    }
    assert m, 'm.nil!'
    count.each do |key, val|
      assert val==1, key
    end
  end 

 
# parameter attr/fattr/attribute 
#
  def test_0500
    name = 'arity_zero_paramter_attr'
    m = nil
    argv = %w( )
    assert_raises(Main::Parameter::Arity){
      main(argv.dup) {
        argument(name){ arity 0 }
        run{ m = self }
      }
    }
  end 
  def test_0510
    name = 'arity_one_paramter_attr'
    m = nil
    argv = %w( a )
    #assert_nothing_raised{
      main(argv.dup) {
        argument(name){ arity 1; attr }
        run{ m = send(name) }
      }
    #}
    assert m == argv.first
  end 
  def test_0520
    name = 'arity_more_than_one_paramter_attr'
    m = nil
    argv = %w( a b c d)
    [2, 3, 4].each do |a|
      assert_nothing_raised{
        main(argv.dup) {
          argument(name){ arity a; attr }
          run{ m = send(name) }
        }
      }
      assert m == argv.first(a)
    end
  end 
  def test_0530
    name = 'arity_negative_one_paramter_attr'
    m = nil
    argvs = %w( ), %w( a ), %w( a b ), %w( a b c )
    argvs.each do |argv|
      assert_nothing_raised{
        main(argv.dup) {
          argument(name){ arity(-1); attr }
          run{ m = send(name) }
        }
      }
      assert m == argv
    end
  end 
  def test_0540
    name = 'arity_negative_more_than_one_paramter_attr'
    m = nil
    argvs = %w(a b), %w( a b c), %w( a b c d )
    argvs.each do |argv|
      [-2, -3].each do |a|
        assert_nothing_raised{
          main(argv.dup) {
            argument(name){ arity a; attr }
            run{ m  = send(name) }
          }
        }
        assert m == argv
      end
    end
  end 

  def test_0550
    name  = 'mode_argument_with_help_parameter_outputs_help'
    p = nil
    argv = %w( foo help )
    assert_nothing_raised{
      main(argv){
        mode( 'foo' ) {
          argument 'bar'
          define_method('run'){ p = param['bar'] }
        }
      }
    }
    assert( p.nil?, "p should not be set, help should have run" )
  end

  def test_0600
    src = 'finalizers should run'
    dst = nil
    argv = []
    assert_nothing_raised{
      main(argv){
        define_method('run'){ finalizers.push(lambda{ dst = src }) }
      }
    }
    assert( src==dst, "appears finalizer did not run!?" )
  end

# logging
#
  def test_0700
    argv = []
    logger = nil 
    assert_nothing_raised{
      main(argv){
        define_method('run'){ self.logger = STDERR; logger = self.logger }
      }
    }
    assert( logger.class==Main::Logger, "setting logger did not work" )
    assert( logger.device==STDERR, "setting logger did not work" )
  end

# argv with a '--' behavior
#
  def test_0800
    a = nil
    assert_nothing_raised{
      main(%w[arg --foo=42 -- --bar]){
        argument('arg')
        option('--foo=foo')
        define_method('run'){ a = @argv }
      }
    }
    assert a == ["--", "--bar"]
  end

# main_env
#
  def test_0900
    %w[ STATE STATE_DIRNAME STATE_BASENAME ].each do |key|
      value = nil
      assert_nothing_raised{
        main([], key => '42'){
          define_method('run'){ 
            k = key.downcase
            value = main_env[k]
          }
        }
      }
      assert value == '42'
    end
  end
  def test_0910
    %w[ MAIN_STATE MAIN_STATE_DIRNAME MAIN_STATE_BASENAME ].each do |key|
      value = nil
      assert_nothing_raised{
        main([], key => '42'){
          define_method('run'){ 
            k = key.downcase.sub('main_', '')
            value = main_env[k]
          }
        }
      }
      assert value == '42'
    end
  end
  def test_0920
    %w[ STATE MAIN_STATE ].each do |key|
      dir = File.expand_path(".main-test-#{ Process.pid }-#{ (rand*1000000000000).to_i }")
      FileUtils.mkdir_p(dir)
      begin
        values = [] 
        assert_nothing_raised{
          main([], key => dir){
            define_method('run'){ 
              values.push state_path
              state_path{ values.push File.expand_path(Dir.pwd) }
            }
          }
        }
        assert values == [dir, dir]
      ensure
        FileUtils.rm_rf(dir)
      end
    end
  end
end


