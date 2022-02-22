# -*- encoding: utf-8 -*-
# stub: asciidoctor-pdf 1.5.4 ruby lib

Gem::Specification.new do |s|
  s.name = "asciidoctor-pdf".freeze
  s.version = "1.5.4"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "bug_tracker_uri" => "https://github.com/asciidoctor/asciidoctor-pdf/issues", "changelog_uri" => "https://github.com/asciidoctor/asciidoctor-pdf/blob/master/CHANGELOG.adoc", "mailing_list_uri" => "http://discuss.asciidoctor.org", "source_code_uri" => "https://github.com/asciidoctor/asciidoctor-pdf" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Dan Allen".freeze, "Sarah White".freeze]
  s.date = "2021-01-09"
  s.description = "An extension for Asciidoctor that converts AsciiDoc documents to PDF using the Prawn PDF library.".freeze
  s.email = "dan@opendevise.com".freeze
  s.executables = ["asciidoctor-pdf".freeze, "asciidoctor-pdf-optimize".freeze]
  s.files = ["bin/asciidoctor-pdf".freeze, "bin/asciidoctor-pdf-optimize".freeze]
  s.homepage = "https://asciidoctor.org/docs/asciidoctor-pdf".freeze
  s.licenses = ["MIT".freeze]
  s.rubygems_version = "3.0.3.1".freeze
  s.summary = "Converts AsciiDoc documents to PDF using Asciidoctor and Prawn".freeze

  s.installed_by_version = "3.0.3.1" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<asciidoctor>.freeze, [">= 1.5.3", "< 3.0.0"])
      s.add_runtime_dependency(%q<prawn>.freeze, ["~> 2.2.0"])
      s.add_runtime_dependency(%q<ttfunk>.freeze, ["~> 1.5.0", ">= 1.5.1"])
      s.add_runtime_dependency(%q<prawn-table>.freeze, ["~> 0.2.0"])
      s.add_runtime_dependency(%q<prawn-templates>.freeze, ["~> 0.1.0"])
      s.add_runtime_dependency(%q<prawn-svg>.freeze, ["~> 0.31.0"])
      s.add_runtime_dependency(%q<prawn-icon>.freeze, ["~> 2.5.0"])
      s.add_runtime_dependency(%q<safe_yaml>.freeze, ["~> 1.0.0"])
      s.add_runtime_dependency(%q<thread_safe>.freeze, ["~> 0.3.0"])
      s.add_runtime_dependency(%q<concurrent-ruby>.freeze, ["~> 1.1.0"])
      s.add_runtime_dependency(%q<treetop>.freeze, ["~> 1.6.0"])
      s.add_development_dependency(%q<rake>.freeze, ["~> 13.0.0"])
      s.add_development_dependency(%q<rspec>.freeze, ["~> 3.9.0"])
      s.add_development_dependency(%q<pdf-inspector>.freeze, ["~> 1.3.0"])
      s.add_development_dependency(%q<rouge>.freeze, ["~> 3.0"])
      s.add_development_dependency(%q<coderay>.freeze, ["~> 1.1.0"])
      s.add_development_dependency(%q<chunky_png>.freeze, ["~> 1.3.0"])
    else
      s.add_dependency(%q<asciidoctor>.freeze, [">= 1.5.3", "< 3.0.0"])
      s.add_dependency(%q<prawn>.freeze, ["~> 2.2.0"])
      s.add_dependency(%q<ttfunk>.freeze, ["~> 1.5.0", ">= 1.5.1"])
      s.add_dependency(%q<prawn-table>.freeze, ["~> 0.2.0"])
      s.add_dependency(%q<prawn-templates>.freeze, ["~> 0.1.0"])
      s.add_dependency(%q<prawn-svg>.freeze, ["~> 0.31.0"])
      s.add_dependency(%q<prawn-icon>.freeze, ["~> 2.5.0"])
      s.add_dependency(%q<safe_yaml>.freeze, ["~> 1.0.0"])
      s.add_dependency(%q<thread_safe>.freeze, ["~> 0.3.0"])
      s.add_dependency(%q<concurrent-ruby>.freeze, ["~> 1.1.0"])
      s.add_dependency(%q<treetop>.freeze, ["~> 1.6.0"])
      s.add_dependency(%q<rake>.freeze, ["~> 13.0.0"])
      s.add_dependency(%q<rspec>.freeze, ["~> 3.9.0"])
      s.add_dependency(%q<pdf-inspector>.freeze, ["~> 1.3.0"])
      s.add_dependency(%q<rouge>.freeze, ["~> 3.0"])
      s.add_dependency(%q<coderay>.freeze, ["~> 1.1.0"])
      s.add_dependency(%q<chunky_png>.freeze, ["~> 1.3.0"])
    end
  else
    s.add_dependency(%q<asciidoctor>.freeze, [">= 1.5.3", "< 3.0.0"])
    s.add_dependency(%q<prawn>.freeze, ["~> 2.2.0"])
    s.add_dependency(%q<ttfunk>.freeze, ["~> 1.5.0", ">= 1.5.1"])
    s.add_dependency(%q<prawn-table>.freeze, ["~> 0.2.0"])
    s.add_dependency(%q<prawn-templates>.freeze, ["~> 0.1.0"])
    s.add_dependency(%q<prawn-svg>.freeze, ["~> 0.31.0"])
    s.add_dependency(%q<prawn-icon>.freeze, ["~> 2.5.0"])
    s.add_dependency(%q<safe_yaml>.freeze, ["~> 1.0.0"])
    s.add_dependency(%q<thread_safe>.freeze, ["~> 0.3.0"])
    s.add_dependency(%q<concurrent-ruby>.freeze, ["~> 1.1.0"])
    s.add_dependency(%q<treetop>.freeze, ["~> 1.6.0"])
    s.add_dependency(%q<rake>.freeze, ["~> 13.0.0"])
    s.add_dependency(%q<rspec>.freeze, ["~> 3.9.0"])
    s.add_dependency(%q<pdf-inspector>.freeze, ["~> 1.3.0"])
    s.add_dependency(%q<rouge>.freeze, ["~> 3.0"])
    s.add_dependency(%q<coderay>.freeze, ["~> 1.1.0"])
    s.add_dependency(%q<chunky_png>.freeze, ["~> 1.3.0"])
  end
end
