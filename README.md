#The aTech Cloud

This gem provides some deployment recipes for deploying to an aTech Cloud Virtual Machine.
This is only really of use to aTech Developers but you may find some interesting tools 
which you can use in your own deployment scripts.

Use the file below as a starting point for a new Capfile:

    require 'atech_cloud/deploy'
    
    ## Set the name for the application
    set :application, "support"
    
    ## Path where the application should be stored
    set :repository, "git@codebasehq.com:atechmedia/help/app.git"
    set :branch, "master"
    
    ## Which rails environment should all processes be executed under
    set :environment, "production"
    
    ## Define all servers which are 
    role :app, "atechweb01.cloud.atechmedia.net", :database_ops => true
