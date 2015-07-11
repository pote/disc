
console:
	@irb -r ./lib/disc

test:
	@cutest -r ./test/*_test.rb #./test/*/*_test.rb

.PHONY: test
