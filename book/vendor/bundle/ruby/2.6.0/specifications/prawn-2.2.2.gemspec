# -*- encoding: utf-8 -*-
# stub: prawn 2.2.2 ruby lib

Gem::Specification.new do |s|
  s.name = "prawn".freeze
  s.version = "2.2.2"

  s.required_rubygems_version = Gem::Requirement.new(">= 1.3.6".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Gregory Brown".freeze, "Brad Ediger".freeze, "Daniel Nelson".freeze, "Jonathan Greenberg".freeze, "James Healy".freeze]
  s.cert_chain = ["-----BEGIN CERTIFICATE-----\nMIIDcDCCAligAwIBAgIBATANBgkqhkiG9w0BAQUFADA/MQ0wCwYDVQQDDARhbGV4\nMRkwFwYKCZImiZPyLGQBGRYJcG9pbnRsZXNzMRMwEQYKCZImiZPyLGQBGRYDb25l\nMB4XDTE3MDEwNDExNDAzM1oXDTE4MDEwNDExNDAzM1owPzENMAsGA1UEAwwEYWxl\neDEZMBcGCgmSJomT8ixkARkWCXBvaW50bGVzczETMBEGCgmSJomT8ixkARkWA29u\nZTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAM85Us8YQr55o/rMl+J+\nula89ODiqjdc0kk+ibzRLCpfaFUJWxEMrhFiApRCopFDMeGXHXjBkfBYsRMFVs0M\nZfe6rIKdNZQlQqHfJ2JlKFek0ehX81buGERi82wNwECNhOZu9c6G5gKjRPP/Q3Y6\nK6f/TAggK0+/K1j1NjT+WSVaMBuyomM067ejwhiQkEA3+tT3oT/paEXCOfEtxOdX\n1F8VFd2MbmMK6CGgHbFLApfyDBtDx+ydplGZ3IMZg2nPqwYXTPJx+IuRO21ssDad\ngBMIAvL3wIeezJk2xONvhYg0K5jbIQOPB6zD1/9E6Q0LrwSBDkz5oyOn4PRZxgZ/\nOiMCAwEAAaN3MHUwCQYDVR0TBAIwADALBgNVHQ8EBAMCBLAwHQYDVR0OBBYEFE+A\njBJVt6ie5r83L/znvqjF1RuuMB0GA1UdEQQWMBSBEmFsZXhAcG9pbnRsZXNzLm9u\nZTAdBgNVHRIEFjAUgRJhbGV4QHBvaW50bGVzcy5vbmUwDQYJKoZIhvcNAQEFBQAD\nggEBAEmhsdVfgxHfXtOG6AP3qe7/PBjJPdUzNOkE/elj6TgpdvvJkOZ6QNyyqvpl\nCsoDWL0EXPM5pIETaj5z9iBRK9fAi8YNS3zckhBJwhR78cb4+MiCPIBC+iiGx5bw\nBFER2ASPeeY4uC0AHWHnURDLdxyZr+xp6pb/TitTAaCm18Kvkk1u60lOa4Jtdb+9\n2U1KICEBoX6UAzdT3N0nZ3VKq/vHVrvV2oePYCMIlNkghWp+VUE91OTBDMjnjjj8\nwxx1aB3kGoI0T6JXywKpPnzUt/qji/qpzCNiVJ0RZxzDHyZuL8NEoA9ORZnAIGiW\n5u3JK+T0toNEYkMuV6W8NU+gVyo=\n-----END CERTIFICATE-----\n".freeze]
  s.date = "2017-03-17"
  s.description = "  Prawn is a fast, tiny, and nimble PDF generator for Ruby\n".freeze
  s.email = ["gregory.t.brown@gmail.com".freeze, "brad@bradediger.com".freeze, "dnelson@bluejade.com".freeze, "greenberg@entryway.net".freeze, "jimmy@deefa.com".freeze]
  s.homepage = "http://prawnpdf.org".freeze
  s.licenses = ["PRAWN".freeze, "GPL-2.0".freeze, "GPL-3.0".freeze]
  s.required_ruby_version = Gem::Requirement.new("~> 2.1".freeze)
  s.rubygems_version = "3.0.3.1".freeze
  s.summary = "A fast and nimble PDF generator for Ruby".freeze

  s.installed_by_version = "3.0.3.1" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<ttfunk>.freeze, ["~> 1.5"])
      s.add_runtime_dependency(%q<pdf-core>.freeze, ["~> 0.7.0"])
      s.add_development_dependency(%q<pdf-inspector>.freeze, [">= 1.2.1", "< 2.0.a"])
      s.add_development_dependency(%q<yard>.freeze, [">= 0"])
      s.add_development_dependency(%q<rspec>.freeze, ["~> 3.0"])
      s.add_development_dependency(%q<rake>.freeze, ["~> 12.0"])
      s.add_development_dependency(%q<simplecov>.freeze, [">= 0"])
      s.add_development_dependency(%q<prawn-manual_builder>.freeze, [">= 0.2.0"])
      s.add_development_dependency(%q<pdf-reader>.freeze, ["~> 1.4", ">= 1.4.1"])
      s.add_development_dependency(%q<rubocop>.freeze, ["~> 0.47.1"])
      s.add_development_dependency(%q<rubocop-rspec>.freeze, ["~> 1.10"])
    else
      s.add_dependency(%q<ttfunk>.freeze, ["~> 1.5"])
      s.add_dependency(%q<pdf-core>.freeze, ["~> 0.7.0"])
      s.add_dependency(%q<pdf-inspector>.freeze, [">= 1.2.1", "< 2.0.a"])
      s.add_dependency(%q<yard>.freeze, [">= 0"])
      s.add_dependency(%q<rspec>.freeze, ["~> 3.0"])
      s.add_dependency(%q<rake>.freeze, ["~> 12.0"])
      s.add_dependency(%q<simplecov>.freeze, [">= 0"])
      s.add_dependency(%q<prawn-manual_builder>.freeze, [">= 0.2.0"])
      s.add_dependency(%q<pdf-reader>.freeze, ["~> 1.4", ">= 1.4.1"])
      s.add_dependency(%q<rubocop>.freeze, ["~> 0.47.1"])
      s.add_dependency(%q<rubocop-rspec>.freeze, ["~> 1.10"])
    end
  else
    s.add_dependency(%q<ttfunk>.freeze, ["~> 1.5"])
    s.add_dependency(%q<pdf-core>.freeze, ["~> 0.7.0"])
    s.add_dependency(%q<pdf-inspector>.freeze, [">= 1.2.1", "< 2.0.a"])
    s.add_dependency(%q<yard>.freeze, [">= 0"])
    s.add_dependency(%q<rspec>.freeze, ["~> 3.0"])
    s.add_dependency(%q<rake>.freeze, ["~> 12.0"])
    s.add_dependency(%q<simplecov>.freeze, [">= 0"])
    s.add_dependency(%q<prawn-manual_builder>.freeze, [">= 0.2.0"])
    s.add_dependency(%q<pdf-reader>.freeze, ["~> 1.4", ">= 1.4.1"])
    s.add_dependency(%q<rubocop>.freeze, ["~> 0.47.1"])
    s.add_dependency(%q<rubocop-rspec>.freeze, ["~> 1.10"])
  end
end
