.PHONY: net dor-check api-test web-test secret-scan

# One command to run the same checks CI runs.
net: dor-check api-test web-test

dor-check:
	@bash tools/dor-check/test_fixtures.sh

api-test:
	cd api && bundle exec rspec

web-test:
	cd web && npm test && npm run build

secret-scan:
	gitleaks detect --source . --log-opts=--all
