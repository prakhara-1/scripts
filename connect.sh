#!/bin/bash

# Configuration file to store name-IP mappings
CONFIG_FILE="$HOME/.vm_mappings.conf"

# Ensure the configuration file exists, if not, create it
if [ ! -f "$CONFIG_FILE" ]; then
  touch "$CONFIG_FILE"
  echo "Created configuration file: $CONFIG_FILE"
fi

# Function to add or update a name-IP mapping
add_vm_mapping() {
  local name=$1
  local ip=$2
  # Update or add the name-IP mapping
  grep -q "^$name=" "$CONFIG_FILE" && sed -i '' "s/^$name=.*/$name=$ip/" "$CONFIG_FILE" || echo "$name=$ip" >> "$CONFIG_FILE"
  echo "Mapping saved: $name -> $ip"
}

# Function to get the IP for a given name
get_vm_ip() {
  local name=$1
  # Get the IP address associated with the name
  grep "^$name=" "$CONFIG_FILE" | cut -d '=' -f2
}

# Function to establish the SSH tunnel and copy the file
connect_to_server() {
  local server_ip=$1
  local user="root"
  local password="Cisco@123"
  local local_port=6443
  local remote_port=6443
  local remote_host="172.16.0.1"
  local remote_file="/etc/kubernetes/admin.conf"
  local local_file="$HOME/.kube/config"

  # Find and kill the process using the specified local port
  PID=$(lsof -ti:${local_port})
  if [ -n "$PID" ]; then
    kill -9 $PID
    echo "Closed existing SSH connection on port ${local_port}"
  else
    echo "No existing SSH connection found on port ${local_port}"
  fi

  # Copy the file from the server to the local machine
  sshpass -p "$password" scp ${user}@${server_ip}:${remote_file} ${local_file}

  # Check if the copy was successful
  if [ $? -eq 0 ]; then
    echo "File copied to ${local_file}"
  else
    echo "Failed to copy file"
    exit 1
  fi

  # Replace the string 172.16.0.1 with 127.0.0.1 in the copied file
  sed -i '' 's/172.16.0.1/127.0.0.1/g' ${local_file}

  # Run ssh command using sshpass with hardcoded password
  sshpass -p "$password" ssh -fNL ${local_port}:${remote_host}:${remote_port} ${user}@${server_ip}

  # Check if the command was successful
  if [ $? -eq 0 ]; then
    echo "SSH tunnel established on port ${local_port}"
  else
    echo "Failed to establish SSH tunnel"
  fi
}

# Main logic
if [ $# -eq 2 ]; then
  # If both name and IP are provided, save the mapping
  NAME=$1
  IP=$2
  add_vm_mapping $NAME $IP
  connect_to_server $IP
elif [ $# -eq 1 ]; then
  # If only the name is provided, retrieve the IP and connect
  NAME=$1
  IP=$(get_vm_ip $NAME)
  
  if [ -n "$IP" ]; then
    echo "Connecting to $NAME at $IP..."
    connect_to_server $IP
  else
    echo "No saved VM with the name '$NAME'"
    exit 1
  fi
else
  echo "Usage: $0 <name> [<ip>]"
  exit 1
fi
