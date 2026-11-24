FROM hashicorp/vault:latest

# Switch to root to copy entrypoint and set permissions
USER root

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 8200

ENTRYPOINT ["/entrypoint.sh"]
