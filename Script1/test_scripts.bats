#!/usr/bin/env bats

# BATS Unit Tests for Docker-Kubernetes Deployment Script
# Usage: bats test_script.bats

# Setup function - runs before each test
setup() {
    # Source the main script functions (assuming script is named main.sh)
    source "${BATS_TEST_DIRNAME}/script2.sh" 2>/dev/null || true
    
    # Create temporary test directories
    export TEST_DIR=$(mktemp -d)
    export TEST_SAVE_PATH="${TEST_DIR}/test_save"
    export TEST_DOCKER_PATH="${TEST_DIR}/test_docker"
    export TEST_K8_PATH="${TEST_DIR}/test_k8"
    
    # Mock variables for testing
    export URL="https://github.com/TWilkinson1/Docker_Diss/archive/refs/heads/main.zip"
    export SAVE_PATH="${TEST_SAVE_PATH}"
    export DOCKER_PATH="${TEST_DOCKER_PATH}"
    export IMAGE_NAME="test_image"
    export DOCKER_FILE="${TEST_DIR}/dockerfile_test"
    export K8_PATH="${TEST_K8_PATH}"
    export FILE_POD="test-pod.yaml"
    export POD_NAME="test-pod"
    
    # Create test directories
    mkdir -p "${TEST_SAVE_PATH}"
    mkdir -p "${TEST_DOCKER_PATH}"
    mkdir -p "${TEST_K8_PATH}"
    mkdir -p "${TEST_DIR}/dockerfile_test"
}

# Teardown function - runs after each test
teardown() {
    # Clean up temporary directories
    rm -rf "${TEST_DIR}" 2>/dev/null || true
}

# Test URL validation function
@test "check_url_regex: valid HTTP URL" {
    URL="https://github.com/user/repo.git"
    run check_url_regex
    [ "$status" -eq 0 ]
    [[ "$output" =~ "is valid" ]]
}

@test "check_url_regex: valid HTTPS URL" {
    URL="https://example.com/path/to/file.zip"
    run check_url_regex
    [ "$status" -eq 0 ]
    [[ "$output" =~ "is valid" ]]
}

@test "check_url_regex: valid FTP URL" {
    URL="ftp://ftp.example.com/file.tar.gz"
    run check_url_regex
    [ "$status" -eq 0 ]
    [[ "$output" =~ "is valid" ]]
}

@test "check_url_regex: invalid URL without protocol" {
    URL="github.com/user/repo"
    run check_url_regex
    [ "$status" -eq 0 ]
    [[ "$output" =~ "is not valid" ]]
}

@test "check_url_regex: invalid URL with spaces" {
    URL="https://example.com/path with spaces"
    run check_url_regex
    [ "$status" -eq 0 ]
    [[ "$output" =~ "is not valid" ]]
}

# Test path validation function
@test "check_path_regex: valid absolute path" {
    SAVE_PATH="/tmp/test/path"
    run check_path_regex
    [ "$status" -eq 0 ]
    [[ "$output" =~ "is valid" ]]
}

@test "check_path_regex: valid path with existing parent directory" {
    SAVE_PATH="${TEST_DIR}/existing/path"
    mkdir -p "${TEST_DIR}/existing"
    run check_path_regex
    [ "$status" -eq 0 ]
    [[ "$output" =~ "is valid" ]]
    [[ "$output" =~ "exists" ]]
}

@test "check_path_regex: invalid relative path" {
    SAVE_PATH="relative/path"
    run check_path_regex
    [ "$status" -eq 1 ]
    [[ "$output" =~ "is an invalid path" ]]
}

@test "check_path_regex: creates non-existing directory" {
    SAVE_PATH="${TEST_DIR}/new/nested/path"
    run check_path_regex
    [ "$status" -eq 0 ]
    [[ "$output" =~ "doesn't exist, creating it" ]]
    [ -d "${TEST_DIR}/new/nested" ]
}

# Test download function (mocked)
@test "private_download: wget available" {
    # Mock wget command
    wget() {
        echo "wget called with: $*"
        touch "${TEST_SAVE_PATH}/test.zip"
        return 0
    }
    
    unzip() {
        echo "unzip called with: $*"
        return 0
    }
    
    export -f wget unzip
    
    # Mock command check
    command() {
        if [[ "$2" == "wget" ]]; then
            return 0
        fi
        return 1
    }
    export -f command
    
    SAVE_PATH="${TEST_SAVE_PATH}"
    run private_download
    [ "$status" -eq 0 ]
    [[ "$output" =~ "wget installed" ]]
}

