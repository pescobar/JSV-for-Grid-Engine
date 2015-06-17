#!/usr/bin/perl

use strict;
use warnings;
no warnings qw/uninitialized/;

use Env qw(SGE_ROOT);
use lib "$SGE_ROOT/util/resources/jsv";
use JSV qw( :DEFAULT jsv_sub_is_param jsv_sub_add_param jsv_sub_get_param jsv_send_env jsv_log_info jsv_is_param jsv_get_param jsv_log_warning jsv_log_error jsv_show_params jsv_sub_del_param jsv_del_param);

# this extra lib is used only in case I want to dump the hash containing all the arguments
use Data::Dumper;

#my $time;

# in this hash I will save all the arguments provided by the user
# To update this I use the function jsv_get_param_hash();
our %params;

# list of users allowed to use core_binding
our @binding_users = ("user1","user2");

jsv_on_start(sub {
   jsv_send_env();
});


jsv_on_verify(sub {
   
   # print all params to qmaster logfile for debugging
   #my %params = jsv_get_param_hash();
   #my $argshash = Dumper(\%params);
   #$argshash=~s/\n//g;
   #$argshash=~s/ +/ /g;
   #jsv_log_warning($argshash);

   # print all params to STDOUT for debugging
   # this only works when running jsv at client side
   #jsv_show_params();
   
   # this functions can be used to add info to the master logfile
   # only works when running jsv in server side
   #jsv_log_warning('running jsv_log_warning()');
   #jsv_log_error('running jsv_log_error()');
   

    ########################################
    #  QUEUE AND RUNTIME SETUP
    ########################################
    
    
    ## CHRISTMAS FIX ##
    # SEND EVERYTHING TO YEAR.Q #
    # excepting for users in array @binding_users 
    # which is actually just pescobar
    
    #my $username2 = jsv_get_param("USER");
    #if (!($username2 ~~ @binding_users)){
    #jsv_set_param('q_hard','year.q');
    #}  

    #################################
    

    # if users ask for h_rt we setup d_rt (runtime) to the same value
    if (jsv_sub_is_param("l_hard","h_rt")){
        my $runtime = jsv_sub_get_param("l_hard","h_rt");
        jsv_sub_add_param('l_hard','d_rt',$runtime);
    }
    
    # if users don't ask for memory (h_vmem) we setup a default value of 4G
    if (!(jsv_sub_is_param("l_hard","h_rss"))){
        jsv_sub_add_param('l_hard','h_rss','2G');
    }
       
    # if user selects a queue we don't modify anything
    # about queues or d_rt. This way we allow power users
    # to select queues or hostgroups
    #if (jsv_is_param("q_hard")){
    #   #jsv_log_warning('iiiiiinnn');
    #}
        
    # user don't ask for time or queue so we setup the default
    # queue short.q which has a max runtime of 6h (23/01/2014)
    ###########################################################
    elsif (!(jsv_is_param("q_hard")) && (! jsv_sub_get_param('l_hard', 'd_rt')) ) {
           # we have disabled this option and now we don't setup default d_rt to 06:00:00
           # this way we avoid backfilling and resource reservation works when trying to
           # reserve a high number of slots
           #jsv_sub_add_param('l_hard','d_rt','06:00:00');
           jsv_sub_add_param('q_hard','short.q');
          
    }
   
    # user ask for runtime (d_rt or h_rt) but DON'T ASK for queue
    # so we take the time and setup the queue accordingly
    ##########################################################
    if (!(jsv_is_param("q_hard")) && (jsv_is_param('l_hard', 'd_rt')) ) {
            
        # We get the hash %params containing all the user params
        # If we modify any argument later in this script with jsv_sub_add_param()) 
        # we should update this hash
        %params = jsv_get_param_hash();
        my $time = $params{l_hard}{d_rt};
        #jsv_log_warning('time');
        #jsv_log_warning($time);

                
        if ($time <= 21600){      # 6 hours = 21600sec
            jsv_sub_add_param('q_hard','short.q');
        }
        elsif ($time <= 86400){   # 1 day = 86400sec
            jsv_sub_add_param('q_hard','long.q');
        }
        elsif ($time <= 604800){  # 1 week = 168 hours = 604800sec
            jsv_sub_add_param('q_hard','very_long.q');
        }
        else { # if requested time is over 1 week the job goes to infinite.q
            jsv_sub_add_param('q_hard','infinite.q');
        }
            
    }   


        ########################################
        #  END - QUEUE AND RUNTIME (H_RT) SETUP
        ########################################



        ########################################
        #  CORE BINDING SETUP
        ########################################

    # Only allow users in @binding_users to specify custom binding
    # reject jobs for users not in @binding_users
    #%params = jsv_get_param_hash();
    #my $username = jsv_get_param("USER");
    #if ((exists $params{binding_strategy}) && !($username ~~ @binding_users)){
    #   #jsv_log_info ('rejected binding request');
    #   #jsv_reject ('Are you sure you want to specify binding strategy? Contact bc2-admin@unibas.ch');
    
    #   jsv_log_info ('removing binding from job');
    #   jsv_del_param('binding_type');  # this is not working
    #   jsv_del_param('binding_strategy');  # this is not working
    #   jsv_del_param('binding_amount');  # this is not working
    
    #   return;
    #}

    # if not binding is specified we setup it
    %params = jsv_get_param_hash();
    if (!(exists $params{binding_strategy})) {
        # binding for standar jobs without PE:
        if (!(exists $params{pe_name}) || (($params{pe_name} eq 'smp') && ($params{pe_min} eq '1')) ) {
                    # -------------------------------------------
                    # in case no parallel environment was chosen
            # or PE smp asking for just 1 core
                    # add a default request of one processor core
                    # -------------------------------------------

            #jsv_sub_add_param('binding_type','set');
            #jsv_sub_add_param('binding_strategy','linear_automatic');
            #jsv_sub_add_param('binding_amount','1');

        }elsif ($params{pe_name} eq 'smp'){
                    # -------------------------------------------
            #  PE smp asking for just X core
                    #  Add binding for X cores
                    # -------------------------------------------

            #jsv_sub_add_param('binding_type','set');
            #jsv_sub_add_param('binding_strategy','linear_automatic');
            #jsv_sub_add_param('binding_amount',"$params{pe_max}");

        }elsif ($params{pe_name} eq 'ompi'){
                    # -------------------------------------------
            #  We don't do automatic binding for openmpi
                    #  Maybe we should?
                    # -------------------------------------------
            #jsv_sub_add_param('binding_type','set');
            #jsv_sub_add_param('binding_strategy','linear_automatic');
            #jsv_sub_add_param('binding_amount',"$params{pe_max}");
        }   
    } 


        ########################################
        #  END CORE BINDING SETUP
        ########################################

    
    ########################################
        #  RESERVATION SETUP
        ########################################
    
    # if selecting parallel environment smp and more than 1 slot, activate reservation
    if (!(jsv_is_param("R"))) {
        if (($params{pe_name} eq 'smp') && ($params{pe_min} gt '1')){
            jsv_sub_add_param('R','y');
            jsv_log_info ('This is SMP job. Activate reservation');
        }
    }
    # if selecting parallel environment ompi and more than 1 slot, activate reservation
    if (!(jsv_is_param("R"))) {
        if (($params{pe_name} eq 'ompi') && ($params{pe_min} gt '1')){
            jsv_sub_add_param('R','y');
            jsv_log_info ('This is OpenMPI job. Activate reservation');
        }
    }
    ########################################
        #  END RESERVATION SETUP
        ########################################
   
      jsv_accept('Job is accepted');
      return;


}); 

jsv_main();


