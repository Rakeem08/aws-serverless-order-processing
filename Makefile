.PHONY: test lint fmt-check

test:
	python -m pytest -q

lint:
	python -m ruff check src tests

fmt-check:
	terraform -chdir=infra/bootstrap fmt -check -recursive
	terraform -chdir=infra/platform fmt -check -recursive

