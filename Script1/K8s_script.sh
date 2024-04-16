echo "please enter the repo location for Kubernetes"
read -r K8_PATH

echo "please enter file name for pod creation"
read -r FILE_POD


function Kubernetes_create() {
    if [ "$(command kubectl version --output=yaml)" ]; then
        echo "Kubernetes is installed"
        cd "$K8_PATH"
       kubectl apply -f "$FILE_POD"
    else
        echo "Kubernetes not found"
        exit 1
    fi

}

Kubernetes_create

echo "please provide the pod name to be patched"
read -r POD_NAME

echo "please provide patch file name"
read -r FILE_NAME


function Kubernetes_patch() {
    if [ "$(command kubectl get pods $POD_NAME)" ]; then
        echo "Pod found"
        cd "$K8_PATH"
        kubectl patch pod "$POD_NAME" --patch-file "$FILE_NAME"
    else
        echo "Pod not found"
        exit 1
    fi
}

Kubernetes_patch