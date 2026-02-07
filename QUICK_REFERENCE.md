# Quick Reference - Network Simulation

## Quick Commands

### Start Environment
```bash
docker compose up -d
```

### Apply Network Conditions
```bash
# Basic delay
./network-sim.sh -c cprowl-container1 -d 100ms

# Delay with jitter
./network-sim.sh -c cprowl-container1 -d 50ms -j 10ms

# Delay with packet loss
./network-sim.sh -c cprowl-container1 -d 50ms -l 5%

# All conditions
./network-sim.sh -c cprowl-container1 -d 100ms -j 20ms -l 3% -b 1mbit
```

### Test Network Conditions
```bash
# Quick ping test (get container IP first)
CONTAINER1_IP=$(docker exec cprowl-container1 hostname -i | tr -d ' \n')
docker exec cprowl-container2 ping -c 5 $CONTAINER1_IP

# Or run full test suite
./test-network.sh
```

### View Current Conditions
```bash
./network-sim.sh -c cprowl-container1 -a show
```

### Remove Conditions
```bash
./network-sim.sh -c cprowl-container1 -a remove
```

### Stop Environment
```bash
docker compose down
```

## Common Use Cases

### Simulate Poor WiFi
```bash
./network-sim.sh -c cprowl-container1 -d 50ms -j 20ms -l 2%
```

### Simulate 3G Mobile Network
```bash
./network-sim.sh -c cprowl-container1 -d 100ms -j 30ms -l 1% -b 2mbit
```

### Simulate Satellite Connection
```bash
./network-sim.sh -c cprowl-container1 -d 600ms -j 50ms
```

### Simulate Bidirectional Issues
```bash
./network-sim.sh -c cprowl-container1 -d 50ms -l 2%
./network-sim.sh -c cprowl-container2 -d 50ms -l 2%
```

## Parameters

- `-d DELAY`: Network delay (e.g., 100ms, 1s)
- `-j JITTER`: Delay variation (e.g., 10ms)
- `-l LOSS`: Packet loss percentage (e.g., 5%)
- `-b BANDWIDTH`: Bandwidth limit (e.g., 1mbit, 100kbit)
- `-i INTERFACE`: Network interface (default: eth0)
- `-a ACTION`: Action - add, remove, show (default: add)

## Tips

- Always test with ping after applying conditions to verify
- Remember to remove conditions when done testing
- Conditions are temporary and reset when containers restart
- Both containers can have different conditions applied simultaneously
