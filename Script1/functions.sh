#!/bin/bash

# Function definitions only - no execution

function check_url_regex() {
    URL_CHECK_REGEX='(https?|ftp|file)://[-[:alnum:]\+&@#/%?=~_|!:,.;]*[-[:alnum:]\+&@#/%=~_|]'
    if [[ "$URL" =~ ${URL_CHECK_REGEX} ]]; then
        echo "$URL is valid."
    else
        echo "$URL is not valid."
    fi
}

function check_path_regex() {
    PATH_CHECK_REGEX='^(\/[^\/]*)+\/?$'
    if [[ "$SAVE_PATH" =~ ${PATH_CHECK_REGEX} ]]; then
        echo "$SAVE_PATH is valid"
        FOLDER=$(dirname "$SAVE_PATH")
        if [[ -d "$FOLDER" ]]; then
            echo "Folder $FOLDER exists"
        else
            echo "Folder $FOLDER doesn't exist, creating it"
            mkdir -p -v "$FOLDER"
            if [ -d "$FOLDER" ]; then
                echo "created $FOLDER"
            else
                echo "failed to create $FOLDER"
                exit 1
            fi
        fi
    else
        echo "$SAVE_PATH is an invalid path."
        exit 1
    fi
}

function private_download() {
    if [ "$(command -v wget)" ]; then
        echo "$URL wget installed, downloading using wget"
        cd "$SAVE_PATH" && wget -O download.zip "$URL"
        unzip download.zip || exit 1
    elif [ "$(command -v curl)" ]; then
        echo "curl installed, download using curl"
        cd "$SAVE_PATH" && curl -LO "$URL" || exit 1
        unzip "$(basename "$URL")" || exit 1
    else
        echo "Failed to find wget or curl"
        exit 1
    fi
}

function validate() {
    if [ -d "$SAVE_PATH" ]; then
        echo "File Downloaded."
    else
        echo "Failed to download"
        exit 1
    fi
}

function docker_create() {
    if command docker ps >/dev/null 2>&1; then
        echo "Docker is running"
        cd "$DOCKER_FILE" || exit 1
        docker build "$DOCKER_FILE" || exit 1
        docker build . -t "$IMAGE_NAME"
    else 
        echo "Docker is not running or not installed"
        exit 1
    fi
}

function Kubernetes_create() {
    if command kubectl version --output=yaml >/dev/null 2>&1; then
        echo "Kubernetes is installed"
        cd "$K8_PATH" || exit 1
        kubectl apply -f "$FILE_POD" 
        kubectl describe pod "$POD_NAME"
    else
        echo "Kubernetes pod or deployment not found"
        exit 1
    fi
}

function Kubernetes_patch() {
    if command kubectl get pods "$POD_NAME" >/dev/null 2>&1; then
        echo "Pod found" 
        cd "$K8_PATH" || exit 1
        kubectl patch pod "$POD_NAME" --type='json' -p='[{"op": "replace", "path": "/spec/containers/0/image", "value":"'"$IMAGE_NAME"'"}]'
        kubectl describe pod "$POD_NAME"
    else
        echo "Pod not found"
        kubectl delete pod "$POD_NAME" 2>/dev/null || kubectl delete deployment "$POD_NAME" 2>/dev/null || true
        echo "Pod deleted"
        exit 1
    fi
}
