#!/bin/bash

# Network Simulation Script for Docker Containers
# This script uses tc (traffic control) to simulate various network conditions

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
CONTAINER_NAME=""
DELAY="0ms"
JITTER="0ms"
LOSS="0%"
BANDWIDTH=""
INTERFACE="eth0"
ACTION="add"

print_usage() {
    cat << EOF
Network Simulation Script - Simulate network conditions in Docker containers

Usage: $0 -c CONTAINER_NAME [-d DELAY] [-j JITTER] [-l LOSS] [-b BANDWIDTH] [-i INTERFACE] [-a ACTION]

Options:
    -c CONTAINER_NAME   Name of the container (required)
    -d DELAY           Network delay (e.g., 100ms, 1s) [default: 0ms]
    -j JITTER          Delay variation/jitter (e.g., 10ms) [default: 0ms]
    -l LOSS            Packet loss percentage (e.g., 5%) [default: 0%]
    -b BANDWIDTH       Bandwidth limit (e.g., 1mbit, 100kbit)
    -i INTERFACE       Network interface [default: eth0]
    -a ACTION          Action: add, remove, show [default: add]
    -h                 Show this help message

Examples:
    # Add 100ms delay to container1
    $0 -c cprowl-container1 -d 100ms

    # Add 50ms delay with 10ms jitter and 5% packet loss
    $0 -c cprowl-container1 -d 50ms -j 10ms -l 5%

    # Limit bandwidth to 1mbit with 200ms delay
    $0 -c cprowl-container1 -d 200ms -b 1mbit

    # Remove all network simulation rules
    $0 -c cprowl-container1 -a remove

    # Show current network simulation rules
    $0 -c cprowl-container1 -a show

EOF
}

# Parse command line arguments
while getopts "c:d:j:l:b:i:a:h" opt; do
    case $opt in
        c) CONTAINER_NAME="$OPTARG" ;;
        d) DELAY="$OPTARG" ;;
        j) JITTER="$OPTARG" ;;
        l) LOSS="$OPTARG" ;;
        b) BANDWIDTH="$OPTARG" ;;
        i) INTERFACE="$OPTARG" ;;
        a) ACTION="$OPTARG" ;;
        h) print_usage; exit 0 ;;
        *) print_usage; exit 1 ;;
    esac
done

# Validate required parameters
if [ -z "$CONTAINER_NAME" ]; then
    echo -e "${RED}Error: Container name is required${NC}"
    print_usage
    exit 1
fi

# Check if container exists
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo -e "${RED}Error: Container '${CONTAINER_NAME}' not found or not running${NC}"
    exit 1
fi

# Function to add network conditions
add_network_conditions() {
    echo -e "${GREEN}Adding network conditions to ${CONTAINER_NAME}...${NC}"
    
    # Remove existing tc rules first
    docker exec "$CONTAINER_NAME" tc qdisc del dev "$INTERFACE" root 2>/dev/null || true
    
    # Build tc command
    TC_CMD="tc qdisc add dev $INTERFACE root netem"
    
    # Add delay
    if [ "$DELAY" != "0ms" ]; then
        TC_CMD="$TC_CMD delay $DELAY"
        echo -e "  ${YELLOW}Delay: $DELAY${NC}"
    fi
    
    # Add jitter
    if [ "$JITTER" != "0ms" ]; then
        if [ "$DELAY" != "0ms" ]; then
            TC_CMD="$TC_CMD $JITTER"
            echo -e "  ${YELLOW}Jitter: $JITTER${NC}"
        else
            echo -e "  ${RED}Warning: Jitter requires delay to be set. Ignoring jitter.${NC}"
        fi
    fi
    
    # Add packet loss
    if [ "$LOSS" != "0%" ]; then
        TC_CMD="$TC_CMD loss $LOSS"
        echo -e "  ${YELLOW}Packet Loss: $LOSS${NC}"
    fi
    
    # Add bandwidth limit
    if [ -n "$BANDWIDTH" ]; then
        # For bandwidth limiting, we need to use tbf (token bucket filter)
        docker exec "$CONTAINER_NAME" tc qdisc del dev "$INTERFACE" root 2>/dev/null || true
        docker exec "$CONTAINER_NAME" tc qdisc add dev "$INTERFACE" root handle 1: tbf rate "$BANDWIDTH" burst 32kbit latency 400ms
        echo -e "  ${YELLOW}Bandwidth: $BANDWIDTH${NC}"
        
        # If we have delay/loss/jitter, add them as a child qdisc
        if [ "$DELAY" != "0ms" ] || [ "$LOSS" != "0%" ]; then
            NETEM_CMD="tc qdisc add dev $INTERFACE parent 1:1 handle 10: netem"
            if [ "$DELAY" != "0ms" ]; then
                NETEM_CMD="$NETEM_CMD delay $DELAY"
                if [ "$JITTER" != "0ms" ]; then
                    NETEM_CMD="$NETEM_CMD $JITTER"
                fi
            fi
            if [ "$LOSS" != "0%" ]; then
                NETEM_CMD="$NETEM_CMD loss $LOSS"
            fi
            docker exec "$CONTAINER_NAME" $NETEM_CMD
        fi
    else
        # Execute the tc command
        docker exec "$CONTAINER_NAME" $TC_CMD
    fi
    
    echo -e "${GREEN}Network conditions applied successfully!${NC}"
}

# Function to remove network conditions
remove_network_conditions() {
    echo -e "${GREEN}Removing network conditions from ${CONTAINER_NAME}...${NC}"
    docker exec "$CONTAINER_NAME" tc qdisc del dev "$INTERFACE" root 2>/dev/null || echo -e "${YELLOW}No tc rules found${NC}"
    echo -e "${GREEN}Network conditions removed successfully!${NC}"
}

# Function to show current network conditions
show_network_conditions() {
    echo -e "${GREEN}Current network conditions for ${CONTAINER_NAME}:${NC}"
    docker exec "$CONTAINER_NAME" tc qdisc show dev "$INTERFACE" || echo -e "${YELLOW}No tc rules found${NC}"
}

# Execute action
case "$ACTION" in
    add)
        add_network_conditions
        ;;
    remove)
        remove_network_conditions
        ;;
    show)
        show_network_conditions
        ;;
    *)
        echo -e "${RED}Error: Invalid action '$ACTION'. Use 'add', 'remove', or 'show'${NC}"
        exit 1
        ;;
esac
