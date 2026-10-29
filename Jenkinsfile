pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
    }

    parameters {
        string(
            name: 'IMAGE_TAG',
            defaultValue: '',
            description: 'Full 40-character Git commit SHA of an image already published to ECR'
        )
    }

    environment {
        AWS_REGION                = 'ap-south-1'
        AWS_ACCOUNT_ID            = '429965676677'
        ECR_REPOSITORY            = 'cloud-native-backend'
        EKS_CLUSTER_NAME          = 'cloud-native-devops-eks-cluster'
        K8S_NAMESPACE             = 'cloud-native'
        POSTGRES_ADMIN_SECRET_ID  = '/cloud-native-devops/postgresql/admin'
        POSTGRES_APP_SECRET_ID    = '/cloud-native-devops/postgresql/app'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Validate Input and Tools') {
            steps {
                script {
                    def tag = params.IMAGE_TAG?.trim()

                    if (!(tag ==~ /(?i)[0-9a-f]{40}/)) {
                        error('IMAGE_TAG must be a full 40-character Git commit SHA.')
                    }

                    env.IMAGE_TAG = tag
                }

                sh '''
                    set -eu

                    for cmd in aws kubectl helm jq curl; do
                        if ! command -v "$cmd" >/dev/null 2>&1; then
                            echo "ERROR: Required command is missing: $cmd"
                            exit 1
                        fi
                    done

                    echo "Required deployment tools are installed."
                    aws sts get-caller-identity
                '''
            }
        }

        stage('Verify ECR Image') {
            steps {
                sh '''
                    set -eu

                    aws ecr describe-images \
                      --region "$AWS_REGION" \
                      --repository-name "$ECR_REPOSITORY" \
                      --image-ids imageTag="$IMAGE_TAG" \
                      --query 'imageDetails[0].imageTags[0]' \
                      --output text

                    echo "Requested image tag exists in ECR."
                '''
            }
        }

        stage('Configure EKS Access') {
            steps {
                sh '''
                    set -eu

                    aws eks update-kubeconfig \
                      --region "$AWS_REGION" \
                      --name "$EKS_CLUSTER_NAME"

                    kubectl get pods --namespace "$K8S_NAMESPACE" >/dev/null
                '''
            }
        }

        stage('Check Cluster Prerequisites') {
            steps {
                echo 'Namespace and gp3 StorageClass must be bootstrapped by an administrative identity.'
            }
        }

        stage('Sync Database Secrets') {
            steps {
                sh '''
                    set +x
                    set -eu
                    umask 077

                    TMP_DIR="$(mktemp -d)"
                    trap 'rm -rf "$TMP_DIR"' EXIT

                    aws secretsmanager get-secret-value \
                      --region "$AWS_REGION" \
                      --secret-id "$POSTGRES_ADMIN_SECRET_ID" \
                      --query SecretString \
                      --output text \
                      | jq -er '.POSTGRES_PASSWORD | select(type == "string" and length > 0)' \
                      > "$TMP_DIR/admin-password"

                    aws secretsmanager get-secret-value \
                      --region "$AWS_REGION" \
                      --secret-id "$POSTGRES_APP_SECRET_ID" \
                      --query SecretString \
                      --output text \
                      | jq -er '.POSTGRES_PASSWORD | select(type == "string" and length > 0)' \
                      > "$TMP_DIR/app-password"

                    kubectl create secret generic postgres-admin-credentials \
                      --namespace "$K8S_NAMESPACE" \
                      --from-file=POSTGRES_PASSWORD="$TMP_DIR/admin-password" \
                      --dry-run=client -o yaml \
                      | kubectl apply -f -

                    kubectl create secret generic postgres-credentials \
                      --namespace "$K8S_NAMESPACE" \
                      --from-file=POSTGRES_PASSWORD="$TMP_DIR/app-password" \
                      --dry-run=client -o yaml \
                      | kubectl apply -f -

                    echo "Database Kubernetes Secrets were synchronised."
                '''
            }
        }

        stage('Deploy PostgreSQL') {
            steps {
                sh '''
                    set -eu

                    helm upgrade --install postgresql ./helm/postgresql \
                      --namespace "$K8S_NAMESPACE" \
                      --atomic \
                      --wait \
                      --timeout 5m
                '''
            }
        }

        stage('Deploy Backend') {
            steps {
                sh '''
                    set -eu

                    helm upgrade --install cloud-native-backend \
                      ./helm/cloud-native-backend \
                      --namespace "$K8S_NAMESPACE" \
                      --values ./helm/cloud-native-backend/values.yaml \
                      --values ./helm/cloud-native-backend/values-dev.yaml \
                      --set-string image.tag="$IMAGE_TAG" \
                      --atomic \
                      --wait \
                      --timeout 5m
                '''
            }
        }

        stage('Verify Deployment and Health') {
            steps {
                sh '''
                    set -eu

                    kubectl rollout status statefulset/postgresql \
                      --namespace "$K8S_NAMESPACE" \
                      --timeout=5m

                    kubectl rollout status deployment/cloud-native-backend \
                      --namespace "$K8S_NAMESPACE" \
                      --timeout=5m

                    kubectl get pods,services \
                      --namespace "$K8S_NAMESPACE"

                    kubectl port-forward \
                      --namespace "$K8S_NAMESPACE" \
                      service/cloud-native-backend 18080:80 \
                      >/tmp/cloud-native-port-forward.log 2>&1 &
                    PF_PID=$!
                    trap 'kill "$PF_PID" 2>/dev/null || true' EXIT

                    ready=0
                    for attempt in $(seq 1 30); do
                        if curl --silent --show-error --fail \
                          http://127.0.0.1:18080/health >/dev/null 2>&1 \
                          && curl --silent --show-error --fail \
                          http://127.0.0.1:18080/ready >/dev/null 2>&1; then
                            ready=1
                            break
                        fi
                        sleep 2
                    done

                    if [ "$ready" -ne 1 ]; then
                        echo "ERROR: Backend health/readiness check failed."
                        cat /tmp/cloud-native-port-forward.log || true
                        exit 1
                    fi

                    echo "Backend health and readiness checks passed."
                '''
            }
        }
    }

    post {
        success {
            echo 'Deployment completed successfully.'
        }
        failure {
            echo 'Deployment failed. Review the failed stage and Kubernetes/Helm events.'
        }
    }
}
