.PHONY: build run stop clean logs

IMAGE_NAME := elpan-postgres
CONTAINER_NAME := elpan-postgres-container
POSTGRES_PASSWORD := postgres

# Build a specific major version
build-%:
	@echo "Building PostgreSQL version $*..."
	@if [ ! -d "$*" ]; then echo "Error: Version directory $* not found"; exit 1; fi
	@if [ ! -f "$*/meta.yaml" ]; then echo "Error: meta.yaml not found in $* directory"; exit 1; fi
	@UPSTREAM_TAG=$$(yq-python '.upstream_tag' $*/meta.yaml) && \
	MAJOR_VERSION=$$(yq-python '.major_version' $*/meta.yaml) && \
	sed "s/{{ upstream_tag }}/$$UPSTREAM_TAG/g" Containerfile.template > $*/Containerfile && \
	sed -i "s/postgresql-[0-9]\+-postgis-3/postgresql-$$MAJOR_VERSION-postgis-3/g" $*/Containerfile && \
	sed -i "s/postgresql-[0-9]\+-postgis-3-scripts/postgresql-$$MAJOR_VERSION-postgis-3-scripts/g" $*/Containerfile && \
	podman build -t $(IMAGE_NAME):$$MAJOR_VERSION -t $(IMAGE_NAME):$$UPSTREAM_TAG -f $*/Containerfile .

# Build all versions
build-all:
	@for dir in */; do \
		if [ -f "$$dir/meta.yaml" ]; then \
			version=$${dir%/}; \
			$(MAKE) build-$$version; \
		fi \
	done

run-%:
	@MAJOR_VERSION=$$(yq-python '.major_version' $*/meta.yaml) && \
	podman run -d \
		--name $(CONTAINER_NAME)-$$MAJOR_VERSION \
		-e POSTGRES_PASSWORD=$(POSTGRES_PASSWORD) \
		-p 5432:5432 \
		$(IMAGE_NAME):$$MAJOR_VERSION

stop-%:
	@MAJOR_VERSION=$$(yq-python '.major_version' $*/meta.yaml) && \
	podman stop $(CONTAINER_NAME)-$$MAJOR_VERSION || true && \
	podman rm $(CONTAINER_NAME)-$$MAJOR_VERSION || true

clean-%:
	@MAJOR_VERSION=$$(yq-python '.major_version' $*/meta.yaml) && \
	UPSTREAM_TAG=$$(yq-python '.upstream_tag' $*/meta.yaml) && \
	podman rmi $(IMAGE_NAME):$$MAJOR_VERSION $(IMAGE_NAME):$$UPSTREAM_TAG || true

logs-%:
	@MAJOR_VERSION=$$(yq-python '.major_version' $*/meta.yaml) && \
	podman logs -f $(CONTAINER_NAME)-$$MAJOR_VERSION

rebuild-%: clean-% build-%
