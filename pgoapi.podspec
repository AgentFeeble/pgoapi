Pod::Spec.new do |s|

  s.name         = "pgoapi"
  s.version      = "0.0.1"
  s.summary      = "A Pokèmon Go API written in swift."
  s.description  = <<-DESC
  This is still a work in progress. The only working function at the moment is login via PTC, and downloading the following data:
  player data, hatched eggs, inventory, badges, settings, & map objects.
                   DESC

  s.homepage = "https://github.com/AgentFeeble/pgoapi"
  s.license  = "Apache"

  s.author = "Rayman Rosevear"

  s.ios.deployment_target = '8.0'
  s.osx.deployment_target = '10.10'

  s.source       = { :git => "https://github.com/AgentFeeble/pgoapi.git", :tag => "#{s.version}" }
  s.source_files = "pgoapi/Classes/**/*.{swift,h,mm}", "pgoapi/3rd Party/S2/**/*.{h,cc}"
  s.public_header_files = "pgoapi/Classes/**/*.h"

  s.requires_arc = true

  # s.xcconfig = { "HEADER_SEARCH_PATHS" => "$(SDKROOT)/usr/include/libxml2" }
  s.dependency "Alamofire", "~> 3.4.1"
  s.dependency "Bolts-Swift", "~> 1.1.0"
  s.dependency "ProtocolBuffers-Swift"

end
