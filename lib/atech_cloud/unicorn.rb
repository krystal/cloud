rails_env = ENV['RAILS_ENV'] || 'production'

## Directory to use for stuff
rails_root = File.expand_path('../../', __FILE__)
FileUtils.mkdir_p(File.join(rails_root, 'tmp', 'sockets'))
FileUtils.mkdir_p(File.join(rails_root, 'tmp', 'pids'))
FileUtils.mkdir_p(File.join(rails_root, 'log'))

## Set the number of worker processes which can be spawned
worker_processes $WORKER_PROCESSES

## Preload the application into master for fast worker spawn
## times.
preload_app true

## Restart any workers which haven't responded for 30 seconds.
timeout $TIMEOUT

## Store the pid file safely away in the pids folder
logger Logger.new(File.join(rails_root, 'log', "unicorn.#{rails_env}.log"))
pid File.join(rails_root, 'tmp', 'pids', "unicorn.#{rails_env}.pid")

## Listen on a unix data socket
listen File.join(rails_root, 'tmp', 'sockets', "unicorn.#{rails_env}.sock")

before_fork do |server, worker|
  # When sent a USR2, Unicorn will suffix its pidfile with .oldbin and
  # immediately start loading up a new version of itself (loaded with a new
  # version of our app). When this new Unicorn is completely loaded
  # it will begin spawning workers. The first worker spawned will check to
  # see if an .oldbin pidfile exists. If so, this means we've just booted up
  # a new Unicorn and need to tell the old one that it can now die. To do so
  # we send it a QUIT.
  #
  # Using this method we get 0 downtime deploys.

  old_pid = File.join(rails_root, 'tmp', 'pids', "unicorn.#{rails_env}.pid.oldbin")
  if File.exists?(old_pid) && server.pid != old_pid
    begin
      Process.kill("QUIT", File.read(old_pid).to_i)
    rescue Errno::ENOENT, Errno::ESRCH
      # someone else did our job for us
    end
  end
end

after_fork do |server, worker|
  # Unicorn master loads the app then forks off workers - because of the way
  # Unix forking works, we need to make sure we aren't using any of the parent's
  # sockets, e.g. db connection
  ActiveRecord::Base.establish_connection
  srand
end