@test "private_download: curl available when wget not found" {
    # Mock curl command
    curl() {
        echo "curl called with: $*"
        touch "${TEST_SAVE_PATH}/test.zip"
        return 0
    }
    
    unzip() {
        echo "unzip called with: $*"
        return 0
    }
    
    export -f curl unzip
    
    # Mock command check to return false for wget, true for curl
    command() {
        if [[ "$2" == "wget" ]]; then
            return 1
        elif [[ "$2" == "curl" ]]; then
            return 0
        fi
        return 1
    }
    export -f command
    
    SAVE_PATH="${TEST_SAVE_PATH}"
    run private_download
    [ "$status" -eq 0 ]
    [[ "$output" =~ "curl installed" ]]
}

@test "private_download: neither wget nor curl available" {
    # Mock command check to return false for both
    command() {
        return 1
    }
    export -f command
    
    run private_download
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Failed to find wget or curl" ]]
}

# Test validation function
@test "validate: successful when directory exists" {
    SAVE_PATH="${TEST_SAVE_PATH}"
    run validate
    [ "$status" -eq 0 ]
    [[ "$output" =~ "File Downloaded" ]]
}

@test "validate: fails when directory doesn't exist" {
    SAVE_PATH="${TEST_DIR}/nonexistent"
    run validate
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Failed to download" ]]
}

# Test Docker functions (mocked)
@test "docker_create: Docker running successfully" {
    # Mock docker command
    docker() {
        if [[ "$1" == "ps" ]]; then
            echo "CONTAINER ID   IMAGE"
            return 0
        elif [[ "$1" == "build" ]]; then
            echo "Building Docker image..."
            return 0
        fi
    }
    
    # Mock command check
    command() {
        if [[ "$*" =~ "docker ps" ]]; then
            return 0
        fi
        return 1
    }
    
    export -f docker command
    
    DOCKER_FILE="${TEST_DIR}/dockerfile_test"
    IMAGE_NAME="test_image"
    
    run docker_create
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Docker is running" ]]
}

@test "docker_create: Docker not running" {
    # Mock command check to fail
    command() {
        return 1
    }
    export -f command
    
    run docker_create
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Docker is not running or not installed" ]]
}

# Test Kubernetes functions (mocked)
@test "Kubernetes_create: kubectl available and working" {
    # Mock kubectl command
    kubectl() {
        if [[ "$1" == "version" ]]; then
            echo "Client Version: v1.25.0"
            return 0
        elif [[ "$1" == "apply" ]]; then
            echo "pod/test-pod created"
            return 0
        elif [[ "$1" == "describe" ]]; then
            echo "Name: test-pod"
            return 0
        fi
    }
    
    # Mock command check
    command() {
        if [[ "$*" =~ "kubectl version" ]]; then
            return 0
        fi
        return 1
    }
    
    export -f kubectl command
    
    # Create mock pod file
    echo "apiVersion: v1" > "${TEST_K8_PATH}/${FILE_POD}"
    
    K8_PATH="${TEST_K8_PATH}"
    FILE_POD="test-pod.yaml"
    POD_NAME="test-pod"
    
    run Kubernetes_create
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Kubernetes is installed" ]]
}

@test "Kubernetes_create: kubectl not available" {
    # Mock command check to fail
    command() {
        return 1
    }
    export -f command
    
    run Kubernetes_create
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Kubernetes pod or deployment not found" ]]
}

@test "Kubernetes_patch: pod exists and patch successful" {
    # Mock kubectl command
    kubectl() {
        if [[ "$1" == "get" && "$2" == "pods" ]]; then
            echo "NAME       READY   STATUS    RESTARTS   AGE"
            echo "test-pod   1/1     Running   0          1m"
            return 0
        elif [[ "$1" == "patch" ]]; then
            echo "pod/test-pod patched"
            return 0
        elif [[ "$1" == "describe" ]]; then
            echo "Name: test-pod"
            echo "Image: my_image"
            return 0
        fi
    }
    
    # Mock command check
    command() {
        if [[ "$*" =~ "kubectl get pods" ]]; then
            return 0
        fi
        return 1
    }
    
    export -f kubectl command
    
    K8_PATH="${TEST_K8_PATH}"
    POD_NAME="test-pod"
    IMAGE_NAME="my_image"
    
    run Kubernetes_patch
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Pod found" ]]
    [[ "$output" =~ "patched" ]]
}

