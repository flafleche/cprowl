#!/bin/bash

# Example scenarios for network simulation between containers
# This script demonstrates various real-world network conditions

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

CONTAINER1="cprowl-container1"
CONTAINER2="cprowl-container2"

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}Network Simulation Example Scenarios${NC}"
echo -e "${BLUE}================================================${NC}\n"

# Function to run scenario
run_scenario() {
    local scenario_name="$1"
    local description="$2"
    shift 2
    
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}Scenario: ${scenario_name}${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo -e "${YELLOW}${description}${NC}\n"
    
    # Execute the network simulation commands
    "$@"
    
    echo -e "\n${BLUE}Testing scenario...${NC}"
    docker exec ${CONTAINER2} ping -c 3 container1
    
    echo -e "\n${YELLOW}Press Enter to continue to next scenario (or Ctrl+C to exit)...${NC}"
    read
    
    # Clean up
    echo -e "${YELLOW}Cleaning up...${NC}"
    ./network-sim.sh -c ${CONTAINER1} -a remove
    ./network-sim.sh -c ${CONTAINER2} -a remove
    echo ""
}

# Check if containers are running
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER1}$"; then
    echo -e "${RED}Error: Containers not running. Starting them now...${NC}"
    docker-compose up -d
    sleep 5
fi

echo -e "${GREEN}Starting example scenarios...${NC}\n"

# Scenario 1: Good LAN connection
run_scenario \
    "Good LAN Connection" \
    "Low latency, no packet loss (baseline)" \
    echo "No network conditions applied"

# Scenario 2: Typical Internet connection
run_scenario \
    "Typical Internet Connection" \
    "30ms latency, 10ms jitter, minimal packet loss" \
    ./network-sim.sh -c ${CONTAINER1} -d 30ms -j 10ms -l 0.1%

# Scenario 3: Poor WiFi connection
run_scenario \
    "Poor WiFi Connection" \
    "50ms delay, 20ms jitter, 2% packet loss, 10Mbit bandwidth" \
    ./network-sim.sh -c ${CONTAINER1} -d 50ms -j 20ms -l 2% -b 10mbit

# Scenario 4: Mobile 3G Network
run_scenario \
    "Mobile 3G Network" \
    "100ms delay, 30ms jitter, 1% loss, 2Mbit bandwidth" \
    ./network-sim.sh -c ${CONTAINER1} -d 100ms -j 30ms -l 1% -b 2mbit

# Scenario 5: Mobile 4G Network
run_scenario \
    "Mobile 4G Network" \
    "50ms delay, 10ms jitter, 0.5% loss, 20Mbit bandwidth" \
    ./network-sim.sh -c ${CONTAINER1} -d 50ms -j 10ms -l 0.5% -b 20mbit

# Scenario 6: Satellite Connection
run_scenario \
    "Satellite Connection" \
    "600ms delay (high latency), 50ms jitter" \
    ./network-sim.sh -c ${CONTAINER1} -d 600ms -j 50ms

# Scenario 7: Congested Network
run_scenario \
    "Congested Network" \
    "Limited bandwidth with variable delay" \
    ./network-sim.sh -c ${CONTAINER1} -d 100ms -j 50ms -b 1mbit

# Scenario 8: Very lossy network
run_scenario \
    "Very Lossy Network" \
    "High packet loss (10%) with some delay" \
    ./network-sim.sh -c ${CONTAINER1} -d 50ms -l 10%

# Scenario 9: Bidirectional issues
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Scenario: Bidirectional Network Issues${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "${YELLOW}Both directions have delays and packet loss${NC}\n"

./network-sim.sh -c ${CONTAINER1} -d 50ms -l 2%
./network-sim.sh -c ${CONTAINER2} -d 50ms -l 2%

echo -e "\n${BLUE}Testing bidirectional scenario...${NC}"
echo -e "${YELLOW}Ping from container2 to container1:${NC}"
docker exec ${CONTAINER2} ping -c 3 container1

echo -e "\n${YELLOW}Ping from container1 to container2:${NC}"
docker exec ${CONTAINER1} ping -c 3 container2

echo -e "\n${YELLOW}Press Enter to finish...${NC}"
read

# Final cleanup
echo -e "${YELLOW}Final cleanup...${NC}"
./network-sim.sh -c ${CONTAINER1} -a remove
./network-sim.sh -c ${CONTAINER2} -a remove

echo -e "\n${GREEN}================================================${NC}"
echo -e "${GREEN}All scenarios completed!${NC}"
echo -e "${GREEN}================================================${NC}\n"

echo -e "${YELLOW}You can now:${NC}"
echo -e "  - Apply your own custom conditions using: ./network-sim.sh"
echo -e "  - Run the test suite: ./test-network.sh"
echo -e "  - Stop containers: docker-compose down\n"
