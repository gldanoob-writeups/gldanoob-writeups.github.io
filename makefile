deploy:
	rm -rf public
	hugo --gc --minify
	git add public
	git commit -m "deploy: $(shell date)"
	git push origin `git subtree split --prefix public master`:gh-pages --force