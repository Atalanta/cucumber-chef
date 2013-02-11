require 'rubygems'
require 'cucumber'
require 'cucumber/rake/task'

namespace :cc do

  desc "Run features in a style suitable for Continuous Integration"
  task :ci do |t|
    pushed = false
    exit_codes = Array.new

    puts("Cleaning up...")
    system(%Q{rm -rfv artifacts})
    system(%Q{rm -rfv public})
    system(%Q{mkdir -v public})
    system(%Q{echo "<html><head><title>Cucumber-Chef Report</title></head><body>" | tee public/index.html})
    system(%Q{echo "<h2>Cucumber-Chef Report</h2><ul>" | tee -a public/index.html})

    puts("Generating Cucumber-Chef html reports...")
    Dir.glob("features/*").each do |feature_dir|
      found_features = false
      Dir.glob("#{feature_dir}/*.feature") do |feature|
        if found_features == false
          found_features = true
          system(%Q{echo "<li /><p>#{File.basename(feature_dir)}<ul>" | tee -a public/index.html})
        end
        filename = feature.gsub(/(\w*).feature/, '\1.html')
        puts("#{feature} -> public/#{filename}")

        system(%Q{mkdir -pv #{File.dirname("public/#{filename}")}})

        push = (pushed ? nil : %Q{SETUP="YES"})
        command = [push, "bundle exec cucumber", "features/support", feature, ENV['EXTRA_CUCUMBER_ARGS'], "--format html", "--out public/#{filename}"].flatten.compact.join(" ")
        pushed = true if !pushed
        puts("command=#{command.inspect}")
        system(command)
        exit_codes << $?.exitstatus

        passed = "<font style='font-weight: bold; color: green;'>PASSED</font>"
        failed = "<font style='font-weight: bold; color: red;'>FAILED</font>"
        status = ((exit_codes[-1] == 0) ? passed : failed)

        system(%Q{echo "<li /><a href='#{filename}'>#{File.basename(filename.gsub('.html', ''))}</a> (#{status})" | tee -a public/index.html})
      end

      if found_features
        system(%Q{echo "</p></ul>" | tee -a public/index.html})
      end
    end

    system(%Q{echo "</ul></body></html>" | tee -a public/index.html})

    system(%Q{/bin/bash -c '[[ -d $CUCUMBER_CHEF_HOME/aws/artifacts ]] && mv -v $CUCUMBER_CHEF_HOME/aws/artifacts .'})

    # If we had a failure be sure to surface it
    exit_code = (exit_codes.any?{ |ec| ec != 0 } ? 1 : 0)
    exit(exit_code)
  end

  Cucumber::Rake::Task.new(:cucumber) do |t|
    feature_dirs = Array.new

    feature_dir_glob = File.join(Dir.pwd, "*cookbook*", "*", "*feature*")
    feature_dirs << Dir.glob(feature_dir_glob)

    feature_dir_glob = File.join(Dir.pwd, "*feature*")
    feature_dirs << Dir.glob(feature_dir_glob)

    opts = [
      "--exclude support/cookbooks",
      "--exclude support/data_bags",
      "--exclude support/environments",
      "--exclude support/keys",
      "--exclude support/roles",
      feature_dirs
    ].flatten.compact.join(" ")

    t.cucumber_opts = opts
  end

end
