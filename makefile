deploy: public
	hugo --gc --minify
	git add public
	git commit -m "deploy: $(shell date)"
	git subtree push --prefix public origin gh-pages