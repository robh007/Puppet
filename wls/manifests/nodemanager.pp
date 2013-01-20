# == Define: wls::nodemanager
#
# install and configures nodemanager  
#
#
# === Examples
#
#  $jdkWls12cJDK = 'jdk1.7.0_09'
#  $wls12cVersion = "1211"
#
#  
#  case $operatingsystem {
#     centos, redhat, OracleLinux, ubuntu, debian: { 
#       $osWlHome     = "/opt/oracle/wls/wls12c/wlserver_12.1"
#       $user         = "oracle"
#       $group        = "dba"
#     }
#     windows: { 
#       $osWlHome     = "c:/oracle/wls/wls12c/wlserver_12.1"
#       $user         = "Administrator"
#       $group        = "Administrators"
#       $serviceName  = "C_oracle_wls_wls12c_wlserver_12.1"
#     }
#  }
#
#
#  Wls::Nodemanager {
#    wlHome       => $osWlHome,
#    fullJDKName  => $jdkWls12cJDK,	
#    user         => $user,
#    group        => $group,
#    serviceName  => $serviceName,  
#  }
#
#  #nodemanager configuration and starting
#  wls::nodemanager{'nodemanager':
#    listenPort   => '5556',
#  }
# 


define wls::nodemanager($wlHome          = undef, 
                        $fullJDKName     = undef,
                        $listenPort      = 5556,
                        $user            = 'oracle',
                        $group           = 'dba',
                        $serviceName     = undef,
                       ) {


   case $operatingsystem {
     centos, redhat, OracleLinux, ubuntu, debian: { 

        $otherPath        = '/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/sbin:'
        $execPath         = "/usr/java/${fullJDKName}/bin:${otherPath}"
        $checkCommand     = "/bin/ps -ef | grep -v grep | /bin/grep 'weblogic.NodeManager' | /bin/grep '${listenPort}'"
        $path             = '/install/'
        $JAVA_HOME        = "/usr/java/${fullJDKName}"
        
        Exec { path      => $execPath,
               user      => $user,
               group     => $group,
               logoutput => true,
               cwd       => "${wlHome}/common/nodemanager",
             }
     
     }
     windows: { 

        $execPath         = "C:\\unxutils\\bin;C:\\unxutils\\usr\\local\\wbin;C:\\Windows\\system32;C:\\Windows"
        $checkCommand     = "C:\\Windows\\System32\\cmd.exe /c" 
        $path             = "c:\\temp\\" 
        $JAVA_HOME        = "C:\\oracle\\${fullJDKName}"

        Exec { path      => $execPath,
               cwd       => "${wlHome}/common/nodemanager",
             }
     }
   }

   $javaCommand  = "java -client -Xms32m -Xmx200m -XX:PermSize=128m -XX:MaxPermSize=256m -Djava.security.egd=file:/dev/./urandom -DListenPort=${listenPort} -Dbea.home=${wlHome} -Dweblogic.nodemanager.JavaHome=${JAVA_HOME} -Djava.security.policy=${wlHome}/server/lib/weblogic.policy -Xverify:none weblogic.NodeManager -v"


    
   case $operatingsystem {
     centos, redhat, OracleLinux, ubuntu, debian: { 

        exec { "execwlst ux nodemanager ${title}":
          command     => "/usr/bin/nohup ${javaCommand} &",
          environment => ["CLASSPATH=${wlHome}/server/lib/weblogic.jar",
                          "JAVA_HOME=${JAVA_HOME}",
                          "LD_LIBRARY_PATH=$LD_LIBRARY_PATH:${wlHome}/server/native/linux/x86_64",
                          "CONFIG_JVM_ARGS=-Djava.security.egd=file:/dev/./urandom"],
          unless      => "${checkCommand}",
        }    

        # wait for the nodemanager.properties file
        exec { "execwlst ux StopScriptEnabled ${title}":
          command     => "/bin/sed 's/StopScriptEnabled=false/StopScriptEnabled=true/g' nodemanager.properties > nodemanager1.properties",
          unless      => "/usr/bin/test -f ${wlHome}/common/nodemanager/nodemanager.properties",
          require     => Exec ["execwlst ux nodemanager ${title}"],
          tries       => 2,
          try_sleep   => 10,
        }    

        exec { "execwlst ux StartScriptEnabled ${title}":
          command     => "/bin/sed 's/StartScriptEnabled=false/StartScriptEnabled=true/g' nodemanager1.properties > nodemanager2.properties",
          onlyif      => "/usr/bin/test -f ${wlHome}/common/nodemanager/nodemanager1.properties",
          subscribe   => Exec ["execwlst ux StopScriptEnabled ${title}"],
          refreshonly => true,
        } 
        exec { "execwlst ux CrashRecoveryEnabled ${title}":
          command     => "/bin/sed 's/CrashRecoveryEnabled=false/CrashRecoveryEnabled=true/g' nodemanager2.properties > nodemanager.properties",
          onlyif      => "/usr/bin/test -f ${wlHome}/common/nodemanager/nodemanager2.properties",
          subscribe   => Exec ["execwlst ux StartScriptEnabled ${title}"],
          refreshonly => true,
        } 

        # delete old files used by sed
        file { "${wlHome}/common/nodemanager/nodemanager1.properties":
           ensure     => absent,
           require    => Exec ["execwlst ux CrashRecoveryEnabled ${title}"],
        }
        file { "${wlHome}/common/nodemanager/nodemanager2.properties":
           ensure     => absent,
           require  => File["${wlHome}/common/nodemanager/nodemanager1.properties"],
        }


        exec { "sleep 15 sec for wlst exec ${title}":
          command     => "/bin/sleep 15",
          subscribe   => Exec ["execwlst ux nodemanager ${title}"],
          refreshonly => true,
        }  


             
     }
     windows: { 

        exec {"icacls win nodemanager bin ${title}": 
           command    => "${checkCommand} icacls ${wlHome}\\server\\bin\\* /T /C /grant Administrator:F Administrators:F",
           unless     => "${checkCommand} test -e ${wlHome}/common/nodemanager/nodemanager.properties",
           logoutput  => false,
        } 

        exec {"icacls win nodemanager native ${title}": 
           command    => "${checkCommand} icacls ${wlHome}\\server\\native\\* /T /C /grant Administrator:F Administrators:F",
           unless     => "${checkCommand} test -e ${wlHome}/common/nodemanager/nodemanager.properties",
           logoutput  => false,
        } 

        exec { "execwlst win nodemanager ${title}":
          command     => "${wlHome}\\server\\bin\\installNodeMgrSvc.cmd",
          environment => ["CLASSPATH=${wlHome}\\server\\lib\\weblogic.jar",
                          "JAVA_HOME=${JAVA_HOME}"],
          require     => [Exec ["icacls win nodemanager bin ${title}"],Exec ["icacls win nodemanager native ${title}"]],
          unless      => "${checkCommand} test -e ${wlHome}/common/nodemanager/nodemanager.properties",
          logoutput   => true,
        }    

        service { "window nodemanager initial start ${title}":
                name       => "Oracle WebLogic NodeManager (${serviceName})",
                enable     => true,
                ensure     => true,
                require    => Exec ["execwlst win nodemanager ${title}"],
        }

        exec { "execwlst win StopScriptEnabled ${title}":
          command     => "${checkCommand} sed \"s/StopScriptEnabled=false/StopScriptEnabled=true/g\" nodemanager.properties > nodemanager1.properties",
          unless      => "${checkCommand} dir ${wlHome}/common/nodemanager/nodemanager.properties",
          creates     => "${wlHome}/common/nodemanager/nodemanager1.properties",
          require     => [Service ["window nodemanager initial start ${title}"],Exec ["execwlst win nodemanager ${title}"]],
          tries       => 6,
          try_sleep   => 5,
          logoutput   => true,
        }    

        exec { "execwlst win StartScriptEnabled ${title}":
          command     => "${checkCommand} sed \"s/StartScriptEnabled=false/StartScriptEnabled=true/g\" nodemanager1.properties > nodemanager2.properties",
          onlyif      => "${checkCommand} test -e ${wlHome}/common/nodemanager/nodemanager1.properties",
          logoutput   => true,
          subscribe   => Exec ["execwlst win StopScriptEnabled ${title}"],
          refreshonly => true,

        } 
        exec { "execwlst win CrashRecoveryEnabled ${title}":
          command     => "${checkCommand} sed \"s/CrashRecoveryEnabled=false/CrashRecoveryEnabled=true/g\" nodemanager2.properties > nodemanager.properties",
          onlyif      => "${checkCommand} test -e ${wlHome}/common/nodemanager/nodemanager2.properties",
          subscribe   => Exec ["execwlst win StartScriptEnabled ${title}"],
          refreshonly => true,
          logoutput   => true,
        } 


        # delete old files used by sed
        file { "${wlHome}/common/nodemanager/nodemanager1.properties":
           ensure     => absent,
           require    => Exec ["execwlst win CrashRecoveryEnabled ${title}"],
        }

        file { "${wlHome}/common/nodemanager/nodemanager2.properties":
           ensure   => absent,
           require  => File["${wlHome}/common/nodemanager/nodemanager1.properties"],
        }

        exec { "execwlst win stop service ${title}":
          command     => "${checkCommand} NET STOP \"Oracle WebLogic NodeManager (${serviceName})\"",
          subscribe   => File ["${wlHome}/common/nodemanager/nodemanager2.properties"],
          refreshonly => true,
          logoutput   => true,
        } 

        exec { "execwlst win start service ${title}":
          command     => "${checkCommand} NET START \"Oracle WebLogic NodeManager (${serviceName})\"",
          subscribe   => Exec ["execwlst win stop service ${title}"],
          refreshonly => true,
          logoutput   => true,
        } 



     }
   }
}
