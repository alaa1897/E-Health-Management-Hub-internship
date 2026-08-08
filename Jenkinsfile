// Task 4 — CI/CD Pipeline: Jenkins + Nexus
//
// DEVIATION FROM BRIEF (documented per Piège 8's "choix d'architecture" note):
// The brief's original Jenkinsfile assumes `docker build`/`docker push` via a
// docker.sock mount (Piège 12, Option A). k8s-worker1/worker2 were confirmed
// (2026-08-08) to have neither `docker` nor `nerdctl` installed, only bare
// containerd, and both are RAM-constrained (<2Gi each). Rather than install a
// permanent dockerd on the hosts, image builds are delegated to short-lived
// Kaniko Jobs launched via `kubectl` (already required for the Deploy stage,
// reusing the same `kubeconfig` credential). Kaniko needs no daemon and only
// consumes resources while a build is actually running — a better fit for
// this cluster's resource budget. Build + push happen atomically inside each
// Kaniko Job, so there's no separate "Push to Nexus" stage like the brief's
// template.

pipeline {
    agent any

    environment {
        NEXUS_REGISTRY  = "nexus-service.cicd.svc.cluster.local:8082"
        BACKEND_IMAGE   = "ehealth-backend"
        FRONTEND_IMAGE  = "ehealth-frontend"
        // Piège 5 — value the BROWSER uses (resolves via /etc/hosts on the Mac),
        // not a cluster-internal address. Must exactly match what Task 3 baked in.
        REACT_APP_API_URL = "http://api.ehealth.local"
        GITHUB_URL      = "https://github.com/alaa1897/E-Health-Management-Hub-internship.git"
        // Kaniko's git-context syntax needs the git:// form with an explicit ref.
        KANIKO_CONTEXT  = "git://github.com/alaa1897/E-Health-Management-Hub-internship.git#refs/heads/main"
    }

    triggers {
        // Piège 8 — Jenkins isn't exposed to the internet, so GitHub can't webhook
        // it. Polling every minute is the documented workaround.
        pollSCM('* * * * *')
    }

    stages {
        stage('Checkout') {
            steps {
                // Repo is public, so credentialsId isn't strictly required for the
                // clone itself, but kept for consistency with Jenkins Credentials
                // setup (Piège 9) and in case the repo ever goes private.
                git credentialsId: 'github-credentials',
                    url: "${GITHUB_URL}",
                    branch: 'main'
            }
        }

        stage('Build & Push Backend (Kaniko)') {
            steps {
                withCredentials([file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG')]) {
                    sh '''
                        set -e
                        cat <<EOF > /tmp/kaniko-backend-${BUILD_NUMBER}.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: kaniko-backend-${BUILD_NUMBER}
  namespace: cicd
spec:
  backoffLimit: 0
  ttlSecondsAfterFinished: 300
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: kaniko
          image: gcr.io/kaniko-project/executor:latest
          args:
            - --context=${KANIKO_CONTEXT}
            - --context-sub-path=Backend
            - --destination=${NEXUS_REGISTRY}/${BACKEND_IMAGE}:${BUILD_NUMBER}
            - --destination=${NEXUS_REGISTRY}/${BACKEND_IMAGE}:latest
            - --insecure
            - --skip-tls-verify
            - --verbosity=info
          resources:
            requests:
              cpu: "250m"
              memory: "256Mi"
            limits:
              cpu: "1"
              memory: "768Mi"
          volumeMounts:
            - name: docker-config
              mountPath: /kaniko/.docker
      volumes:
        - name: docker-config
          secret:
            secretName: nexus-push-secret
            items:
              - key: .dockerconfigjson
                path: config.json
EOF
                        kubectl --kubeconfig=$KUBECONFIG apply -f /tmp/kaniko-backend-${BUILD_NUMBER}.yaml
                        kubectl --kubeconfig=$KUBECONFIG wait --for=condition=complete \
                            job/kaniko-backend-${BUILD_NUMBER} -n cicd --timeout=600s \
                        || { echo "--- Kaniko backend build failed, logs: ---"; \
                             kubectl --kubeconfig=$KUBECONFIG logs -n cicd job/kaniko-backend-${BUILD_NUMBER} --all-containers; \
                             exit 1; }
                    '''
                }
            }
        }

        stage('Build & Push Frontend (Kaniko)') {
            steps {
                withCredentials([file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG')]) {
                    sh '''
                        set -e
                        cat <<EOF > /tmp/kaniko-frontend-${BUILD_NUMBER}.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: kaniko-frontend-${BUILD_NUMBER}
  namespace: cicd
spec:
  backoffLimit: 0
  ttlSecondsAfterFinished: 300
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: kaniko
          image: gcr.io/kaniko-project/executor:latest
          args:
            - --context=${KANIKO_CONTEXT}
            - --context-sub-path=FrontEnd
            - --build-arg=REACT_APP_API_URL=${REACT_APP_API_URL}
            - --destination=${NEXUS_REGISTRY}/${FRONTEND_IMAGE}:${BUILD_NUMBER}
            - --destination=${NEXUS_REGISTRY}/${FRONTEND_IMAGE}:latest
            - --insecure
            - --skip-tls-verify
            - --verbosity=info
          resources:
            requests:
              cpu: "250m"
              memory: "256Mi"
            limits:
              cpu: "1"
              memory: "1Gi"
          volumeMounts:
            - name: docker-config
              mountPath: /kaniko/.docker
      volumes:
        - name: docker-config
          secret:
            secretName: nexus-push-secret
            items:
              - key: .dockerconfigjson
                path: config.json
EOF
                        kubectl --kubeconfig=$KUBECONFIG apply -f /tmp/kaniko-frontend-${BUILD_NUMBER}.yaml
                        kubectl --kubeconfig=$KUBECONFIG wait --for=condition=complete \
                            job/kaniko-frontend-${BUILD_NUMBER} -n cicd --timeout=600s \
                        || { echo "--- Kaniko frontend build failed, logs: ---"; \
                             kubectl --kubeconfig=$KUBECONFIG logs -n cicd job/kaniko-frontend-${BUILD_NUMBER} --all-containers; \
                             exit 1; }
                    '''
                }
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                withCredentials([file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG')]) {
                    sh '''
                        set -e
                        kubectl --kubeconfig=$KUBECONFIG set image deployment/backend \
                            backend=${NEXUS_REGISTRY}/${BACKEND_IMAGE}:${BUILD_NUMBER} \
                            -n ehealth

                        kubectl --kubeconfig=$KUBECONFIG set image deployment/frontend \
                            frontend=${NEXUS_REGISTRY}/${FRONTEND_IMAGE}:${BUILD_NUMBER} \
                            -n ehealth

                        kubectl --kubeconfig=$KUBECONFIG rollout status deployment/backend \
                            -n ehealth --timeout=180s
                        kubectl --kubeconfig=$KUBECONFIG rollout status deployment/frontend \
                            -n ehealth --timeout=180s
                    '''
                }
            }
        }
    }

    post {
        success {
            echo "Pipeline terminé — build ${BUILD_NUMBER} déployé sur Kubernetes"
        }
        failure {
            echo "Pipeline échoué — vérifier les logs ci-dessus"
        }
    }
}