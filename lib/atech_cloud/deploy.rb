Capistrano::Configuration.instance(:must_exist).load do
  
  ## Server configuration
  set :user, `whoami`.chomp
  set :ssh_options, {:forward_agent => true, :port => 22}
  
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

    task :update_code, :roles => :app do
      path = fetch(:deploy_to)
      ## Create a branch for previous (pre-deployment)
      run "cd #{path} && git branch -d rollback && git branch rollback"
      ## Update remote repository and merge deploy branch into current branch
      run "cd #{path} && git fetch origin && git reset --hard origin/#{fetch(:branch)}"
      finalise
    end

    task :finalise, :roles => :app do
      execute = Array.new
      execute << "cd #{fetch(:deploy_to)}"
      execute << "git submodule init"
      execute << "git submodule sync"
      execute << "git submodule update --recursive"
      run execute.join(' && ')

      run "cd #{fetch(:deploy_to)} && bundle --deployment --quiet"
      migrate if fetch(:run_migrations, false)
    end

    desc 'Setup the repository on the remote server for the first time'
    task :setup, :roles => :app do
      path = fetch(:deploy_to)
      run "git clone -n #{fetch(:repository)} #{path} --branch #{fetch(:branch)}"
      run "cd #{path} && git branch rollback && git checkout -b deploy && git branch -d #{fetch(:branch)}"
      run "sed 's/socket: \\\/tmp\\\/mysql.sock/host: db-a.cloud.atechmedia.net/' #{path}/config/database.yml.example > #{path}/config/database.yml ; true"
      update_code
    end
  end
  
  ## ==================================================================
  ## Database
  ## ==================================================================
  desc 'Run database migrations on the remote'
  task :migrate, :roles => :app, :only => {:database_ops => true} do
    run "cd #{fetch(:deploy_to)} && RAILS_ENV=#{fetch(:environment)} bundle exec rake db:migrate"
  end

  ## ==================================================================
  ## Rollback
  ## ==================================================================
  desc 'Rollback to the previous deployment'
  task :rollback, :roles => :app do
    run "cd #{fetch(:deploy_to)} && git reset --hard rollback"
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
      run "sudo -u app sh -c \"cd #{fetch(:deploy_to)} && bundle exec unicorn_rails -E #{fetch(:environment)} -c #{fetch(:deploy_to)}/config/unicorn.rb -D\""
    end

    task :stop, :roles => :app do
      run "sudo -u app sh -c \"kill `cat #{fetch(:deploy_to)}/tmp/pids/unicorn.pid`\""
    end

    task :restart, :roles => :app do
      run "sudo -u app sh -c \"kill -USR2 `cat #{fetch(:deploy_to)}/tmp/pids/unicorn.pid`\""
    end
  end
  
end
