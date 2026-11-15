FROM python:3.12-slim-bookworm

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        openssh-client \
        git \
        curl && \
    pip install --no-cache-dir ansible-core && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /workspace/ansible

CMD ["sleep", "infinity"]
