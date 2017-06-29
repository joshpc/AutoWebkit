Pod::Spec.new do |spec|
  spec.name = "AutoWebkit"
  spec.version = "0.5.0"
  spec.summary = "A simple API to extract information from websites."
  spec.homepage = "https://github.com/joshpc/AutoWebkit"
  spec.license = { type: 'MIT', file: 'LICENSE' }
  spec.authors = { "Joshua Tessier" => 'joshpc@gmail.com' }

  spec.requires_arc = true
  spec.source = { git: "https://github.com/joshpc/AutoWebkit.git", tag: "v#{spec.version}", submodules: true }
  spec.source_files = "AutoWebkit/**/*.{h,swift}"

  spec.ios.deployment_target = "10"
  spec.osx.deployment_target = "10.12"
  spec.ios.framework  = 'UIKit'
  spec.osx.framework  = 'AppKit'
end
