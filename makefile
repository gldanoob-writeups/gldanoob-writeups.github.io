deploy: public
	hugo --gc --minify
	git subtree push --prefix public origin gh-pages