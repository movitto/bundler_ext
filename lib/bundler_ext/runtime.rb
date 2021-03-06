require "bundler_ext/output"

module BundlerExt
  class Runtime
    def gemfile(new_val = nil)
      @bext_gemfile ||= Bundler.default_gemfile
      @bext_gemfile   = new_val unless new_val.nil?
      @bext_gemfile
    end

    def root
      gemfile.dirname.expand_path
    end

    def bundler
      @bundler_runtime ||= Bundler::Runtime.new(root, gemfile)
    end

    def rubygems
      @bundler_rubygems ||= Bundler::RubygemsIntegration.new
    end


    def setup_env
      # some rubygems do not play well with daemonized processes ($HOME is empty)
      ENV['HOME'] = ENV['BEXT_HOME']        if ENV['BEXT_HOME']
      ENV['HOME'] = ENV['BUNDLER_EXT_HOME'] if ENV['BUNDLER_EXT_HOME']
    end

    def system_require(files)
      files.each do |dep|
        #This part ripped wholesale from lib/bundler/runtime.rb (github/master)
        begin
          #puts "Attempting to require #{dep}"
          require dep
        rescue LoadError => e
          #puts "Caught error: #{e.message}"
          if dep.include?('-')
            begin
              if dep.respond_to? :name
                namespaced_file = dep.name.gsub('-', '/')
              else
                # try to load unresolved deps
                namespaced_file = dep.gsub('-', '/')
              end
              #puts "Munged the name, now trying to require as #{namespaced_file}"
              require namespaced_file
            rescue LoadError => e2
              Output.strict_err "Gem loading error: #{e2.message}"
            end
          else
            Output.strict_err "Gem loading error: #{e.message}"
          end
        end
      end
    end

    def clear
      bundler.send :clean_load_path
    end

    def add_spec(spec)
      # copied from Bundler::Runtime#setup
      rubygems.mark_loaded spec
      load_paths = spec.load_paths.reject {|path| $LOAD_PATH.include?(path)}
      $LOAD_PATH.unshift(*load_paths)
    end
  end
end
