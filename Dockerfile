FROM debian:11-slim
RUN apt-get update && \
	apt-get install -y ca-certificates python3 python3-venv && \
	apt-get -y autoremove && \
	adduser snek && \
	mkdir /app && \
	chown snek /app

WORKDIR /app
USER snek
COPY ./requirements.txt /app/requirements.txt
RUN python3 -m venv venv && \
	/app/venv/bin/pip install -U pip wheel && \
	/app/venv/bin/pip install -r /app/requirements.txt

USER root
COPY ./ca.crt /usr/local/share/ca-certificates/redpanda.crt
RUN update-ca-certificates
USER snek

COPY ./client.py /app/client.py

ENTRYPOINT ["/app/venv/bin/python3", "client.py"]
