// Task 5 — SonarQube + Trivy in the Jenkins pipeline.
//
// Builds directly on Task 4's Jenkinsfile (Kaniko-via-kubectl-Job, no Docker
// socket anywhere on the cluster). Same deviation rationale applies here for
// every new stage: no dockerd/nerdctl on the workers, so anything that used
// to be "docker run some-tool" is either (a) a native binary installed into
// the Jenkins pod via initContainer (see k8s/cicd/jenkins-deployment.yaml —
// this is how sonar-scanner and node/npm are available below), or (b) a
// short-lived Kubernetes Job launched the same way Kaniko already is.
//
// Mentor's imposed order (all 10 stages present, same names/order):
//   1 Checkout  2 Build Frontend  3 Build Backend  4 SonarQube Analysis
//   5 Quality Gate  6 Build Docker Images  7 Security Scan (Trivy)
//   8 Push Validated Images  9 Deploy to Kubernetes  10 Verify Application
//
// Piège 4 decision: OPTION C (staging tag). Kaniko pushes each image to
// ":staging-${BUILD_NUMBER}" only. Trivy scans that tag straight from Nexus.
// If it passes, a `crane` Job re-points ":${BUILD_NUMBER}" and ":latest" at
// the same manifest server-side (no rebuild, no re-upload of layers) — this
// avoids the shared-tarball-volume plumbing Option A would need between two
// separate ephemeral Job pods, and matches how Task 4 already pushes.
//
// SonarQube Quality Gate note (not covered by the brief): `waitForQualityGate`
// needs SonarQube to call back to Jenkins. Configure a webhook in SonarQube
// (Administration → Configuration → Webhooks) pointing at
// http://jenkins-service.cicd.svc.cluster.local:8080/sonarqube-webhook/
// (trailing slash required) BEFORE running this pipeline for the first time,
// or the Quality Gate stage will likely hang until the 5-minute timeout even
// on a project that actually passed — this is almost certainly what Piège 5
// is actually describing.

def waitForJobCompletion(String jobName, String namespace, int maxIterations) {
    sh """
        set -e
        JOB=${jobName}
        NS=${namespace}
        i=0
        while [ \$i -lt ${maxIterations} ]; do
            COMPLETE=\$(kubectl --kubeconfig=\$KUBECONFIG get job/\$JOB -n \$NS -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}' 2>/dev/null)
            FAILED=\$(kubectl --kubeconfig=\$KUBECONFIG get job/\$JOB -n \$NS -o jsonpath='{.status.conditions[?(@.type=="Failed")].status}' 2>/dev/null)
            if [ "\$COMPLETE" = "True" ]; then
                echo ">>> Job \$JOB succeeded."
                kubectl --kubeconfig=\$KUBECONFIG logs -n \$NS job/\$JOB --all-containers || true
                exit 0
            fi
            if [ "\$FAILED" = "True" ]; then
                echo "--- Job \$JOB FAILED, logs: ---"
                kubectl --kubeconfig=\$KUBECONFIG logs -n \$NS job/\$JOB --all-containers
                exit 1
            fi
            sleep 10
            i=\$((i+1))
        done
        echo "--- Job \$JOB timed out after ${maxIterations * 10}s, logs: ---"
        kubectl --kubeconfig=\$KUBECONFIG logs -n \$NS job/\$JOB --all-containers || true
        exit 1
    """
}

