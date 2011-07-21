Capistrano::Configuration.instance(:must_exist).load do
  
  ## Define the roles
  role :app
  role :storage
  
  ## Server configuration
  set :user, `whoami`.chomp
  set :ssh_options, {:forward_agent => true, :port => 22}
  
  ## Return the deployment path
  def deploy_to
    fetch(:deploy_to, nil) || "/opt/apps/#{fetch(:application)}"
  end
  
  ## Return an array of all environments which should be deployed
  def environments
    fetch(:environments, nil) || [fetch(:environment, 'production')]
  end
  
  ## Deployment namespace
  namespace :deploy do
    desc 'Deploy the latest revision of the application'
    task :default do
      update_code
      restart
    end

    desc 'Deploy and migrate the database before restart'
    task :migrations do
      set :run_migrations, true
      default
    end

    task :update_code, :roles => [:app, :storage] do
      ## Create a branch for previous (pre-deployment)
      run "cd #{deploy_to} && git branch -d rollback && git branch rollback"
      ## Update remote repository and merge deploy branch into current branch
      run "cd #{deploy_to} && git fetch origin && git reset --hard origin/#{fetch(:branch)}"
      finalise
    end

    task :finalise, :roles => [:app, :storage] do
      execute = Array.new
      execute << "cd #{deploy_to}"
      execute << "git submodule init"
      execute << "git submodule sync"
      execute << "git submodule update --recursive"
      run execute.join(' && ')

      run "cd #{deploy_to} && bundle --deployment --quiet"
      migrate if fetch(:run_migrations, false)
    end

    desc 'Setup the repository on the remote server for the first time'
    task :setup, :roles => [:app, :storage] do
      run "rm -rf #{deploy_to}"
      run "git clone -n #{fetch(:repository)} #{deploy_to} --branch #{fetch(:branch)}"
      run "cd #{deploy_to} && git branch rollback && git checkout -b deploy && git branch -d #{fetch(:branch)}"
      upload_db_config
      update_code
    end
    
    desc 'Upload the database configuration file'
    task :upload_db_config, :roles => [:app, :storage] do
      put "production:\n  adapter: mysql2\n  encoding: utf8\n  reconnect: false\n  database: #{fetch(:application, 'databasename')}\n  pool: 5\n  username: #{fetch(:application, 'dbusernmae')}\n  password: #{ENV['DBPASS'] || 'xxxx'}\n  host: #{fetch(:database_host, 'db-a.cloud.atechmedia.net')}\n", File.join(deploy_to, 'config', 'database.yml')
    end
  end
  
  ## ==================================================================
  ## Database
  ## ==================================================================
  desc 'Run database migrations on the remote'
  task :migrate, :roles => :app, :only => {:database_ops => true} do
    for environment in environments
      run "cd #{deploy_to} && RAILS_ENV=#{environment} bundle exec rake db:migrate"
    end
  end

  ## ==================================================================
  ## Rollback
  ## ==================================================================
  desc 'Rollback to the previous deployment'
  task :rollback, :roles => [:app, :storage] do
    run "cd #{deploy_to} && git reset --hard rollback"
    deploy.finalise
    deploy.restart
  end
  
  ## ==================================================================
  ## Test
  ## ==================================================================
  desc 'Test the deployment connection'
  task :testing do
    run "whoami"
  end
  
  ## ==================================================================
  ## init
  ## ==================================================================
  desc 'Restart the whole remote application'
  task :restart, :roles => :app do
    unicorn.restart
    workers.restart if respond_to?(:workers)
  end

  desc 'Stop the whole remote application'
  task :stop, :roles => :app do
    unicorn.stop
    workers.stop if respond_to?(:workers)
  end

  desc 'Start the whole remote application'
  task :start, :roles => :app do
    unicorn.start
    workers.start if respond_to?(:workers)
  end

  ## ==================================================================
  ## Unicorn Management
  ## ==================================================================
  namespace :unicorn do
    task :start, :roles => :app  do
      upload_config
      for environment in environments
        run "sudo -u app sh -c \"umask 002 && cd #{deploy_to} && bundle exec unicorn_rails -E #{environment} -c #{deploy_to}/config/unicorn.rb -D\""
      end
    end

    task :stop, :roles => :app do
      for environment in environments
        run "sudo -u app sh -c \"kill `cat #{deploy_to}/tmp/pids/unicorn.#{environment}.pid`\""
      end
    end

    task :restart, :roles => :app do
      upload_config
      for environment in environments
        run "sudo -u app sh -c \"kill -USR2 `cat #{deploy_to}/tmp/pids/unicorn.#{environment}.pid`\""
      end
    end
    
    task :upload_config, :roles => :app do
      unless fetch(:skip_unicorn_config, false)
        template_config = File.read(File.expand_path('../unicorn.rb', __FILE__))
        template_config.gsub!('$WORKER_PROCESSES', fetch(:unicorn_workers, 4).to_s)
        template_config.gsub!('$TIMEOUT', fetch(:unicorn_timeout, 30).to_s)
        put template_config, File.join(deploy_to, 'config', 'unicorn.rb')
      end
    end
  end
  
end
