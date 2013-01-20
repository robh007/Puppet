# == Define: wls::bsupatch
#
# installs bsu patch for weblogic  
#
#
# === Examples
#
#    $jdkWls11gJDK = 'jdk1.7.0_09'
#    $wls11gVersion = "1036"
# 
#  case $operatingsystem {
#     centos, redhat, OracleLinux, ubuntu, debian: { 
#       $osMdwHome    = "/opt/oracle/wls/wls11g"
#       $osWlHome     = "/opt/oracle/wls/wls11g/wlserver_10.3"
#       $user         = "oracle"
#       $group        = "dba"
#     }
#     windows: { 
#       $osMdwHome    = "c:/oracle/wls/wls11g"
#       $osWlHome     = "c:/oracle/wls/wls11g/wlserver_10.3"
#       $user         = "Administrator"
#       $group        = "Administrators"
#     }
#  }
#
#  wls::bsupatch{'p13573621':
#    mdwHome      => $osMdwHome ,
#    wlHome       => $osWlHome,
#    fullJDKName  => $defaultFullJDK,
#    patchId      => 'KZKQ',	
#    patchFile    => 'p13573621_1036_Generic.zip',	
#    user         => $user,
#    group        => $group, 
#  }
## 


define wls::bsupatch($mdwHome         = undef,
                     $wlHome          = undef,
                     $fullJDKName     = undef, 
                     $patchId         = undef,
                     $patchFile       = undef,	
                     $user            = 'oracle',
                     $group           = 'dba',
                    ) {

   case $operatingsystem {
     centos, redhat, OracleLinux, ubuntu, debian: { 

        $execPath        = '/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/sbin:'
        $path             = '/install/'
        
        Exec { path      => $execPath,
               user      => $user,
               group     => $group,
               logoutput => true,
             }
        File {
               ensure  => present,
               mode    => 0775,
               owner   => $user,
               group   => $group,
             }        
     }
     windows: { 

        $execPath         = "C:\\oracle\\${fullJDKName}\\bin;C:\\unxutils\\bin;C:\\unxutils\\usr\\local\\wbin;C:\\Windows\\system32;C:\\Windows"
        $checkCommand     = "C:\\Windows\\System32\\cmd.exe /c" 
        $path             = "c:\\temp\\" 

        Exec { path      => $execPath,
             }
        File { ensure  => present,
               mode    => 0555,
             }   
     }
   }
   if ! defined(File["${mdwHome}/utils/bsu/cache_dir"]) {
     file { "${mdwHome}/utils/bsu/cache_dir":
       ensure  => directory,
       recurse => false, 
     }
   }

   # the patch used by the bsu
   if ! defined(File["${path}${patchFile}"]) {
    file { "${path}${patchFile}":
     source  => "puppet:///modules/wls/${patchFile}",
     require => File ["${mdwHome}/utils/bsu/cache_dir"],
    }
   }



     # check if the bsu already is installed 
     $found = bsu_exists($mdwHome,$patchId)
     if $found == undef {
       $continue = true
     } else {
       if ( $found ) {
         notify {"wls::bsupatch ${title} ${mdwHome} already exists":}
         $continue = false
       } else {
         notify {"wls::bsupatch ${title} ${mdwHome} does not exists":}
         $continue = true 
       }
     }


if ( $continue ) {

   
   $bsuCommand  = "-prod_dir=${wlHome} -patchlist=${patchId} -verbose -install"
    
   case $operatingsystem {
     centos, redhat, OracleLinux, ubuntu, debian: { 

        exec { "extract ${patchFile}":
          command => "unzip -n ${path}/${patchFile} -d ${mdwHome}/utils/bsu/cache_dir",
          require => File ["${path}${patchFile}"],
          creates => "${mdwHome}/utils/bsu/cache_dir/${patchId}.jar",
        }
        
        exec { "exec bsu ux ${title}":
          command     => "${mdwHome}/utils/bsu/bsu.sh ${bsuCommand}",
          require     => Exec["extract ${patchFile}"],
          cwd         => "${mdwHome}/utils/bsu",
        }    
             
     }
     windows: { 

        exec {"icacls win patchfile ${title}": 
           command    => "${checkCommand} icacls ${mdwHome}/utils/bsu/cache_dir /T /C /grant Administrator:F Administrators:F",
#           unless     => "${checkCommand} test -e ${mdwHome}/utils/bsu/cache_dir/${patchId}.jar",
           logoutput  => false,
           require    => File ["${path}${patchFile}"],
        } 

        exec { "extract ${patchFile} ${title}":
          command => "jar.exe xf ${path}${patchFile}",
          cwd     => "${mdwHome}/utils/bsu/cache_dir",
          creates => "${mdwHome}/utils/bsu/cache_dir/${patchId}.jar",
          require => Exec["icacls win patchfile ${title}"],
        }

        exec { "exec bsu win ${title}":
          command     => "${checkCommand} bsu.cmd ${bsuCommand}",
          logoutput   => true,
          require     => Exec["extract ${patchFile} ${title}"],
          cwd         => "${mdwHome}\\utils\\bsu",
        }    

     }
   }
}
}
