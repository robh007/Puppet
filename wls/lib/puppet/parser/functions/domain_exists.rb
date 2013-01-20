# restart the puppetmaster when changed
module Puppet::Parser::Functions
  newfunction(:domain_exists, :type => :rvalue) do |args|
    
    art_exists = false
    mdwArg = args[0].strip.downcase

    # check the middleware home
    mdw_count = lookupvar('ora_mdw_cnt')
    if mdw_count.nil?
      return art_exists

    else
      # check the all mdw home
      i = 0
      while ( i < mdw_count.to_i) 

        mdw = lookupvar('ora_mdw_'+i.to_s)

        unless mdw.nil?
          mdw = mdw.strip.downcase
          os = lookupvar('operatingsystem')
          if os == "windows"
            mdw = mdw.gsub("\\","/")
            mdwArg = mdwArg.gsub("\\","/")
          end 
          

          # how many domains are there in this mdw home
          domain_count = lookupvar('ora_mdw_'+i.to_s+'_domain_cnt')
          n = 0
          while ( n < domain_count.to_i )

            # lookup up domain
            domain = lookupvar('ora_mdw_'+i.to_s+'_domain_'+n.to_s)
            unless domain.nil?
              domain = domain.strip.downcase
              
              domain_path = mdw + "/admin/" + domain

              # do we found the right domain
              if domain_path == mdwArg 
                return true
              end
            end            
            n += 1

          end

        end 
        i += 1
      end

    end

    return art_exists
  end
end

