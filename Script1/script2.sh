https://github.com/TWilkinson1/Dissertation1.git#!/bin/bash

URL="https://github.com/TWilkinson1/Docker_Diss/archive/refs/heads/main.zip"
SAVE_PATH="/users/Thomas.Wilkinson/desktop/test_code"
DOCKER_PATH="/users/Thomas.Wilkinson/desktop/test_code/main"
IMAGE_NAME="my_image"

current_time=$(date +"%H:%M:%S")
#echo "Current time: $current_time"

#echo "please enter URL"
#read -r URL

#echo "please enter save path"
#read -r SAVE_PATH

#echo "please enter Docker path"
#read -r DOCKER_PATH
#echo "please enter image name for new image"
#read -r IMAGE_NAME

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
        if [ -f "$FOLDER" ]; then
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

check_url_regex
check_path_regex

function private_download() {
    if [ "$(command -v wget)" ]; then
        echo "$URL wget installed, downloading using wget"
        cd "$SAVE_PATH" && wget "$SAVE_PATH" "$URL"
        unzip "$DOCKER_PATH" || exit 1
    elif [ "$(command -v curl)" ]; then
          echo "curl installed, download using curl"
          cd "$SAVE_PATH" && curl -LO "$URL" || exit 1
          unzip "$DOCKER_PATH" || exit 1
    else
        echo "Failed to find wget or curl"
        exit 1
    fi
}

private_download

function validate() {
  if [ -d "$SAVE_PATH" ]; then
      echo "File Downloaded."
  else
      echo "Failed to download"
      exit 1
  fi
 }

 validate

#echo "please enter file path to dockerfile"
#read -r "DOCKER_FILE"

DOCKER_FILE="/users/thomas.wilkinson/desktop/test_code/Docker_Diss-main"

function docker_create() {
    if [ "$(command docker ps)" ]; then
        echo "Docker is running"
        cd "$DOCKER_FILE" || exit 1
        /usr/local/bin/docker build "$DOCKER_FILE" || exit 1
        /usr/local/bin/docker build . -t "$IMAGE_NAME"
    else 
        echo "Docker is not running or not installed"
        exit 1
    fi
}

docker_create

#echo "please enter the repo location for Kubernetes"
#read -r K8_PATH

#echo "please enter file name for pod or deployment creation"
#read -r FILE_POD

#echo "please enter pod name to be patched"
#read -r POD_NAME


K8_PATH="/users/thomas.wilkinson/documents/dissertation/dissertation1/pods"
FILE_POD="pod.yaml" 
DEPLOYMENT_FILE="Deployment.yaml"
POD_NAME="test-pod"


function Kubernetes_create() {
    if [ "$(command kubectl version --output=yaml)" ]; then
        echo "Kubernetes is installed"
        cd "$K8_PATH" || exit 1
        kubectl apply -f "$FILE_POD" 
        kubectl describe pod "$POD_NAME"
    else
        echo "Kubernetes pod or deployment not found"
        exit 1
    fi

}

Kubernetes_create

IMAGE_NAME="my_image"


function Kubernetes_patch() {
    if [ "$(command kubectl get pods $POD_NAME)" ]; then
        echo "Pod found" 
        cd "$K8_PATH" || exit 1
        kubectl patch pod "$POD_NAME" --type='json' -p=' [{"op": "replace", "path": "/spec/containers/0/image", "value":"my_image"}]'
        kubectl describe pod "$POD_NAME"
    else
        echo "Pod not found"
        kubectl delete pod "$POD_NAME" || kubectl delete deployment "$POD_NAME"
        echo "Pod deleted"
        exit 1
    fi
}

Kubernetes_patch

current_time=$(date +"%H:%M:%S")
echo "Current time: $current_time"






 