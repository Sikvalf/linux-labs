FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        openssh-server \
        python3 \
        python3-apt \
        sudo \
        ca-certificates \
        supervisor && \
    mkdir -p /run/sshd /var/log/supervisor && \
    rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/bash ansible && \
    mkdir -p /home/ansible/.ssh && \
    chown -R ansible:ansible /home/ansible/.ssh && \
    chmod 700 /home/ansible/.ssh && \
    echo "ansible ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ansible && \
    chmod 440 /etc/sudoers.d/ansible

RUN printf '[supervisord]\nnodaemon=true\n\n[program:sshd]\ncommand=/usr/sbin/sshd -D\nautostart=true\nautorestart=true\n' \
    > /etc/supervisor/conf.d/sshd.conf

EXPOSE 22

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf"]
