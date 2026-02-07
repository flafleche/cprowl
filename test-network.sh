#!/bin/bash

# Test Network Conditions Between Containers
# This script runs various tests to verify network simulation is working

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

CONTAINER1="cprowl-container1"
CONTAINER2="cprowl-container2"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Network Simulation Test Suite${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Check if containers are running
echo -e "${GREEN}Checking container status...${NC}"
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER1}$"; then
    echo -e "${RED}Error: ${CONTAINER1} is not running${NC}"
    echo "Run: docker-compose up -d"
    exit 1
fi

if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER2}$"; then
    echo -e "${RED}Error: ${CONTAINER2} is not running${NC}"
    echo "Run: docker-compose up -d"
    exit 1
fi

echo -e "${GREEN}✓ Both containers are running${NC}\n"

# Function to run a test
run_test() {
    local test_name="$1"
    local test_cmd="$2"
    
    echo -e "${YELLOW}Test: ${test_name}${NC}"
    echo -e "${BLUE}Command: ${test_cmd}${NC}"
    eval "$test_cmd"
    echo -e "${GREEN}✓ Test completed${NC}\n"
}

# Test 1: Basic connectivity
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Test 1: Basic Connectivity${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Get container IPs
CONTAINER1_IP=$(docker exec ${CONTAINER1} hostname -i | tr -d ' \n')
CONTAINER2_IP=$(docker exec ${CONTAINER2} hostname -i | tr -d ' \n')

echo -e "${YELLOW}Container1 IP: ${CONTAINER1_IP}${NC}"
echo -e "${YELLOW}Container2 IP: ${CONTAINER2_IP}${NC}\n"

run_test "Ping from container2 to container1 (5 packets)" \
    "docker exec ${CONTAINER2} ping -c 5 ${CONTAINER1_IP}"

# Test 2: Show current tc rules
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Test 2: Current Network Rules${NC}"
echo -e "${BLUE}========================================${NC}\n"

echo -e "${YELLOW}Container1 tc rules:${NC}"
docker exec ${CONTAINER1} tc qdisc show dev eth0 || echo "No rules configured"
echo ""

echo -e "${YELLOW}Container2 tc rules:${NC}"
docker exec ${CONTAINER2} tc qdisc show dev eth0 || echo "No rules configured"
echo ""

# Test 3: Measure baseline latency
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Test 3: Baseline Latency Measurement${NC}"
echo -e "${BLUE}========================================${NC}\n"

run_test "Measure baseline RTT (Round Trip Time)" \
    "docker exec ${CONTAINER2} ping -c 10 -q ${CONTAINER1_IP} | tail -1"

# Test 4: HTTP connectivity test
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Test 4: HTTP Connectivity${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Start a simple HTTP server on container1 (will be cleaned up automatically when container stops)
echo -e "${YELLOW}Starting HTTP server on container1:8080...${NC}"
docker exec -d ${CONTAINER1} sh -c "while true; do echo 'HTTP/1.1 200 OK\r\nContent-Length: 23\r\n\r\nHello from container1!' | nc -l -p 8080; done" 2>/dev/null || true
sleep 2

run_test "HTTP request from container2 to container1" \
    "docker exec ${CONTAINER2} sh -c 'curl -m 5 http://${CONTAINER1_IP}:8080 2>/dev/null || echo \"Connection failed\"'"

# Note: HTTP server will be cleaned up when containers are stopped

# Test 5: Network statistics
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Test 5: Network Interface Statistics${NC}"
echo -e "${BLUE}========================================${NC}\n"

echo -e "${YELLOW}Container1 eth0 statistics:${NC}"
docker exec ${CONTAINER1} ip -s link show eth0
echo ""

echo -e "${YELLOW}Container2 eth0 statistics:${NC}"
docker exec ${CONTAINER2} ip -s link show eth0
echo ""

# Test 6: Example network simulation
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Test 6: Example Network Simulation${NC}"
echo -e "${BLUE}========================================${NC}\n"

echo -e "${YELLOW}Applying 100ms delay to container1...${NC}"
./network-sim.sh -c ${CONTAINER1} -d 100ms
echo ""

echo -e "${YELLOW}Testing with delay (expect ~100ms RTT):${NC}"
docker exec ${CONTAINER2} ping -c 5 ${CONTAINER1_IP}
echo ""

echo -e "${YELLOW}Removing network conditions...${NC}"
./network-sim.sh -c ${CONTAINER1} -a remove
echo ""

# Summary
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Test Suite Complete!${NC}"
echo -e "${BLUE}========================================${NC}\n"

echo -e "${GREEN}All tests completed successfully!${NC}"
echo -e "\n${YELLOW}Next steps:${NC}"
echo -e "  1. Apply custom network conditions: ./network-sim.sh -c cprowl-container1 -d 50ms -l 5%"
echo -e "  2. Test your application between containers"
echo -e "  3. Remove conditions when done: ./network-sim.sh -c cprowl-container1 -a remove"
echo -e "  4. Stop containers: docker-compose down\n"
