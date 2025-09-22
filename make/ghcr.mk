.PHONY:
clean-registry-untagged:
	@set -o errexit; \
	if test -z "$${GH_TOKEN}" && ! test -f "$${HOME}/.config/gh/hosts.yml"; then \
		echo "### Error: Need GH_TOKEN or configured gh."; \
		exit 1; \
	fi; \
	gh api --paginate users/$(OWNER)/packages?package_type=container \
	| jq --raw-output '.[].name' \
	| while read NAME; do \
		gh api --paginate "users/$(OWNER)/packages/container/$${NAME////%2F}/versions" \
		| jq --raw-output '.[] | select(.metadata.container.tags | length == 0) | .id' \
		| while read -r ID; do \
			echo "Removing package $${NAME} version ID $${ID}"; \
			gh api --method DELETE "users/$(OWNER)/packages/container/$${NAME////%2F}/versions/$${ID}"; \
		done; \
	done

.PHONY:
clean-registry-untagged--%:
	@set -o errexit; \
	if test -z "$${GH_TOKEN}" && ! test -f "$${HOME}/.config/gh/hosts.yml"; then \
		echo "### Error: Need GH_TOKEN or configured gh."; \
		exit 1; \
	fi; \
	NAME="uniget/$*"; \
	gh api --paginate "users/$(OWNER)/packages/container/$${NAME////%2F}/versions" \
	| jq --raw-output '.[] | select(.metadata.container.tags | length == 0) | .id' \
	| while read -r ID; do \
		echo "Removing package $${NAME} version ID $${ID}"; \
		gh api --method DELETE "users/$(OWNER)/packages/container/$${NAME////%2F}/versions/$${ID}" \; \
	done

.PHONY:
clean-ghcr-unused--%:
	@set -o errexit; \
	if test -z "$${GH_TOKEN}" && ! test -f "$${HOME}/.config/gh/hosts.yml"; then \
		echo "### Error: Need GH_TOKEN or configured gh."; \
		exit 1; \
	fi; \
	echo "Removing tag $*"; \
	gh api --paginate /users/$(OWNER)/packages?package_type=container | jq --raw-output '.[].name' \
	| while read NAME; do \
		gh api --paginate "users/$(OWNER)/packages/container/$${NAME////%2F}/versions" \
		| jq --raw-output --arg tag "$*" '.[] | select(.metadata.container.tags[] | contains($$tag)) | .id' \
		| while read -r ID; do \
			echo "Removing package $${NAME} tag $${ID}"; \
			gh api --method DELETE "users/$(OWNER)/packages/container/$${NAME////%2F}/versions/{}"; \
		done; \
	done

.PHONY:
ghcr-orphaned:
	@set -o errexit; \
	gh api --paginate /users/$(OWNER)/packages?package_type=container | jq --raw-output '.[].name' \
	| cut -d/ -f2 \
	| while read NAME; do \
		test "$${NAME}" == "base" && continue; \
		test "$${NAME}" == "metadata" && continue; \
		if ! test -f "$(TOOLS_DIR)/$${NAME}/manifest.yaml"; then \
			echo "Missing tool for $${NAME}"; \
			exit 1; \
		fi; \
	done

.PHONY:
ghcr-exists--%:
	@gh api --paginate "users/$(OWNER)/packages/container/uniget%2F$*" >/dev/null 2>&1

.PHONY:
ghcr-exists: \
		$(addprefix ghcr-exists--,$(TOOLS_RAW))

.PHONY:
ghcr-inspect:
	@set -o errexit; \
	gh api --paginate /users/$(OWNER)/packages?package_type=container | jq --raw-output '.[].name' \
	| while read NAME; do \
		echo "### Package $${NAME}"; \
		gh api --paginate "users/$(OWNER)/packages/container/$${NAME////%2F}/versions" \
		| jq --raw-output '.[].metadata.container.tags[]'; \
	done

.PHONY:
$(addsuffix --ghcr-tags,$(ALL_TOOLS_RAW)):%--ghcr-tags:
	@set -o errexit; \
	gh api --paginate "users/$(OWNER)/packages/container/uniget%2F$*/versions" \
	| jq --raw-output '.[] | "\(.metadata.container.tags[]);\(.name);\(.id)"' \
	| column --separator ";" --table --table-columns Tag,SHA256,ID

.PHONY:
$(addsuffix --ghcr-inspect,$(ALL_TOOLS_RAW)):%--ghcr-inspect:
	@set -o errexit; \
	gh api --paginate "users/$(OWNER)/packages/container/uniget%2F$*" \
	| yq --prettyPrint

.PHONY:
$(addsuffix --ghcr-delete-test,$(ALL_TOOLS_RAW)):%--ghcr-delete-test: ; $(info $(M) Removing tag test from tool $*...)
	@\
	gh api --paginate "users/$(OWNER)/packages/container/uniget%2F$*/versions" \
	| jq --raw-output '.[] | select(.metadata.container.tags[] | contains("test")) | .id' \
	| xargs -I{} \
		gh api --method DELETE "users/$(OWNER)/packages/container/uniget%2F$*/versions/{}"

.PHONY:
delete-ghcr--%:
	@set -o errexit; \
	if test -z "$${GH_TOKEN}" && ! test -f "$${HOME}/.config/gh/hosts.yml"; then \
		echo "### Error: Need GH_TOKEN or configured gh."; \
		exit 1; \
	fi; \
	PARAM=$*; \
	NAME="$${PARAM%%:*}"; \
	TAG="$${PARAM#*:}"; \
	echo "Removing $${NAME}:$${TAG}"; \
	gh api --paginate "users/$(OWNER)/packages/container/uniget%2F$${NAME}/versions" \
	| jq --raw-output --arg tag "$${TAG}" '.[] | select(.metadata.container.tags[] | contains($$tag)) | .id' \
	| xargs -I{} \
		gh api --method DELETE "users/$(OWNER)/packages/container/uniget%2F$${NAME}/versions/{}"

.PHONY:
ghcr-private:
	@set -o errexit; \
	gh api --paginate "users/$(OWNER)/packages?package_type=container&visibility=private" \
	| jq '.[] | "\(.name);\(.html_url)"' \
	| column --separator ";" --table --table-columns Name,Url

.PHONY:
$(addsuffix --ghcr-private,$(ALL_TOOLS_RAW)):%--ghcr-private: ; $(info $(M) Testing that $* is publicly visible...)
	@gh api "users/$(OWNER)/packages/container/uniget%2F$*" \
	| jq --exit-status 'select(.visibility == "public")' >/dev/null 2>&1
