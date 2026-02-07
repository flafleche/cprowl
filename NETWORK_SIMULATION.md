# Network Simulation Between Docker Containers

This guide explains how to simulate various network conditions (delay, packet loss, jitter, bandwidth limits) between Docker containers on the same machine.

## Overview

The network simulation setup consists of:
- **docker-compose.yml**: Defines two Docker containers on the same network
- **network-sim.sh**: A script to apply network conditions using Linux traffic control (tc)
- **test-network.sh**: A helper script to test network conditions between containers

## Requirements

- Docker and Docker Compose installed
- Linux host (tc command requires Linux kernel features)
- Root/sudo privileges (required for tc operations)

## Quick Start

### 1. Start the Containers

```bash
docker-compose up -d
```

This will start two Alpine Linux containers with network tools installed:
- `cprowl-container1`: Acts as server/receiver
- `cprowl-container2`: Acts as client/sender

### 2. Apply Network Conditions

Make the script executable:
```bash
chmod +x network-sim.sh
```

#### Add 100ms network delay to container1:
```bash
./network-sim.sh -c cprowl-container1 -d 100ms
```

#### Add delay with jitter and packet loss:
```bash
./network-sim.sh -c cprowl-container1 -d 50ms -j 10ms -l 5%
```

#### Limit bandwidth to 1 Mbit/s:
```bash
./network-sim.sh -c cprowl-container1 -b 1mbit
```

#### Combine bandwidth limit with delay:
```bash
./network-sim.sh -c cprowl-container1 -d 200ms -b 1mbit
```

### 3. Test the Network Conditions

Use the test script to verify network conditions:
```bash
chmod +x test-network.sh
./test-network.sh
```

Or manually test:

#### Test with ping:
```bash
docker exec cprowl-container2 ping -c 5 container1
```

#### Test with curl:
```bash
docker exec cprowl-container1 sh -c "echo 'Hello from container1' | nc -l -p 8080" &
docker exec cprowl-container2 curl http://container1:8080
```

#### Test with iperf3 (bandwidth test):
```bash
# Start iperf3 server on container1
docker exec -d cprowl-container1 iperf3 -s

# Run client on container2
docker exec cprowl-container2 iperf3 -c container1 -t 10
```

### 4. View Current Network Conditions

```bash
./network-sim.sh -c cprowl-container1 -a show
```

### 5. Remove Network Conditions

```bash
./network-sim.sh -c cprowl-container1 -a remove
```

### 6. Stop the Containers

```bash
docker-compose down
```

## Network Simulation Parameters

### Delay
Adds latency to network packets:
- `-d 50ms`: 50 milliseconds delay
- `-d 1s`: 1 second delay
- `-d 500ms`: 500 milliseconds delay

### Jitter
Adds variation to the delay (requires delay to be set):
- `-j 10ms`: ±10ms variation in delay
- Creates more realistic network conditions

### Packet Loss
Simulates packet loss percentage:
- `-l 5%`: 5% of packets will be dropped
- `-l 10%`: 10% packet loss
- `-l 0.5%`: 0.5% packet loss

### Bandwidth Limiting
Limits the available bandwidth:
- `-b 1mbit`: 1 Megabit per second
- `-b 100kbit`: 100 Kilobits per second
- `-b 10mbit`: 10 Megabits per second

## Use Cases

### 1. Simulating Slow Network
```bash
./network-sim.sh -c cprowl-container1 -d 200ms -j 50ms -b 1mbit
```
Simulates a slow, unreliable connection with 200ms base delay, 50ms jitter, and 1Mbit bandwidth.

### 2. Simulating Mobile Network (3G)
```bash
./network-sim.sh -c cprowl-container1 -d 100ms -j 30ms -l 1% -b 2mbit
```
Typical 3G characteristics: 100ms delay, 30ms jitter, 1% loss, 2Mbit bandwidth.

### 3. Simulating Satellite Connection
```bash
./network-sim.sh -c cprowl-container1 -d 600ms -j 50ms -l 0.5%
```
High latency satellite link: 600ms delay with jitter.

### 4. Simulating Lossy Network
```bash
./network-sim.sh -c cprowl-container1 -l 10%
```
10% packet loss, useful for testing retry logic.

### 5. Simulating Both Directions
Apply conditions to both containers to simulate bidirectional network issues:
```bash
./network-sim.sh -c cprowl-container1 -d 50ms -l 2%
./network-sim.sh -c cprowl-container2 -d 50ms -l 2%
```

## How It Works

The solution uses Linux Traffic Control (`tc`) with the Network Emulator (`netem`) kernel module:

1. **Privileged Mode**: Containers run with `NET_ADMIN` capability to allow tc operations
2. **TC Command**: The `tc qdisc` command manipulates the network queue discipline
3. **Netem**: Network emulator that can delay, drop, duplicate, reorder, and corrupt packets
4. **Per-Interface**: Network conditions are applied per network interface (default: eth0)

## Troubleshooting

### Container not found
Ensure containers are running:
```bash
docker-compose ps
```

### Permission denied
The script needs to run tc commands which require privileges. Containers are configured with `NET_ADMIN` capability.

### Changes don't persist
Network conditions are temporary and will be reset when containers restart. This is intentional for testing purposes.

### Testing from host machine
To test from the host to a container, you'll need to apply tc rules on the host's network interface or inside the container's network namespace.

## Advanced Usage

### Apply to specific network interface
```bash
./network-sim.sh -c cprowl-container1 -d 100ms -i eth1
```

### Chain multiple conditions
You can apply different conditions by using tc's hierarchical structure:
```bash
docker exec cprowl-container1 tc qdisc add dev eth0 root handle 1: tbf rate 1mbit burst 32kbit latency 400ms
docker exec cprowl-container1 tc qdisc add dev eth0 parent 1:1 handle 10: netem delay 100ms loss 5%
```

## References

- [Linux Traffic Control HOWTO](https://tldp.org/HOWTO/Traffic-Control-HOWTO/)
- [NetEm - Network Emulator](https://wiki.linuxfoundation.org/networking/netem)
- [Docker Networking](https://docs.docker.com/network/)
