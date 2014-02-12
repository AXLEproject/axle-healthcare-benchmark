# Installation instructions

## Configure RabbitMQ
Enable management plugin:

```bash
sudo rabbitmq-plugins enable rabbitmq_management
```

Browse to localhost:12345 (see `/etc/rabbitmq/rabbitmq.config`).

In web interface load broker configuration from json file (in project `config/rabbitmq_broker_definitions.json`) via Overview > Import.