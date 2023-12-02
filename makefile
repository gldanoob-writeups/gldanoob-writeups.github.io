deploy:
	rm -rf public
	hugo --gc --minify
	cd public
	git init
	git add .
	git commit -m "deploy: $(shell date)"
	git remote add origin https://github.com/gldanoob-writeups/gldanoob-writeups.github.io.git
	git push --force origin gh-pages
	rm -rf .git
	cd ..