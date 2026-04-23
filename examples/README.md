# Kafkaesque Examples

This section contains practical examples demonstrating how to use `Kafkaesque`, implement different architectural patterns, create integration tests, and apply best practices. 

If you have suggestions for additional examples or feedback, please contact the Data Engineering Team & Staff Engineers.

## Table of Contents
- [Overview](#overview)
- [Available Examples](#available-examples)
- [Getting Started](#getting-started)
- [Contributing](#contributing)

## Overview

These examples showcase real-world usage patterns of the Kafkaesque library, including:
- **Dead Letter Queue (DLQ) patterns** for handling failed message processing
- **Consumer group management** with different architectural approaches
- **Integration testing strategies** using testcontainers
- **Error handling and retry mechanisms**
- **Monitoring and observability patterns**

## Available Examples

### Dead Letter Queue Examples

#### Basic Dead Letter Example

**Purpose**: Demonstrates the fundamental DLQ pattern using Kafkaesque Consumer with separated task-based consumer groups.

**Architecture**: Two-consumer pattern where failed messages are routed to a dedicated DLQ topic and processed by a separate consumer group.

[📖 View Example](./dead-letter-examples/basic_dead_letter_example/README.md)

**Key Features**:
- Main consumer with retry mechanism (2 retries)
- Dead letter queue for failed messages
- One-off consumer for DLQ processing with auto-shutdown
- Example integration tests using testcontainers

**Use Cases**:
- Message processing failures that cannot be automatically resolved
- Processing issues requiring manual intervention
- Audit trail for failed message processing

**Technical Details**:
- **Topics**: `ping-events`, `basic-dead-letter-example.ping-events.dead-letter`
- **Consumer Groups**: `basic-dead-letter-example` (main), `basic_dead_letter_example.ping_events.dead_letter_group` (DLQ)
- **Retry Strategy**: 2 retries before DLQ routing
- **Offset Strategy**: Latest for main consumer, earliest for DLQ consumer

#### Important Notes

##### Message Ordering
- DLQ patterns may affect message ordering within partitions
- Failed messages are processed separately from the main flow
- Consider ordering requirements when implementing DLQ strategies

##### Topic Management
- Each example uses dedicated topics to avoid conflicts
- DLQ topics follow naming convention: `{service}.{original_topic}.dead_letter`
- Topics should be created before running consumers

##### Error Handling
- Examples demonstrate different retry strategies
- Failed messages include original metadata for debugging
- DLQ consumers can implement different processing logic than main consumers

## Getting Started

### Prerequisites
- Elixir 1.14+
- Docker (for integration tests)
- Basic understanding of Kafka concepts

### Quick Start
1. Navigate to any example directory
2. Install dependencies: `mix deps.get`
3. Run tests: `mix test`
4. Follow the example-specific README for detailed instructions

### Common Patterns

All examples follow these conventions:
- **Umbrella applications** for proper separation of concerns
- **Integration tests** using testcontainers for realistic testing
- **Configuration-driven** setup for different environments
- **Comprehensive documentation** with troubleshooting guides

## Contributing

When adding new examples:

1. **Follow the established structure**:
   - Use umbrella applications
   - Separate consumer and core logic
   - Include comprehensive tests

2. **Documentation requirements**:
   - Complete README with setup instructions
   - Architecture diagrams (ASCII art preferred)
   - Troubleshooting section
   - AI-friendly formatting

3. **Testing standards**:
   - Integration tests using testcontainers
   - Clear test scenarios with Given/When/Then structure
   - Proper cleanup and resource management

4. **Code quality**:
   - Follow Elixir conventions
   - Include proper typespecs
   - Comprehensive error handling
