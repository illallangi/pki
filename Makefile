.PHONY: help
help:
	@echo "Usage: make [target]"

.PHONY: clean
clean:
	git clean -fdX

.bundler:
	mkdir -p .bundler

.PHONY: serve
serve: .bundler
	podman run -i -t --rm -p 4000:4000 -v $$(pwd):/opt/app -v $$(pwd)/.bundler/:/opt/bundler -e BUNDLE_PATH=/opt/bundler -w /opt/app docker.io/library/ruby:3.3.6 bash -c "bundle install && bundle exec jekyll serve --watch -H 0.0.0.0"
