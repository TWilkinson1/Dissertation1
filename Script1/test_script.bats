#!/usr/bin/env bats

setup() {
    echo "Setup: PWD=$(pwd)"
    source "${BATS_TEST_DIRNAME}/functions.sh" 2>/dev/null || true
    export TEST_DIR=$(mktemp -d)
    export SAVE_PATH="${TEST_DIR}/save"
    export DOCKER_PATH="${TEST_DIR}/docker"
    export K8_PATH="${TEST_DIR}/k8"
    export DOCKER_FILE="${TEST_DIR}/dockerfile"
    export FILE_POD="test-pod.yaml"
    export POD_NAME="test-pod"
    export IMAGE_NAME="test-image"
    export URL="https://example.com/archive.zip"

    mkdir -p "$SAVE_PATH" "$DOCKER_PATH" "$K8_PATH" "$DOCKER_FILE"
    echo "apiVersion: v1" > "$K8_PATH/$FILE_POD"
}

teardown() {
    cd "$BATS_TEST_DIRNAME" || cd /tmp ||
    rm -rf "$TEST_DIR"
}

@test "Valid URL passes check" {
    URL="https://github.com/user/repo"
    run check_url_regex
    [ "$status" -eq 0 ]
    [[ "$output" == *"is valid"* ]]
}

@test "Invalid URL fails check" {
    URL="invalid_url"
    run check_url_regex
    [ "$status" -eq 0 ]
    [[ "$output" == *"is not valid"* ]]
}

@test "Absolute path is valid" {
    SAVE_PATH="/tmp/test/path"
    run check_path_regex
    [ "$status" -eq 0 ]
    [[ "$output" == *"is valid"* ]]
}

@test "Relative path is invalid" {
    SAVE_PATH="relative/path"
    run check_path_regex
    [ "$status" -eq 1 ]
    [[ "$output" == *"invalid path"* ]]
}

@test "Creates missing SAVE_PATH" {
    SAVE_PATH="$TEST_DIR/new/path"
    run check_path_regex
    [ "$status" -eq 0 ]
    [ -d "$SAVE_PATH" ]
}

@test "private_download works with wget" {
    wget() { touch "$SAVE_PATH/test.zip"; return 0; }
    unzip() { return 0; }
    command() { [ "$2" = "wget" ] && return 0 || return 1; }
    export -f wget unzip command

    run private_download
    [ "$status" -eq 0 ]
}

@test "validate passes if SAVE_PATH exists" {
    run validate
    [ "$status" -eq 0 ]
    [[ "$output" == *"File Downloaded"* ]]
}

@test "Docker is running" {
    docker() {
        [ "$1" = "ps" ] && return 0
        [ "$1" = "build" ] && return 0
    }
    command() { return 0; }
    export -f docker command

    run docker_create
    [ "$status" -eq 0 ]
}

@test "Kubernetes pod is applied" {
    kubectl() {
        case "$1" in
            version|apply|describe) return 0;;
        esac
    }
    command() { return 0; }
    export -f kubectl command

    run Kubernetes_create
    [ "$status" -eq 0 ]
}

@test "Patch succeeds if pod exists" {
    kubectl() {
        [ "$1" = "get" ] && return 0
        [ "$1" = "patch" ] && return 0
    }
    command() { return 0; }
    export -f kubectl command

    run Kubernetes_patch
    [ "$status" -eq 0 ]
}

@test "Patch fails if pod not found" {
    kubectl() {
        [ "$1" = "get" ] && return 1
        [ "$1" = "delete" ] && return 0
    }
    command() { return 1; }
    export -f kubectl command

    run Kubernetes_patch
    [ "$status" -eq 1 ]
}