@test "Kubernetes_patch: pod not found, deletion attempted" {
    # Mock kubectl command
    kubectl() {
        if [[ "$1" == "get" && "$2" == "pods" ]]; then
            echo "No resources found"
            return 1
        elif [[ "$1" == "delete" ]]; then
            echo "pod/test-pod deleted"
            return 0
        fi
    }
    
    # Mock command check
    command() {
        if [[ "$*" =~ "kubectl get pods" ]]; then
            return 1
        fi
        return 1
    }
    
    export -f kubectl command
    
    POD_NAME="test-pod"
    
    run Kubernetes_patch
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Pod not found" ]]
    [[ "$output" =~ "Pod deleted" ]]
}

# Integration tests
@test "integration: full workflow with mocked commands" {
    # Mock all external commands
    wget() {
        touch "${SAVE_PATH}/test.zip"
        return 0
    }
    
    unzip() {
        mkdir -p "${DOCKER_PATH}"
        return 0
    }
    
    docker() {
        if [[ "$1" == "ps" ]]; then
            return 0
        elif [[ "$1" == "build" ]]; then
            return 0
        fi
    }
    
    kubectl() {
        if [[ "$1" == "version" ]]; then
            return 0
        elif [[ "$1" == "apply" ]]; then
            return 0
        elif [[ "$1" == "describe" ]]; then
            return 0
        elif [[ "$1" == "get" ]]; then
            return 0
        elif [[ "$1" == "patch" ]]; then
            return 0
        fi
    }
    
    command() {
        case "$2" in
            "wget"|"docker"|"kubectl") return 0 ;;
            *) return 1 ;;
        esac
    }
    
    export -f wget unzip docker kubectl command
    
    # Set up test environment
    URL="https://github.com/test/repo.zip"
    SAVE_PATH="${TEST_SAVE_PATH}"
    DOCKER_PATH="${TEST_DOCKER_PATH}"
    DOCKER_FILE="${TEST_DIR}/dockerfile_test"
    K8_PATH="${TEST_K8_PATH}"
    FILE_POD="test-pod.yaml"
    POD_NAME="test-pod"
    IMAGE_NAME="test_image"
    
    # Create mock files
    echo "apiVersion: v1" > "${K8_PATH}/${FILE_POD}"
    
    # Test URL validation
    run check_url_regex
    [ "$status" -eq 0 ]
    
    # Test path validation
    run check_path_regex
    [ "$status" -eq 0 ]
    
    # Test download
    run private_download
    [ "$status" -eq 0 ]
    
    # Test validation
    run validate
    [ "$status" -eq 0 ]
    
    # Test Docker
    run docker_create
    [ "$status" -eq 0 ]
    
    # Test Kubernetes create
    run Kubernetes_create
    [ "$status" -eq 0 ]
    
    # Test Kubernetes patch
    run Kubernetes_patch
    [ "$status" -eq 0 ]
}

# Edge case tests
@test "edge_case: empty URL" {
    URL=""
    run check_url_regex
    [ "$status" -eq 0 ]
    [[ "$output" =~ "is not valid" ]]
}

@test "edge_case: empty path" {
    SAVE_PATH=""
    run check_path_regex
    [ "$status" -eq 1 ]
    [[ "$output" =~ "is an invalid path" ]]
}

@test "edge_case: very long valid URL" {
    URL="https://example.com/$(printf 'a%.0s' {1..500})"
    run check_url_regex
    [ "$status" -eq 0 ]
    [[ "$output" =~ "is valid" ]]
}

@test "edge_case: path with special characters" {
    SAVE_PATH="${TEST_DIR}/test-path_with.special+chars"
    run check_path_regex
    [ "$status" -eq 0 ]
    [[ "$output" =~ "is valid" ]]
}