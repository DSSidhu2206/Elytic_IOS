# Flutter Pod helper file

def flutter_root
  generated_xcode_build_settings_path = File.expand_path(File.join('..', 'Flutter', 'Generated.xcconfig'), __dir__)
  unless File.exist?(generated_xcode_build_settings_path)
    raise "#{generated_xcode_build_settings_path} must exist. If you're running pod install manually, make sure flutter pub get is executed first"
  end
  File.foreach(generated_xcode_build_settings_path) do |line|
    matches = line.match(/FLUTTER_ROOT\=(.*)/)
    return matches[1].strip if matches
  end
  raise "FLUTTER_ROOT not found in #{generated_xcode_build_settings_path}"
end

def flutter_install_ios_plugin_pods(ios_application_path = nil)
  ios_application_path ||= File.expand_path('..', __dir__)
  plugin_pods = parse_KV_file(File.join(flutter_root, '.flutter-plugins-dependencies'))
  plugin_pods['plugins'].each do |name, path|
    pod name, :path => File.join(ios_application_path, '..', path)
  end
end

def flutter_install_all_ios_pods(ios_application_path = nil)
  flutter_install_ios_plugin_pods(ios_application_path)
end

def parse_KV_file(file)
  if !File.exist?(file)
    return {}
  end
  pods = {}
  current_key = nil
  File.foreach(file) do |line|
    next if line.strip.empty?
    if line.include?('=')
      key, value = line.strip.split('=', 2)
      pods[key.strip] = value.strip
      current_key = key.strip
    else
      pods[current_key] += line.strip if current_key
    end
  end
  pods
end

def flutter_additional_ios_build_settings(target)
  target.build_configurations.each do |config|
    config.build_settings['ENABLE_BITCODE'] = 'NO'
  end
end
