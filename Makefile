# 8x-hack — common tasks. Run from the repo root.
.DEFAULT_GOAL := help
.PHONY: help setup app-run app-test app-fix db-start db-stop db-reset db-diff db-types check clean

help: ## Show this help
	@grep -hE '^[a-z-]+:.*?## ' $(MAKEFILE_LIST) | awk -F':.*?## ' '{printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

setup: ## First-time setup on a fresh clone
	git lfs install --local
	git lfs pull
	cd app && flutter pub get
	@test -f app/dart_define.json || cp app/dart_define.example.json app/dart_define.json
	@echo
	@echo "Next: fill in app/dart_define.json, then 'make db-start' and 'make app-run'."

app-run: ## Run the Flutter app against your configured Supabase
	cd app && flutter run --dart-define-from-file=dart_define.json

app-test: ## Analyze + test the Flutter app
	cd app && flutter analyze && flutter test

app-fix: ## Auto-format and apply mechanical Dart fixes
	cd app && dart format . && dart fix --apply

db-start: ## Start the local Supabase stack (needs Docker)
	supabase start

db-stop: ## Stop the local Supabase stack
	supabase stop

db-reset: ## Recreate the local DB from migrations + seed.sql
	supabase db reset

db-diff: ## Capture local schema changes as a new migration: make db-diff NAME=add_posts
	@test -n "$(NAME)" || (echo "usage: make db-diff NAME=<snake_case_name>" && exit 1)
	supabase db diff -f $(NAME)

db-types: ## Regenerate Dart-side type reference from the local schema
	supabase gen types typescript --local > supabase/types.gen.ts

check: app-test ## Analyze + test (no Docker needed)

clean: ## Remove build output
	cd app && flutter clean
