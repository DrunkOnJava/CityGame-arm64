#!/bin/bash
# Test orchestrator communication system

echo "Testing orchestrator communication..."

# Test 1: Agent registration
echo "Test 1: Agent registration"
for i in {1..9}; do
    "$AGENTS_DIR/communicate.sh" "agent_$i" "REGISTER" "agent_0" "{\"name\":\"test_agent_$i\"}"
done

# Test 2: Task assignment
echo "Test 2: Task assignment"
"$AGENTS_DIR/communicate.sh" "agent_0" "TASK_ASSIGN" "agent_1" "{\"task_id\":\"001\",\"description\":\"Implement math library\"}"

# Test 3: Status update
echo "Test 3: Status update"
"$AGENTS_DIR/communicate.sh" "agent_1" "STATUS_UPDATE" "agent_0" "{\"task_id\":\"001\",\"progress\":0.25}"

# Test 4: Conflict detection
echo "Test 4: Conflict simulation"
"$AGENTS_DIR/communicate.sh" "agent_2" "RESOURCE_REQUEST" "agent_0" "{\"file\":\"src/main.c\",\"access\":\"write\"}"
"$AGENTS_DIR/communicate.sh" "agent_3" "RESOURCE_REQUEST" "agent_0" "{\"file\":\"src/main.c\",\"access\":\"write\"}"

echo "Orchestration tests complete"