pipeline {
    agent any

    options {
        disableConcurrentBuilds()
    }

    environment {
        NEXUS_REGISTRY   = "nexus-service.cicd.svc.cluster.local:8082"
        BACKEND_IMAGE    = "ehealth-backend"
        FRONTEND_IMAGE   = "ehealth-frontend"
        REACT_APP_API_URL = "http://api.ehealth.local"
        GITHUB_URL       = "https://github.com/alaa1897/E-Health-Management-Hub-internship.git"
        KANIKO_CONTEXT   = "git://github.com/alaa1897/E-Health-Management-Hub-internship.git#refs/heads/main"
        SONAR_HOST_URL   = "http://sonarqube-service.cicd.svc.cluster.local:9000"
        STAGING_TAG      = "staging-${BUILD_NUMBER}"
    }

    // triggers { pollSCM('* * * * *') }
    // Still commented out per Task 4's note — re-enable once a few clean
    // Task 5 runs have gone through via "Build Now".

    stages {

        stage('Checkout') {
            steps {
                git credentialsId: 'github-credentials',
                    url: "${GITHUB_URL}",
                    branch: 'main'

                // TASK 5 FIX (worker1 OOM, confirmed live 2026-08-19 via
                // dmesg — see the matching comment on Quality Gate below for
                // the other half of this). worker1 has ~5.3Gi of real RAM.
                // Jenkins (1024Mi limit) + SonarQube (2Gi limit, resident
                // 24/7) alone commit ~3Gi of *limits* before a single build
                // step runs. When Kaniko's frontend Job (3072Mi limit) needs
                // its own peak during "Build Docker Images", the node runs
                // out of real memory and the kernel OOM-killer sweeps
                // several processes at once — confirmed live: `node`,
                // Kaniko's own `executor` process, and `npm run build` were
                // all killed in the same instant.
                //
                // Fix: SonarQube is only actually needed for the "SonarQube
                // Analysis" / "Quality Gate" stages — nothing after that
                // (Build Docker Images, Trivy, push, deploy) ever talks to
                // it. So scale it UP here, at the very start (this also
                // self-heals if a previous run aborted after scaling it
                // down), then scale it back DOWN to 0 right after the
                // Quality Gate passes, handing its ~1-2Gi of real memory
                // back to worker1 before Kaniko needs it. Doing the scale-up
                // this early gives SonarQube's slow Elasticsearch startup
                // (2-3 min) the whole Build Frontend + Build Backend window
                // to finish before SonarQube Analysis actually needs it.
                withCredentials([file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG')]) {
                    sh '''
                        set -e
                        kubectl --kubeconfig=$KUBECONFIG scale deployment/sonarqube -n cicd --replicas=1
                    '''
                }
            }
        }

        // "Build" here = dependency-install sanity check on source code — no
        // Docker image yet. Runs natively in the Jenkins pod using the
        // Node.js installed by the install-node initContainer.
        //
        // CORRECTED (caught live, 2026-08-19): this stage originally also
        // ran the full `npm run build` (webpack bundle) with
        // NODE_OPTIONS=--max-old-space-size=1536 — Jenkins' own pod only has
        // a 768Mi memory limit (Piège 2), so that OOMKilled Jenkins itself
        // outright (exit 137). The full production build already gets
        // validated for real later, inside Kaniko's Job, which has its own
        // dedicated 3072Mi (the same number Task 4 already had to raise it
        // to for this exact reason). Running it twice was both wasteful and,
        // on this cluster's memory budget, actively unsafe — `npm ci` alone
        // is a legitimate and much lighter "does this even install" gate.
        stage('Build Frontend') {
            steps {
                sh '''
                    set -e
                    export PATH="/opt/tools/node/bin:$PATH"
                    cd FrontEnd
                    npm ci
                '''
            }
        }

        stage('Build Backend') {
            steps {
                sh '''
                    set -e
                    export PATH="/opt/tools/node/bin:$PATH"
                    cd Backend
                    npm ci
                '''
            }
        }

        // Two separate SonarQube projects (backend, frontend). Runs
        // sonar-scanner natively (see jenkins-deployment.yaml) so
        // .scannerwork/report-task.txt lands in this same workspace, which
        // Quality Gate needs.
        // CORRECTED (caught live, 2026-08-19): neither sh block below
        // originally exported PATH, so sonar-scanner's JS/TS analyzer
        // sensor couldn't find `node` ("Error when running: 'node -v'. Is
        // Node.js available during analysis?") and silently SKIPPED
        // JS/TS-specific rules for both projects — the scan still uploaded
        // and the Quality Gate still "passed", just on materially
        // incomplete analysis for a Node.js/React codebase. Fixed the same
        // way the npm shebang issue was fixed earlier: export PATH scoped
        // to just this shell step.
        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('sonarqube') {
                    sh '''
                        set -e
                        export PATH="/opt/tools/node/bin:$PATH"
                        cd Backend
                        /opt/tools/sonar-scanner/bin/sonar-scanner \
                          -Dsonar.projectKey=ehealth-backend \
                          -Dsonar.projectName="E-Health Backend" \
                          -Dsonar.sources=. \
                          -Dsonar.exclusions=node_modules/**
                    '''
                    sh '''
                        set -e
                        export PATH="/opt/tools/node/bin:$PATH"
                        cd FrontEnd
                        /opt/tools/sonar-scanner/bin/sonar-scanner \
                          -Dsonar.projectKey=ehealth-frontend \
                          -Dsonar.projectName="E-Health Frontend" \
                          -Dsonar.sources=src
                    '''
                }
            }
        }

        stage('Quality Gate') {
            steps {
                dir('Backend') {
                    timeout(time: 5, unit: 'MINUTES') {
                        waitForQualityGate abortPipeline: true
                    }
                }
                dir('FrontEnd') {
                    timeout(time: 5, unit: 'MINUTES') {
                        waitForQualityGate abortPipeline: true
                    }
                }

                // TASK 5 FIX — see the matching comment on Checkout above.
                // We only reach this line if BOTH gates passed
                // (abortPipeline: true throws immediately on failure, which
                // also means: if the gate fails, we skip this and SonarQube
                // stays scaled up — harmless, since Kaniko never runs in
                // that case either). SonarQube is done being useful for this
                // run, so scale it to 0 and actually WAIT for the pod to
                // terminate — `kubectl scale` returns immediately, but the
                // JVM+ES process takes a few seconds to actually release its
                // memory back to worker1, and that memory needs to be free
                // *before* the Kaniko frontend Job starts in the very next
                // stage, not racing it.
                withCredentials([file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG')]) {
                    sh '''
                        set -e
                        kubectl --kubeconfig=$KUBECONFIG scale deployment/sonarqube -n cicd --replicas=0
                        kubectl --kubeconfig=$KUBECONFIG wait --for=delete pod -l app=sonarqube -n cicd --timeout=60s || true
                    '''
                }
            }
        }

        // Piège 4 / Option C — build + push to a throwaway ":staging-N" tag
        // only. Nothing under ":latest" or ":N" exists in Nexus yet.
        stage('Build Docker Images') {
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
      nodeSelector:
        kubernetes.io/hostname: k8s-worker1
      containers:
        - name: kaniko
          image: gcr.io/kaniko-project/executor:latest
          args:
            - --context=${KANIKO_CONTEXT}
            - --context-sub-path=Backend
            - --destination=${NEXUS_REGISTRY}/${BACKEND_IMAGE}:${STAGING_TAG}
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
                    '''
                    waitForJobCompletion('kaniko-backend-${BUILD_NUMBER}', 'cicd', 90)

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
      nodeSelector:
        kubernetes.io/hostname: k8s-worker1
      containers:
        - name: kaniko
          image: gcr.io/kaniko-project/executor:latest
          args:
            - --context=${KANIKO_CONTEXT}
            - --context-sub-path=FrontEnd
            - --build-arg=REACT_APP_API_URL=${REACT_APP_API_URL}
            - --destination=${NEXUS_REGISTRY}/${FRONTEND_IMAGE}:${STAGING_TAG}
            - --insecure
            - --skip-tls-verify
            - --verbosity=info
            - --snapshot-mode=time
            - --use-new-run=true
          resources:
            requests:
              cpu: "250m"
              memory: "256Mi"
            limits:
              cpu: "1"
              memory: "3072Mi"
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
                    '''
                    waitForJobCompletion('kaniko-frontend-${BUILD_NUMBER}', 'cicd', 90)
                }
            }
        }

        // Piège 8 — Nexus is HTTP-only, Trivy needs --insecure + creds.
        // Piège 9 — exit-code 0 for now (see Jenkinsfile comment below);
        // flip to 1 --severity CRITICAL once you and your mentor have
        // reviewed a baseline report together.
        stage('Security Scan — Trivy') {
            steps {
                withCredentials([
                    usernamePassword(credentialsId: 'nexus-credentials', usernameVariable: 'NEXUS_USER', passwordVariable: 'NEXUS_PASS'),
                    file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG')
                ]) {
                    sh '''
                        set -e
                        kubectl --kubeconfig=$KUBECONFIG create secret generic nexus-registry-creds \
                          -n cicd \
                          --from-literal=username=$NEXUS_USER \
                          --from-literal=password=$NEXUS_PASS \
                          --dry-run=client -o yaml | kubectl --kubeconfig=$KUBECONFIG apply -f -
                    '''
                }

                withCredentials([file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG')]) {
                    sh '''
                        set -e
                        cat <<EOF > /tmp/trivy-backend-${BUILD_NUMBER}.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: trivy-backend-${BUILD_NUMBER}
  namespace: cicd
spec:
  backoffLimit: 0
  ttlSecondsAfterFinished: 300
  template:
    spec:
      restartPolicy: Never
      nodeSelector:
        kubernetes.io/hostname: k8s-worker1
      containers:
        - name: trivy
          image: aquasec/trivy:latest
          env:
            - name: TRIVY_USERNAME
              valueFrom:
                secretKeyRef: { name: nexus-registry-creds, key: username }
            - name: TRIVY_PASSWORD
              valueFrom:
                secretKeyRef: { name: nexus-registry-creds, key: password }
          args:
            - image
            - --insecure
            - --exit-code
            - "0"
            - --severity
            - HIGH,CRITICAL
            - --format
            - table
            - ${NEXUS_REGISTRY}/${BACKEND_IMAGE}:${STAGING_TAG}
          resources:
            requests: { cpu: "250m", memory: "256Mi" }
            limits: { cpu: "1", memory: "1Gi" }
          volumeMounts:
            - name: trivy-cache
              mountPath: /root/.cache/trivy
      volumes:
        - name: trivy-cache
          persistentVolumeClaim:
            claimName: trivy-cache-pvc
EOF
                        kubectl --kubeconfig=$KUBECONFIG apply -f /tmp/trivy-backend-${BUILD_NUMBER}.yaml
                    '''
                    waitForJobCompletion('trivy-backend-${BUILD_NUMBER}', 'cicd', 60)

                    sh '''
                        set -e
                        cat <<EOF > /tmp/trivy-frontend-${BUILD_NUMBER}.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: trivy-frontend-${BUILD_NUMBER}
  namespace: cicd
spec:
  backoffLimit: 0
  ttlSecondsAfterFinished: 300
  template:
    spec:
      restartPolicy: Never
      nodeSelector:
        kubernetes.io/hostname: k8s-worker1
      containers:
        - name: trivy
          image: aquasec/trivy:latest
          env:
            - name: TRIVY_USERNAME
              valueFrom:
                secretKeyRef: { name: nexus-registry-creds, key: username }
            - name: TRIVY_PASSWORD
              valueFrom:
                secretKeyRef: { name: nexus-registry-creds, key: password }
          args:
            - image
            - --insecure
            - --exit-code
            - "0"
            - --severity
            - HIGH,CRITICAL
            - --format
            - table
            - ${NEXUS_REGISTRY}/${FRONTEND_IMAGE}:${STAGING_TAG}
          resources:
            requests: { cpu: "250m", memory: "256Mi" }
            limits: { cpu: "1", memory: "1Gi" }
          volumeMounts:
            - name: trivy-cache
              mountPath: /root/.cache/trivy
      volumes:
        - name: trivy-cache
          persistentVolumeClaim:
            claimName: trivy-cache-pvc
EOF
                        kubectl --kubeconfig=$KUBECONFIG apply -f /tmp/trivy-frontend-${BUILD_NUMBER}.yaml
                    '''
                    waitForJobCompletion('trivy-frontend-${BUILD_NUMBER}', 'cicd', 60)
                }
            }
        }

        // Option C promotion: re-point :BUILD_NUMBER and :latest at the
        // already-scanned :staging-N manifest. `crane tag` is a registry-side
        // operation — no re-upload, no rebuild.
        stage('Push Validated Images to Nexus') {
            steps {
                withCredentials([file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG')]) {
                    sh '''
                        set -e
                        cat <<EOF > /tmp/crane-promote-${BUILD_NUMBER}.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: crane-promote-${BUILD_NUMBER}
  namespace: cicd
spec:
  backoffLimit: 0
  ttlSecondsAfterFinished: 300
  template:
    spec:
      restartPolicy: Never
      nodeSelector:
        kubernetes.io/hostname: k8s-worker1
      containers:
        - name: crane
          image: gcr.io/go-containerregistry/crane:debug
          env:
            - name: NEXUS_USER
              valueFrom:
                secretKeyRef: { name: nexus-registry-creds, key: username }
            - name: NEXUS_PASS
              valueFrom:
                secretKeyRef: { name: nexus-registry-creds, key: password }
          command: ["/busybox/sh", "-c"]
          args:
            - |
              set -e
              crane auth login ${NEXUS_REGISTRY} --insecure -u "\$NEXUS_USER" -p "\$NEXUS_PASS"
              crane tag --insecure ${NEXUS_REGISTRY}/${BACKEND_IMAGE}:${STAGING_TAG} ${BUILD_NUMBER}
              crane tag --insecure ${NEXUS_REGISTRY}/${BACKEND_IMAGE}:${STAGING_TAG} latest
              crane tag --insecure ${NEXUS_REGISTRY}/${FRONTEND_IMAGE}:${STAGING_TAG} ${BUILD_NUMBER}
              crane tag --insecure ${NEXUS_REGISTRY}/${FRONTEND_IMAGE}:${STAGING_TAG} latest
          resources:
            requests: { cpu: "100m", memory: "128Mi" }
            limits: { cpu: "500m", memory: "256Mi" }
EOF
                        kubectl --kubeconfig=$KUBECONFIG apply -f /tmp/crane-promote-${BUILD_NUMBER}.yaml
                    '''
                    waitForJobCompletion('crane-promote-${BUILD_NUMBER}', 'cicd', 30)
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

        stage('Verify Application') {
            steps {
                withCredentials([file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG')]) {
                    sh '''
                        kubectl --kubeconfig=$KUBECONFIG get pods -n ehealth
                        kubectl --kubeconfig=$KUBECONFIG get svc -n ehealth
                        kubectl --kubeconfig=$KUBECONFIG get ingress -n ehealth
                    '''
                }
            }
        }
    }

    post {
        success {
            echo "Pipeline complet — build ${BUILD_NUMBER} analysé, scanné, déployé et validé"
        }
        failure {
            echo "Pipeline échoué — vérifier les logs ci-dessus"
        }
    }
}
