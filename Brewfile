def work_machine?
    snitches = [
        'IntelligentHubAgent',
        'Enterprise Connect',
        'Confer.app', # Carbon Black
        'CbDefense' # Carbon Black
    ]
    snitches.reduce(false) { |memo, snitch| system("pgrep -iq '#{snitch}'") || memo }
end

def fix_ql_plugins
	Dir["#{ENV['HOME']}/Library/QuickLook/*qlgenerator"].each do |plugin|
		puts "Enabling #{plugin}"
		system("xattr -d -r com.apple.quarantine #{plugin}")
	end
	puts "Resetting Quick Look Server"
	system("qlmanage -r")
end

puts "IS WORK MACHINE?: #{work_machine?}"

tap 'homebrew/bundle'
tap 'homebrew/core'
tap 'homebrew/cask'
tap 'homebrew/cask-versions'

brew 'coreutils'
brew 'git'
tap 'git-duet/tap'
brew 'git-duet'

cask '1Password'
cask 'bartender'
cask 'docker'
cask 'dropbox' unless work_machine?
cask 'firefox'
cask 'google-chrome'
cask 'iTerm2'
cask 'pastebot'
cask 'rectangle'
cask 'slack'
cask 'sublime-text'
cask 'apparition47/tap/mailtrackerblocker'
# cask 'zoomus'

# QuickLook plugins:
# - https://github.com/sindresorhus/quick-look-plugins
# - https://sourabhbajaj.com/mac-setup/Homebrew/Cask.html
cask 'betterzip'
cask 'qlcolorcode'
cask 'qlImageSize'
cask 'qlmarkdown'
cask 'qlstephen'
cask 'quicklook-csv'
cask 'quicklook-json'
cask 'suspicious-package'
fix_ql_plugins


brew 'mas'
mas 'Keynote',  id: 409183694
mas 'Numbers',  id: 409203825
mas 'Pages',    id: 409201541
mas 'Gestimer', id: 990588172
