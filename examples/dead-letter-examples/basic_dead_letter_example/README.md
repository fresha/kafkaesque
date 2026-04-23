# Basic Dead Letter Queue Example

This repository demonstrates a Kafkaesque-based application that uses a Kafkaesque consumer with a dead letter queue (DLQ).
It listens for messages on a Kafka topic, handles any failures by sending the problematic messages to a dedicated DLQ topic, 
and then processes them later with a separate consumer group.

## Table of Contents
- [Quick Start](#quick-start)
- [Architecture Overview](#architecture-overview)
- [Configuration](#configuration)
- [Core Modules](#core-modules)
- [Message Flow](#message-flow)
- [Running Tests](#running-tests)
- [Troubleshooting](#troubleshooting)

## Quick Start

### Prerequisites
- Elixir 1.14+
- Docker (for running tests with Kafka)
- Mix dependencies installed

### Setup
1. Install dependencies:
```bash
mix deps.get
```

2. Run the integration tests to verify everything works:
```bash
mix test
```

3. For manual testing, ensure you have a Kafka cluster running and update the configuration accordingly.

## Architecture Overview

This example implements a **two-consumer pattern** for robust dead letter queue handling:

```
[Kafka Topic: ping-events] 
         ↓ (consume)
[Main Consumer (WithDLQEventsConsumer)]
         ↓ (on failure after retries)
[DLQ Topic: basic-dead-letter-example.ping-events.dead-letter]
         ↓ (consume)
[DLQ Consumer (OneOffConsumer)]
```

### Consumer Types
- **Main Consumer**: Processes incoming messages with retry logic
- **DLQ Consumer**: One-off consumer that processes failed messages and auto-shuts down when idle

## Configuration

### Topic Configuration
The example uses standardized topic naming:
- **Main Topic**: `ping-events`
- **DLQ Topic**: `basic-dead-letter-example.ping-events.dead-letter`

### Consumer Configuration

```elixir
# Main Consumer Configuration
use Kafkaesque.Consumer,
  commit_strategy: :sync,
  consumer_group_identifier: "basic-dead-letter-example",
  topics_config: %{
    "ping-events" => %{
      decoder_config: {nil, []},
      dead_letter_producer: {
        Kafkaesque.DeadLetterQueue.KafkaTopicProducer,
        topic: "basic-dead-letter-example.ping-events.dead-letter", 
        worker_name: :my_worker
      }
    }
  },
  retries: 2

# DLQ Consumer Configuration  
use Kafkaesque.OneOffConsumer,
  consumer_group_identifier: "basic_dead_letter_example.ping_events.dead_letter_group",
  topics: ["basic-dead-letter-example.ping-events.dead-letter"],
  decoders: %{
    "basic-dead-letter-example.ping-events.dead-letter" => %{decoder: nil, opts: []}
  },
  max_idle_time: 5
```

## Core Modules

### Dead Letter Example Core

This is the core module in the umbrella application, where all domain-specific logic should reside.

### Dead Letter Example Consumer

This module handles all Kafka-related logic. 
Each consumer group should have its own domain-oriented supervisor and a unique name. 
This approach simplifies decoupling consumer groups for different releases and provides better control 
over resource usage and scalability.

## Message Flow

### Successful Processing
1. Message arrives on `ping-events`
2. Main consumer processes message successfully
3. Message offset is committed

### Failed Processing (DLQ Flow)
1. Message arrives on `ping-events`
2. Main consumer fails to process message
3. Consumer retries up to 2 times
4. After final retry failure, message is sent to DLQ topic
5. DLQ consumer picks up the message from DLQ topic
6. DLQ consumer processes the message (with different logic if needed)
7. DLQ consumer auto-shuts down after `max_idle_time` when no more messages

### Business Logic
The example implements simple string matching logic:
- **Valid messages**: Must start with "hello" (e.g., "hello world")
- **Invalid messages**: Any other format will trigger DLQ flow

## Running Tests

This application includes comprehensive integration tests using testcontainers:

```bash
# Run all tests
mix test

# Run with verbose output
mix test --trace

# Run specific test
mix test test/dead_letter_example_consumer_test.exs
```

The integration test demonstrates the complete DLQ workflow:
1. Sets up Kafka using testcontainers
2. Creates main and DLQ topics
3. Publishes an invalid message
4. Verifies main consumer fails and sends to DLQ
5. Starts DLQ consumer and verifies successful processing

## Troubleshooting

### Common Issues

#### "Topic does not exist" errors
**Solution**: Ensure topics are created before starting consumers:
```bash
# Create main topic
kafka-topics --create --topic ping-events --bootstrap-server localhost:9092

# Create DLQ topic  
kafka-topics --create --topic basic-dead-letter-example.ping-events.dead-letter --bootstrap-server localhost:9092
```

#### Consumer group rebalancing issues
**Solution**: Ensure unique consumer group identifiers and proper shutdown handling.

#### Messages not being processed from DLQ
**Solution**: 
- Check DLQ consumer is configured to start from `:earliest` offset

#### Integration tests failing
**Solution**:
- Ensure Docker is running
- Check no other processes are using Kafka ports
- Increase sleep timers if running on slower machines
