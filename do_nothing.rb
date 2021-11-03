#!/usr/bin/ruby -w

context = {username: ARGV.fetch(0)}

def wait_for_enter
	print "Press Enter to continue:"
	STDIN.gets("\n")
end

class CreateSSHKeyPairStep
	def run(context)
		puts "Run:"
		puts "   ssh-keygen -t rsa -f ~/#{context[:username]}"
		wait_for_enter
	end
end

class GitCommitStep
	def run(context)
		puts "Copy ~/new_key.pub into the `user_keys` Git repository, then run:"
        puts "    git commit #{context[:username]}"
        puts "    git push"
        wait_for_enter
	end
end

procedure = [CreateSSHKeyPairStep.new, GitCommitStep.new]
procedure.map {|step| step.run(context) }
puts "Done."
