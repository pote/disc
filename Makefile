
console:
	@irb -r ./lib/disque

test:
	@cutest -r ./tests/*_test.rb ./tests/*/*_test.rb
