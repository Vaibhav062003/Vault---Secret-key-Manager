FROM hashicorp/vault:latest

USER root

# Build the startup binary directly on Linux during docker build (100% immune to host/OS line-ending quirks)
RUN echo '#!/bin/sh' > /usr/local/bin/server && \
    echo 'set -e' >> /usr/local/bin/server && \
    echo 'printf "%s\n" "$VAULT_LOCAL_CONFIG" > /tmp/vault.json' >> /usr/local/bin/server && \
    echo 'echo "=== Starting Vault Server ==="' >> /usr/local/bin/server && \
    echo 'cat /tmp/vault.json' >> /usr/local/bin/server && \
    echo 'echo "============================="' >> /usr/local/bin/server && \
    echo 'exec vault server -config=/tmp/vault.json' >> /usr/local/bin/server && \
    chmod 755 /usr/local/bin/server && \
    ln -s /usr/local/bin/server /bin/server 2>/dev/null || true

EXPOSE 8200

# Clear entrypoint to bypass setcap restrictions
ENTRYPOINT []

# Default command
CMD ["/usr/local/bin/server"]
